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

package EnsEMBL::Web::ZMenu::Overlap;
use strict;
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::ZMenu);

#--------------------------------#
#--------------------------------#
# Glyph for clone overlaps.      #
#                                #
#   -wc2@sanger                  # 
#--------------------------------#
#--------------------------------#


#--------------------#
# content
#  -main zmenu code
#--------------------#
sub content{
    my $self = shift;
  
    my $hub       = $self->hub;	
    my $id        = $hub->param('id');
    my $dbID      = $hub->param('dbid');
    my $obj_type  = $hub->param('ftype');
    my $region    = $hub->param('r');
    my $db        = $hub->param('fdb') || $hub->param('db') || 'core'; 

    
    my $db_adaptor   = $hub->database(lc($db));
    my $adaptor_name = "get_${obj_type}Adaptor";
    my $feat_adap    = $db_adaptor->$adaptor_name;
    my $feature      = $feat_adap->fetch_by_dbID( $dbID ) if ( $dbID);    
   
    my $hit_name = $id;
    $hit_name    = $feature->hseqname() if ( $feature );

  
    #---- Some extra Parameters if zmenu fails to return a standard zmenu in the else section----# 
    my $fs = $feat_adap->can( 'fetch_all_by_hit_name' ) ? $feat_adap->fetch_all_by_hit_name($hit_name)
	: $feat_adap->can( 'fetch_all_by_probeset' ) ? $feat_adap->fetch_all_by_probeset($hit_name)
	:                                              []
	;  
    my $logic_name = "";
    $logic_name = ($feature) ? ($feature->analysis->logic_name) : ($fs->[0]->analysis->logic_name) if ($fs->[0]);

    my $external_db_id = ($fs->[0] && $fs->[0]->can('external_db_id')) ? $fs->[0]->external_db_id : '';
    my $extdbs         = $external_db_id ? $hub->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'external_db'}{'entries'} : {};
    my $hit_db_name    = $extdbs->{$external_db_id}{'db_name'} || 'External Feature';
    

    #ZMENU TYPE:
    #Overlaps and false gaps  
    
    if ( $logic_name =~ /overlap/ ) {
	
	my $overlap_name = $feature->hseqname();
	my $percent = $feature->percent_id();
	my $hstart  = $feature->hstart; 
	my $hend    = $feature->hend;
	my $strand  = $feature->strand;
	my $hlength = $hend - $hstart +1;
	
	$self->add_entry({
	    'type'     => "length",
	    'label'    => "$hlength",
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
	    });
	    
	    my $overlap_variation = 100 - $feature->percent_id();
	    $self->add_entry({ 
		'type'     => "Variation ",
		'label'    => sprintf("%3.2f \%", $overlap_variation),
	    });
	    
      	    ## Legacy link to see alignment, using cigar line via the OverlapAlignment.pm module.  Uncomment to view	    
	    #my $alignment_url = $hub->url({'type'=>'Location','action'=>'OverlapAlignment','dbid'=>$feature->dbID, 'db'=>$db});	    
	    #$self->add_entry({ 		
	    #    'label'     => "View alignment",
	    #	'link'      => $alignment_url,
	    #});
	}
	
	#--- Certificate data---#
	if ($attrib_hash{ "cert_category" } ) {
	    $self->add_entry({ 	'label'     => $attrib_hash{ "cert_category" }->value(),
				'type'      => "Certificate Category",
			     }); 
	}
	if ($attrib_hash{ "cert_date" } ) {
	    $self->add_entry({ 	'label'     => $attrib_hash{ "cert_date" }->value(),
				'type'      => "Certificate Date",
			     }); 
	}
	if ($attrib_hash{ "cert_status" } ) {
	    $self->add_entry({ 	'label'     => $attrib_hash{ "cert_status" }->value(),
				'type'      => "Certificate Status",
			     }); 
	}
	if ($attrib_hash{ "cert_comment" } ) {
	    $self->add_entry({ 	'label'     => $attrib_hash{ "cert_comment" }->value(),
				'type'      => "Certificate Comment",
			     }); 
	}
	if ($attrib_hash{ "cert_evidence" } ) {
	    $self->add_entry({ 	'label'     => $attrib_hash{ "cert_evidence" }->value(),
				'type'      => "Certificate Evidence",
			     }); 
	}


	if ($attrib_hash{ "prev_bad_over" } ) {
	    my $pre_bad = $feat_adap->fetch_by_dbID($attrib_hash{ "prev_bad_over" }->value() );
	    my $region  = $pre_bad->slice->seq_region_name . ":" .$pre_bad->start . "-" .$pre_bad->end;
	    my $fv_url  = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Previous lowquality overlap",
		'link'     => $fv_url,
	    });
	}

	if ($attrib_hash{ "prev_over" } ) {
	    my $pre_bad = $feat_adap->fetch_by_dbID($attrib_hash{ "prev_over" }->value() );
	    my $region  = $pre_bad->slice->seq_region_name . ":" .$pre_bad->start . "-" .$pre_bad->end;
	    my $fv_url  = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Previous good overlap",
		'link'     => $fv_url,
	    });
	}

	if ($attrib_hash{ "next_bad_over" } ) {
	    my $pre_bad = $feat_adap->fetch_by_dbID($attrib_hash{ "next_bad_over" }->value() );
	    my $region  = $pre_bad->slice->seq_region_name . ":" .$pre_bad->start . "-" .$pre_bad->end;
	    my $fv_url  = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Next lowquality overlap",
		'link'     => $fv_url,
	    });
	}
	
	if ($attrib_hash{ "next_over" } ) {
	    my $pre_bad = $feat_adap->fetch_by_dbID($attrib_hash{ "next_over" }->value() );
	    my $region  = $pre_bad->slice->seq_region_name . ":" .$pre_bad->start . "-" .$pre_bad->end;
	    my $fv_url  = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Next good overlap",
		'link'     => $fv_url,
	    });
	}
	
	if ($attrib_hash{ "prev_prob_join" } ) {
	    my $pre_prob = $feat_adap->fetch_by_dbID($attrib_hash{ "prev_prob_join" }->value() );
	    my $region   = $pre_prob->slice->seq_region_name . ":" .$pre_prob->start . "-" .$pre_prob->end;
	    my $fv_url   = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Previous bad join",
		'link'     => $fv_url,
	    });
	}
	
	if ($attrib_hash{ "next_prob_join" } ) {
	    my $next_prob = $feat_adap->fetch_by_dbID($attrib_hash{ "next_prob_join" }->value() );
	    my $region    = $next_prob->slice->seq_region_name . ":" .$next_prob->start . "-" .$next_prob->end;
	    my $fv_url    = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Next bad join",
		'link'     => $fv_url,
	    });
	}
	
	if ($attrib_hash{ "prev_false" } ) {
	    my $pre_false = $feat_adap->fetch_by_dbID($attrib_hash{ "prev_false" }->value() );
	    my $region    = $pre_false->slice->seq_region_name . ":" .$pre_false->start . "-" .$pre_false->end;
	    my $fv_url    = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Previous false gap",
		'link'     => $fv_url,
	    });
	}
	
	if ($attrib_hash{ "next_false" } ) {
	    my $next_false = $feat_adap->fetch_by_dbID($attrib_hash{ "next_false" }->value() );
	    my $region     = $next_false->slice->seq_region_name . ":" .$next_false->start . "-" .$next_false->end;
	    my $fv_url     = $hub->url({'type'=>'Location','action'=>'View','ftype'=>$obj_type,'r'=>$region,'db'=>$db});
	    $self->add_entry({ 
		'label'    => "Next false gap",
		'link'     => $fv_url,
	    });
	}
  }
  else {
    $self->caption("$id ($hit_db_name)");
    if ($hit_name) {
        $self->add_entry({
	  'type'  => "Hitname",
          'label' => $hit_name,
        });
    }  
    my $URL = CGI::escapeHTML( $hub->get_ExtURL($hit_db_name, $id) );
    my $label = ($hit_db_name eq 'TRACE') ? 'View Trace archive' : $id;
    $self->add_entry({
      'label' => $label,
      'link'  => $URL,
    });
    my $fv_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'db'=>$db});
    $self->add_entry({ 
      'label' => "View all hits",
      'link'   => $fv_url,
    }) if ($logic_name);
  
    return ;
   }
}


1;

__END__ 
