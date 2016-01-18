#-------------------------------------------------------------------------------#
# Copyright (c) 2014 by Genome Research Limited
#  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of the Wellcome Trust Sanger Institute, Genome
#      Research Limited, Genome Reference Consortium nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL GENOME RESEARCH LIMITIED BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#-------------------------------------------------------------------------------#
# PGP mods 20100917 wc2

package EnsEMBL::Web::ZMenu::Genome;
use strict;
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::ZMenu);

sub content{
    my $self = shift;
  
    my $hub       = $self->hub;	
    my $id        = $hub->param('id');
    my $dbID      = $hub->param('dbid');
    my $obj_type  = $hub->param('ftype');
    my $region    = $hub->param('r');
    my $db        = $hub->param('fdb') || $hub->param('db') || 'core'; 

    # kb8
    # Ugly hack to the al-blocks zmenu to work. Some code below makes this break, so this is 
    # the solution for now. Either loose the alblocks or make them into  a proper ensembl adaptor.
    if ( $obj_type =~ /al_block/ ) {
	(my $url_id = $id) =~ s/_.*//;
	$self->caption("$url_id (al_block)"); 
	my $URL = CGI::escapeHTML( "/PGP_zfish/contigview?region=$url_id" );
	$self->add_entry({
	    'type'        =>  'bp:',
	    'label_html'  =>  'Jump to region',
	    'link'        =>  $URL,
	    'priority'    =>  1,
	});
	return;
    }

    my $db_adaptor   = $hub->database(lc($db));
    my $adaptor_name = "get_${obj_type}Adaptor";
    my $feat_adap    = $db_adaptor->$adaptor_name;
    my $feature      = $feat_adap->fetch_by_dbID( $dbID ) if ( $dbID);    
   
    my $hit_name = $id;
    $hit_name    = $feature->hseqname() if ( $feature );

    my $fs = $feat_adap->can( 'fetch_all_by_hit_name' ) ? $feat_adap->fetch_all_by_hit_name($hit_name)
	: $feat_adap->can( 'fetch_all_by_probeset' ) ? $feat_adap->fetch_all_by_probeset($hit_name)
	:                                              []
	;  
    

    my $logic_name = "";
    $logic_name    = ($feature) ? ($feature->analysis->logic_name) : ($fs->[0]->analysis->logic_name) if ($fs->[0]);

    my $external_db_id = ($fs->[0] && $fs->[0]->can('external_db_id')) ? $fs->[0]->external_db_id : '';
    my $extdbs         = $external_db_id ? $hub->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'external_db'}{'entries'} : {};
    my $hit_db_name    = $extdbs->{$external_db_id}{'db_name'} || 'External Feature';
    

    my $species= $hub->species;


    # Instead of total features for viewing, show count for rep and no_rep wc2;    	
    my $fs_track = undef;
    if ( $logic_name && $logic_name =~ /_norep/ ){
	 $fs_track  = @{$feat_adap->fetch_all_by_hit_name($hit_name,$logic_name)} ." (norep) / ". @$fs ." (all)";
     }
    else {
	$fs_track = @$fs ." (all)";
    }
    # ----- 
    
    
    #
    # ZMENU TYPE:
    # different zmenu for oligofeatures, PGP doesn't even use this. wc2 (AT RISK)

    if ($obj_type eq 'ProbeFeature') {
	my $array_name = $hub->param('array') || '';
	my $ptype      = $hub->param('ptype') || '';
	unless ($self->{'caption'}) { $self->{'caption'} = "Probe set: $id"; }
	my $fv_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'fdb'=>'funcgen', 'ptype'=>$ptype, 'db' =>'core'});
	my $p = 50;
	$self->add_entry({ 
	    'label' => 'View all probe hits',
	    'link'   => $fv_url,
	    'priority' => $p,
	});
	
	# details of each probe within the probe set on the array that are found within the slice
	my ($r_name,$r_start,$r_end) = $hub->param('r') =~ /(\w+):(\d+)-(\d+)/;
	my %probes;
	
	foreach my $of (@$fs){ 
	    my $op = $of->probe; 
	    my $of_name    = $of->probe->get_probename($array_name);
	    my $of_sr_name = $of->seq_region_name;
	    next if ("$of_sr_name" ne "$r_name");
	    my $of_start   = $of->seq_region_start;
	    my $of_end     = $of->seq_region_end;
	    next if ( ($of_start > $r_end) || ($of_end < $r_start));
	    my $loc = $of_start.'bp-'.$of_end.'bp';
	    $probes{$of_name}{'chr'}   = $of_sr_name;
	    $probes{$of_name}{'start'} = $of_start;
	    $probes{$of_name}{'end'}   = $of_end;
	    $probes{$of_name}{'loc'}   = $loc;
	}
	foreach my $probe (sort {
	    $probes{$a}->{'chr'}   <=> $probes{$b}->{'chr'}
	    || $probes{$a}->{'start'} <=> $probes{$b}->{'start'}
	    || $probes{$a}->{'stop'}  <=> $probes{$b}->{'stop'}
	} keys %probes) {
	    my $type = $p < 50 ? ' ' : 'Individual probes:';
	    $p--;
	    my $loc = $probes{$probe}->{'loc'};
	    $self->add_entry({
		'type'     => $type,
		'label'    => "$probe ($loc)",
		'priority' => $p,
	    });
	}
    }
    

    #
    # ZMENU TYPE:
    # End Read information, The addition of Helminth complicates things with capillary reads.
    # !!! IMPORTANT: This is legacy code, and ends should be pointing to the ENDS.pm instead.
    # !!! Have kept this around just in case.
       
    elsif ( ($logic_name =~ /end_|fos|bac/ || $logic_name =~ /cap_wgs|capillary|ungrouped|454_20kb/) && $dbID ) {
	
	#my $feature = $feat_adap->fetch_by_dbID( $dbID );
	#print STDERR "========== ENDS ================ \n";
	my $slice_adaptor        =  $db_adaptor->get_SliceAdaptor();
	my $dafa                 =  $db_adaptor->get_DnaAlignFeatureAdaptor();	
	
	my ($clone_name, $distance) = $id =~ /^(.*) distance: (.*)/;
	my $logic_name              = $hub->param('logic_name');  
	my $extra_data              = $hub->param('extra_data');
	my ($int_name, $chem, $matepair_id) = split (/\./, $extra_data);
	my @mpids = split (",", $matepair_id);

	if ( $id =~ /distance/ ) { # This is the paired read blocks
	   
	    $self->caption($clone_name);
	    $self->add_entry({
		'type'     => "Clone id",
		'label'    => "$clone_name",
		'priority' => 101,
	    });
	    $self->add_entry({
		'type'     => "Distance",
		'label'    => "$distance ",
		'priority' => 100,
	    });
	    
	    my ($hit_name) = $id =~ /^(.*?) /;
	    
	    # ugly hack cause of the naming property of some of the ends.  T7/SP6
	    $hit_name =~ s/SP6|T7//;
	    
	    my ($name, $start, $end) =  $region =~ /^(.*):(.*)-(.*)/;
	    
	    my $coord_sys_name = "toplevel";
	    if ($db_adaptor->dbname =~ /wgs/i){
		$coord_sys_name = "supercontig";
	    }

	    my $region_slice   = $slice_adaptor->fetch_by_region($coord_sys_name, $name, $start, $end);
	    
	    my @slice_features = sort {$a->seq_region_start <=> $b->seq_region_end } @{$dafa->fetch_all_by_Slice( $region_slice, $logic_name )};

	    my @region_features;
	    foreach my $slice_feat (@slice_features){
		push @region_features, $slice_feat if ($slice_feat->hseqname =~ /$hit_name/);
	    }

	    my @ends;
	    my $priority = 90;
	    
	    foreach my $region_feature ( @region_features ) {

		my $total_featcount = @{$feat_adap->fetch_all_by_hit_name($region_feature->hseqname)};
		my @feat_proj = @{$region_feature->project($coord_sys_name)};
		
		my $chr    = $feat_proj[0]->to_Slice->seq_region_name;
		my $hstart = $feat_proj[0]->to_Slice->start;
		my $hend   = $feat_proj[0]->to_Slice->end;
		
		my $reg = $chr.":".$hstart."-".$hend;
		
		my $hit_url =  $hub->url({'type' => 'Location', 'action' => 'View', 'r' => $reg, 'h' => $region_feature->hseqname});

		$self->add_entry({
		    'label'    => $region_feature->hseqname ." ($total_featcount hits)",
		    'link'     => $hit_url,
		    'priority' => $priority--,
		});
	    }
	    @region_features = undef;
	}
	else {
	    
	    $self->caption($id);
	    (my $clone_name = $id)=~ s/\..*|SP6|T7//;
	    $self->add_entry({
		'type'     => "Clone id",
		'label'    => $clone_name,
		'priority' => 101,
	    });
	    my $percent = $feature->percent_id();
	    my $hstart  = $feature->hstart; 
	    my $hend    = $feature->hend;
	    my $strand  = $feature->strand;
	    my $hlength = $hend - $hstart +1;
	    
	    $self->add_entry({
		'type'     => "Internal name",
		'label'    => "$int_name.$chem ",
		'priority' => 100,
	    }) if ($int_name);	    
	    $self->add_entry({
		'type'     => "Hit length",
		'label'    => $hlength,
		'priority' => 100,
	    });	    
	    $self->add_entry({
		'type'     => "Percent id",
		'label'    => $percent,
		'priority' => 90,
	    });	   

	    (my $ext_id = $hit_name) =~ s/.*\.//;
 	
            my $ext_url = "http://www.ncbi.nlm.nih.gov/Traces/trace.cgi?cmd=retrieve&val=$ext_id";    		
            $ext_url    = "http://www.ncbi.nlm.nih.gov/nucgss/$ext_id" if ($hit_name =~/rp/i); #RP libraries only in gss
	    
            if ($ext_id =~ /^\d+$/){
	    	$self->add_entry({
		    'type'    => "Record",
		    'label'    => $hit_name,
		    'link'     => $ext_url,
		    'priority' => 80,
	        });
	    }
	    $self->add_entry({ 
		'type'     => "Total hits",
		'label'    => $fs_track,
		'priority' => 15,
	    });

	    foreach my $mp (@mpids){
		my $mp_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>"$clone_name.$mp",'db'=>$db});
		$self->add_entry({ 
		    'type'     => "matepair",
		    'label'    => "$clone_name.$mp",
		    'link'     => $mp_url,
		    'priority' => 10,
		});
		#$count++;
	    }
	    my $fv_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "View all hits",
		'link'     => $fv_url,
		'priority' => 10,
	    });
	}	
	my $attribs = $feature->get_all_Attributes();
	
	my @hanger_attrib = @{$feature->get_all_Attributes("gap_hanger")};
	my %attrib_hash;
	foreach my $attrib ( @{$attribs} ) {
	    $attrib_hash{ $attrib->code } = $attrib;
	}

	#
	# Extra Attrib Info to be added on to the zmenu.		
	if ($attrib_hash{ "spanner" } ) {
	    my $region = $attrib_hash{ "spanner" }->value();  
	    my $fv_url = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});

	    $self->add_entry({ 
		'label'    => "Show spanning pair",
		'link'     => $fv_url,
		'priority' => 60,
	    });
	}
	if ($attrib_hash{ "gap_spanner" } ) {
	    my $region = $attrib_hash{ "gap_spanner" }->value();
	    my $fv_url = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});

	    $self->add_entry({ 
		'label'    => "Show gap spanning pair",
		'link'     => $fv_url,
		'priority' => 60,
	    });
	}

        if ($attrib_hash{ "prev_feature" } ) {
            my $pre_feat = $feat_adap->fetch_by_dbID($attrib_hash{ "prev_feature" }->value() );
            my $region   = $pre_feat->slice->seq_region_name . ":" .$pre_feat->start . "-" .$pre_feat->end;
            my $fv_url   = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
            $self->add_entry({ 
                'label'    => "Previous feature",
                'link'     => $fv_url,
            });
        }

        if ($attrib_hash{ "next_feature" } ) {
            my $next_feat = $feat_adap->fetch_by_dbID($attrib_hash{ "next_feature" }->value() );
            my $region   = $next_feat->slice->seq_region_name . ":" .$next_feat->start . "-" .$next_feat->end;
            my $fv_url   = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
            $self->add_entry({ 
                'label'    => "Next feature",
                'link'     => $fv_url,
            });
        }


	if ($attrib_hash{"fpc_asc"}) {
	    my $fpc_asc = $attrib_hash{"fpc_asc"}->value();
	    my $fpc_url = $hub->url({'type'=>'Location','action'=>'View','r'=>undef, 'region'=>$fpc_asc,});
	    $self->add_entry({
		'label'    => "FPC: $fpc_asc",
		'link'     => $fpc_url,
		'priority' => 85,
	    });
	}
	if ($attrib_hash{"gap_hanger"}) { # HELMINTH HANGERS	     
	    # Display indiv only if less than 3. else point to the genome view listing.
	    if (@hanger_attrib < 3){
		foreach my $attrib_feat (@hanger_attrib){
		    #warn "---$attrib_feat\n";
		    
		    my $opp_end_id      = $attrib_feat->value();
		    my $opp_feat        = $dafa->fetch_by_dbID($opp_end_id);
		    my $region          = $opp_feat->seq_region_name. ":".$opp_feat->seq_region_start."-".$opp_feat->seq_region_end;
		    my $opp_url     = $hub->url({'type'=>'Location','action'=>'View','h'=>$opp_feat->hseqname, 'r'=>$region});
		    $self->add_entry({
			'type'     => "mate pair",
			'label'    => $opp_feat->seq_region_name,
			'link'     => $opp_url,
			'priority' => 95,
		    });
		}
	    }
	    else {
		my $opp_hitname = ( $dafa->fetch_by_dbID($attrib_hash{"gap_hanger"}->value()) )->hseqname;
		my $opp_url     = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type, 'id'=>$opp_hitname, 'db'=>$db});
		$self->add_entry({
		    'type'     => "mate pair",
		    'label'    => "view all hits",
		    'link'     => $opp_url,
		    'priority' => 95,
		});
	    }
	}
    }



    #
    # ZMENU TYPE:
    # selfcomp track zmenu  
    # !!! IMPORTANT: This is legacy code, and selfcomp should be pointing to the Selfcomp.pm instead.
    # !!! Have kept this around just in case.
  
    elsif ( $logic_name =~ /self/ && $logic_name =~ /comp/ ) {
	
	my $logic_name           = $hub->param('logic_name');    
	my ($name, $start, $end) = $region =~ /^(.*):(.*)-(.*)/;

	my $slice_adaptor =  $db_adaptor->get_SliceAdaptor();
	my $dafa          =  $db_adaptor->get_DnaAlignFeatureAdaptor();
	my $region_slice  =  $slice_adaptor->fetch_by_region(undef, $name, $start, $end);
	
	my @region_features = sort {$a->seq_region_start <=> $b->seq_region_end } @{$dafa->fetch_all_by_Slice( $region_slice, $logic_name )};
	
	my $priority = 1000;

	#############################################################################################
	# WILL ADD :: To get hit information NOTE: Will be dangerous for human clones within clones #
	#############################################################################################
	my $hit_location = $region_features[0]->hseqname;
	my ($accession, $int_name, $ext_name, $attrib_type); #ext_num for misc_attrib table, which is diff in zfish and human.
	if ($id =~ /_/){ #Zfish has the joined names. OLD WAY - it should be removed but just incase.
	    $id =~ /(.*)_(.*)/;
	    ($accession, $int_name)  = ($1, $2);
	    ($ext_name = $accession) = ~ s/\.\d+//;
	    $attrib_type             = "external_clone";
	}
	elsif ($id =~ /:/){ 
	    my ($cs, $assembly, $name, $start, $stop, $strand) = split(":", $id);
	    $accession   = $name;
	    $ext_name    = $name;
	    $int_name    = $name;
	    $attrib_type = "external_clone";
	}
	else {
	    $accession   = $id;
	    $ext_name    = $accession;
	    $int_name    = $accession;
	    $attrib_type = "internal_clone";
	}	

	my $cs_check = $db_adaptor->get_CoordSystemAdaptor->fetch_by_name('clone');	
	my $hit_slice;
	if ($cs_check){
	    $hit_slice = $slice_adaptor->fetch_by_region('clone', $accession);
	}
	else {
	    $hit_slice = $slice_adaptor->fetch_by_region('contig', $accession);
	}

	my @zfish_accessions = @{$hit_slice->get_all_Attributes('accession')};
	my $zfish_accession;
	if (@zfish_accessions > 0){
	    $zfish_accession = "[".$zfish_accessions[0]->value."]";
	}
	
	my @projection = @{ $hit_slice->project('toplevel') };
	my $hit_chr    = $projection[0]->to_Slice->seq_region_name;
	
	my $mfa = $db_adaptor->get_MiscFeatureAdaptor();
	
	my @feat = @{$mfa->fetch_all_by_attribute_type_value($attrib_type, $ext_name)};
	
	my ($mf_start, $mf_end);
	
	###This was added to work with unfinished misc_features, taking the first ctg, and last ctg and getting the start/end (chr level).
	if (@feat < 1){
	    ($mf_start, $mf_end) = &get_unfin_clone_coord($mfa, $attrib_type, $hit_slice);
	}
	else{ 
	    $mf_start = $feat[0]->start;
	    $mf_end   = $feat[0]->end;
	}
	my ($region_start, $region_end) = (0,0);

	my $url        = $hub->url({'type' => 'Location', 'action' => 'View', 'region' => $accession, '__clear' => 1});
	my $hit_region = "$hit_chr:$region_start-$region_end";
	my $hiturl     = $hub->url({'type' => 'Location', 'action' => 'View', 'r' => $hit_region, '__clear' => 1});
	
	$self->add_entry({
	    'label'    => "Center on $id $zfish_accession",
	    'link'     => $url,
	    'priority' => 2000,
	});
	$self->add_entry({
	    'label'    => "Center on hit(s)",
	    'link'     => $hiturl,
	    'priority' => 1999,
	});
	
	my $shown_region      = $hub->param('region');
	
	my $url2  = $hub->url({'type' => 'Location', 'action' => 'Dotplot', 'r' => $shown_region, 'id' => $accession, '__clear' => 1});
	$self->add_entry({
	    'label'    => "Show dotplot",
	    'link'     => $url2,
	    'priority' => 1998,
	});
	foreach my $region_feature ( @region_features ) {
	    
	    next if ( $region_feature->hseqname !~ /$id/);
	    
	    my ($hit_start, $hit_end);
	    if ($region_feature->hstrand eq 1){
		$hit_start = $mf_start + ($region_feature->hstart);
		$hit_end   = $mf_start + ($region_feature->hend);
	    }
	    else {
		$hit_start = $mf_start + ($region_feature->hstart);
		$hit_end   = $mf_end + ($region_feature->hstart);
	    }
	    
	    my $entry = "[chr.".$region_feature->seq_region_name."]:". $region_feature->seq_region_start . "-" . $region_feature->seq_region_end . "(" . $region_feature->seq_region_strand .")";

	    $entry .= " :: [".$int_name."]:". $hit_start  . "-" . $hit_end. "(" . $region_feature->hstrand .")";
	    
	    $self->add_entry({
		'label' => $entry,
		'priority' => $priority--,
	    });
	    
	    #get range of the hit.
	    if (($region_feature->seq_region_strand eq 1) && ($region_start eq 0)){  $region_start = $hit_start;  }
	    if (($region_feature->seq_region_strand eq 1) && ($hit_end > $region_end)){  $region_end = $hit_end;  }
	    if (($region_feature->seq_region_strand eq -1) && ($region_end eq 0)){  $region_end = $hit_end;  }
	    if (($region_feature->seq_region_strand eq -1) && ($region_start eq 0)){$region_start = $hit_start;}
	    elsif (($region_feature->seq_region_strand eq -1) && ($hit_start < $region_start)){  $region_start = $hit_start;  }	    
	}	
	$self->caption("$id (chr:$hit_chr) $region_start - $region_end");
    }




    
    #
    # ZMENU TYPE:
    # cDNA and other gene models track zmenu  
    # !!! IMPORTANT: This is legacy code, and selfcomp should be pointing to the Selfcomp.pm instead.
    # !!! Have kept this around just in case.

    elsif ( $logic_name =~ /cdna|ssgi|ccds|cufflink|gth_cegma|gth_ferencs|refseq/i ){ 
	
	$self->caption($id);	
	my $logic_name           = $hub->param('logic_name');    
	my ($name, $start, $end) = $region =~ /^(.*):(.*)-(.*)/;
	
	my $slice_adaptor =  $db_adaptor->get_SliceAdaptor();
	my $dafa          =  $db_adaptor->get_DnaAlignFeatureAdaptor();
	
	my $coord_sys_name = "toplevel";
	if ($db_adaptor->dbname =~ /wgs/i){
	    $coord_sys_name = "supercontig";	
	}

	my $region_slice = $slice_adaptor->fetch_by_region($coord_sys_name, $name, $start, $end);
	
	my $region_slice    = $slice_adaptor->fetch_by_region($coord_sys_name, $name, $start, $end);
	my @region_features = sort {$a->seq_region_start <=> $b->seq_region_end } @{$dafa->fetch_all_by_Slice( $region_slice, $logic_name )};
	
	my $priority = 1000;		
	my ($hcoverage, $perc_id) = (0,0);
	my $hit_rank = "";

	foreach my $region_feature ( @region_features ) {

	    next if ( $region_feature->hseqname ne $id);
	    
	    my $entry = $region_feature->seq_region_name.":". $region_feature->seq_region_start . "-" . $region_feature->seq_region_end . "(" . $region_feature->seq_region_strand .")";
	    
	    $entry .= " :: ".  $region_feature->hstart . "-" . $region_feature->hend . "(" . $region_feature->hstrand .")";
	    
	    $self->add_entry({
		'label'    => $entry,
		'priority' => $priority--,
	    });
	    
	    if ($hcoverage == 0){
		$hcoverage = $region_feature->hcoverage;
	    }
	    if ($perc_id == 0){
		$perc_id = $region_feature->percent_id;
	    }
	    
	    $hit_rank = $region_feature->extra_data || "";
	    
	}
	
	my $rankinfo   = $self->caption . " ($hit_rank)" if ($hit_rank);
	$self->caption( $rankinfo );
	my $URL = CGI::escapeHTML( "http://www.ncbi.nlm.nih.gov/nuccore/$id" );

	#--If there is a gene name then split it.

	my ($genename, $acc);
	if ($id =~ /\(|\)/){	    
	    ($genename, $acc) = ($id =~ /(\w+)\((.*)\)/);	    
	    $self->caption($genename);
	    $URL =  CGI::escapeHTML( "http://www.ncbi.nlm.nih.gov/nuccore/$acc" );	    
	}
	if ($id =~ /ccds/i){
		(my $ccds_id = $id) =~ s/\..*//;
		$URL = CGI::escapeHTML( "http://www.ncbi.nlm.nih.gov/projects/CCDS/CcdsBrowse.cgi?REQUEST=CCDS&DATA=$ccds_id" );
	}
	$self->add_entry({
	    'label'    => ($acc) ? "NCBI:$acc" : "NCBI:$id",
	    'link'     => $URL,
	    'priority' => 10,
	});	
	my $fv_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'db'=>$db});
	$self->add_entry({ 
	    'label'    => "View all hits",
	    'link'     => $fv_url,
	    'priority' => 9,
	});       
	$self->add_entry({
	    'type'     => "Coverage",
	    'label'    => "$hcoverage %",
	    'priority' => 8,
	}) if ($hcoverage);	
	$self->add_entry({ 
	    'type'    => "Gene Name",
	    'label'     => $genename,
	    'priority' => 7,
	}) if ($genename);
	$self->add_entry({
	    'type'     => "Perc ID",
	    'label'    => "$perc_id %",
	    'priority' => 6,
	}) if ($perc_id);	
    }
    



    
    
    #ZMENU TYPE:
    #Overlaps and false gaps  
    
    elsif ( $logic_name =~ /overlap/ ) {	
	my $overlap_name = $feature->hseqname();
	my $percent      = $feature->percent_id();
	my $hstart       = $feature->hstart; 
	my $hend         = $feature->hend;
	my $strand       = $feature->strand;
	my $hlength      = $hend - $hstart +1;
	
	$self->add_entry({
	    'type'     => "length",
	    'label'    => "$hlength",
	    'priority' => 100,
	});

	my $attribs = $feature->get_all_Attributes();
	
	my %attrib_hash;
	foreach my $attrib ( @{$attribs} ) {
	    $attrib_hash{ $attrib->code } = $attrib;
	}
	
	if($overlap_name =~  /False/) {
	    $self->caption("False gap");
	}
	elsif($overlap_name =~ /Problem/){
	    $self->caption("Problem Join");
	}
	else {
	    $self->caption("Clone overlap");	    
	    $self->add_entry({
		'type'     => "overlap between ",
		'label'    => "$id",
		'priority' => 90,
	    });
	    
	    my $overlap_variation = 100 - $feature->percent_id();
	    $self->add_entry({ 
		'type'     => "Variation ",
		'label'    => sprintf("%3.2f \%", $overlap_variation),
		'priority' => 80,
	    });	    
	    
	    my $alignment_url = $hub->url({'type'=>'Location','action'=>'OverlapAlignment','dbid'=>$feature->dbID, 'db'=>$db});	    
	    $self->add_entry({ 
		
		'label'     => "View alignment",
		'link'      => $alignment_url,
		'priority'  => 70,
	    });
	}
	
	if ($attrib_hash{ "prev_bad_over" } ) {
	    my $pre_bad = $feat_adap->fetch_by_dbID($attrib_hash{ "prev_bad_over" }->value() );
	    my $region  = $pre_bad->slice->seq_region_name . ":" .$pre_bad->start . "-" .$pre_bad->end;
	    my $fv_url  = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Previous lowquality overlap",
		'link'     => $fv_url,
		'priority' => 60,
	    });
	}

	if ($attrib_hash{ "prev_over" } ) {
	    my $pre_bad = $feat_adap->fetch_by_dbID($attrib_hash{ "prev_over" }->value() );
	    my $region  = $pre_bad->slice->seq_region_name . ":" .$pre_bad->start . "-" .$pre_bad->end;
	    my $fv_url  = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Previous good overlap",
		'link'     => $fv_url,
		'priority' => 50,
	    });
	}

	if ($attrib_hash{ "next_bad_over" } ) {
	    my $pre_bad = $feat_adap->fetch_by_dbID($attrib_hash{ "next_bad_over" }->value() );
	    my $region  = $pre_bad->slice->seq_region_name . ":" .$pre_bad->start . "-" .$pre_bad->end;
	    my $fv_url  = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Next lowquality overlap",
		'link'     => $fv_url,
		'priority' => 40,
	    });
	}
	
	if ($attrib_hash{ "next_over" } ) {
	    my $pre_bad = $feat_adap->fetch_by_dbID($attrib_hash{ "next_over" }->value() );
	    my $region  = $pre_bad->slice->seq_region_name . ":" .$pre_bad->start . "-" .$pre_bad->end;
	    my $fv_url  = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Next good overlap",
		'link'     => $fv_url,
		'priority' => 30,
	    });
	}
	
	if ($attrib_hash{ "prev_prob_join" } ) {
	    my $pre_prob = $feat_adap->fetch_by_dbID($attrib_hash{ "prev_prob_join" }->value() );
	    my $region   = $pre_prob->slice->seq_region_name . ":" .$pre_prob->start . "-" .$pre_prob->end;
	    my $fv_url   = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Previous bad join",
		'link'     => $fv_url,
		'priority' => 45,
	    });
	}
	
	if ($attrib_hash{ "next_prob_join" } ) {
	    my $next_prob = $feat_adap->fetch_by_dbID($attrib_hash{ "next_prob_join" }->value() );
	    my $region    = $next_prob->slice->seq_region_name . ":" .$next_prob->start . "-" .$next_prob->end;
	    my $fv_url    = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Next bad join",
		'link'     => $fv_url,
		'priority' => 44,
	    });
	}
	
	if ($attrib_hash{ "prev_false" } ) {
	    my $pre_false = $feat_adap->fetch_by_dbID($attrib_hash{ "prev_false" }->value() );
	    my $region    = $pre_false->slice->seq_region_name . ":" .$pre_false->start . "-" .$pre_false->end;
	    my $fv_url    = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Previous false gap",
		'link'     => $fv_url,
		'priority' => 55,
	    });
	}
	
	if ($attrib_hash{ "next_false" } ) {
	    my $next_false = $feat_adap->fetch_by_dbID($attrib_hash{ "next_false" }->value() );
	    my $region     = $next_false->slice->seq_region_name . ":" .$next_false->start . "-" .$next_false->end;
	    my $fv_url     = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Next false gap",
		'link'     => $fv_url,
		'priority' => 54,
	    });
	}
    }



    
    #ZMENU TYPE:
    # WGS alignments  
    # !!! IMPORTANT: This is legacy code.
    # !!! Have kept this around just in case. 
    elsif ( $logic_name =~ /wgs\d+/ ) {
#    print STDERR "========== WGS[]NUMBER ================ \n";
	
	$self->caption("$id (WGS)");
	
	my $logic_name           = $hub->param('logic_name');    
	my ($name, $start, $end) = $region =~ /^(.*):(.*)-(.*)/;
	my $slice_adaptor        =  $db_adaptor->get_SliceAdaptor();
	my $dafa                 =  $db_adaptor->get_DnaAlignFeatureAdaptor();
	
	my $region_slice    = $slice_adaptor->fetch_by_region('toplevel', $name, $start, $end);

	my @region_features = sort {$a->seq_region_start <=> $b->seq_region_end } @{$dafa->fetch_all_by_Slice( $region_slice, $logic_name )};

	my $URL;
	if ( $logic_name =~ /28/ ) {	    
	    my $URL = CGI::escapeHTML( "/PGP_WGS28_zfish/Location/View?region=$id" );
	    $self->add_entry({
		'label' => $id,
		'link'  => $URL,
		'priority' => 1000,
	    });	    
	    my $fv_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'db'=>$db});
	    $self->add_entry({ 
		'label' => "View all hits",
		'link'   => $fv_url,
		'priority' => 999,
	    });
	}
	elsif ( $logic_name =~ /29/ ) {
	    my $URL = CGI::escapeHTML( "/PGP_WGS29_zfish/Location/View?region=$id" );
	    $self->add_entry({
		'label' => $id,
		'link'  => $URL,
		'priority' => 1000,
	    });	    
	    my $fv_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'db'=>$db});
	    $self->add_entry({ 
		'label' => "View all hits",
		'link'   => $fv_url,
		'priority' => 999,
	    });
	}
	if ( $logic_name =~ /31/ ) {	    
	    my $URL = CGI::escapeHTML( "/PGP_WGS31_zfish/Location/View?region=$id" );
	    $self->add_entry({
		'label' => $id,
		'link'  => $URL,
		'priority' => 1000,
	    });	    
	    my $fv_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'db'=>$db});
	    $self->add_entry({ 
		'label' => "View all hits",
		'link'   => $fv_url,
		'priority' => 999,
	    });
	}
   
	my $priority = 300;	
	foreach my $region_feature ( @region_features ) {	    
	    next if ( $region_feature->hseqname !~ /$id/);
	    
	    my $entry = $region_feature->seq_region_name.":". 
		$region_feature->seq_region_start  . "-" . 
		$region_feature->seq_region_end    . "(" . 
		$region_feature->seq_region_strand .")";
	    $entry .= " :: ".  $region_feature->hstart . "-" . $region_feature->hend . "(" . $region_feature->hstrand .")";
	    
	    $self->add_entry({
		'label'    => $entry,
		'priority' => $priority--,
	    });	    
	}
    }
    



    #ZMENU TYPE:
    # WGS alignments  
  # This is a hack so the new menu does not collide with the old wgs zfish menu. This will have to be changed when the 
  # compara pipeline is running on all organisms.
  elsif ( $logic_name =~ /wgs/  || $logic_name =~ /compara/ ) {
#    print STDERR "========== WGS ================ \n";


    my $logic_name    = $hub->param('logic_name');    
    my ($name, $start, $end) = $region =~ /^(.*):(.*)-(.*)/;
    my $slice_adaptor =  $db_adaptor->get_SliceAdaptor();
    my $dafa =  $db_adaptor->get_DnaAlignFeatureAdaptor();

    $self->caption("$id (WGS)");

      
    my $region_slice = $slice_adaptor->fetch_by_region('toplevel', $name, $start, $end);
    my @region_features = sort {$a->seq_region_start <=> $b->seq_region_end } @{$dafa->fetch_all_by_Slice( $region_slice, $logic_name )};

    my $priority = 100;
      
    foreach my $region_feature ( @region_features ) {

      next if ( $region_feature->hseqname !~ /$id/);

      my $entry = $region_feature->seq_region_name.":". $region_feature->seq_region_start . "-" . $region_feature->seq_region_end . "(" . $region_feature->seq_region_strand .")";
      $self->caption($entry);
      $entry = " :: ".  $region_feature->hseqname  . "(" . $region_feature->hstrand .")";

      $self->add_entry({
	'label' => $entry,
	'priority' => $priority--,
      });
      last;
      
    }
  }
  else {
    $self->caption("$id ($hit_db_name)");
    my @seq = [];
    @seq = split "\n", $hub->get_ext_seq($id,$hit_db_name) if ($hit_db_name !~ /CCDS/); #don't show EMBL desc for CCDS
    my $desc = $seq[0];
    if ($desc) {
      if ($desc =~ s/^>//) {
        $self->add_entry({
          'label' => $desc,
          'priority' => 150,
        });
      }
    }
    my $URL = CGI::escapeHTML( $hub->get_ExtURL($hit_db_name, $id) );
    my $label = ($hit_db_name eq 'TRACE') ? 'View Trace archive' : $id;
    $self->add_entry({
      'label' => $label,
      'link'  => $URL,
      'priority' => 100,
    });
    my $fv_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'db'=>$db});
    $self->add_entry({ 
      'label' => "View all hits",
      'link'   => $fv_url,
      'priority' => 50,
    }) if ($logic_name);
    
    

  }

    return ;
}



sub get_unfin_clone_coord {
    my ($mfa, $attrib_type, $hit_slice) = @_; # hit_slice is in clone level, in order to get all the contigs.
    
    my ($misc_feat_start, $misc_feat_end);
    
    my @ctg_proj = eval {@{$hit_slice->project('contig')} };

    return undef if (! @ctg_proj);
    
    #order just in case
    @ctg_proj = (sort {  $a->from_start <=> $b->from_start } @ctg_proj);
    my ($firstctg, $lastctg) = ($ctg_proj[0], $ctg_proj[-1]);

    my $first_name = $firstctg->to_Slice->seq_region_name;
    my $last_name  = $lastctg->to_Slice->seq_region_name;
    my @first_feat = @{$mfa->fetch_all_by_attribute_type_value($attrib_type, $first_name)};
    my @last_feat  = @{$mfa->fetch_all_by_attribute_type_value($attrib_type, $last_name)};

    return undef if ( ! @first_feat || !@last_feat);
    
    if ($first_feat[0]->start < $last_feat[0]->start){
	die "Error: incorrect strand\n" if ($first_feat[0]->strand ne 1);
	$misc_feat_start = $first_feat[0]->start;
	$misc_feat_end   = $last_feat[0]->end;
    }
    else {
	$misc_feat_start = $last_feat[0]->start;
	$misc_feat_end   = $first_feat[0]->start;
    }

    return ($misc_feat_start, $misc_feat_end);

}


1;

__END__ 
