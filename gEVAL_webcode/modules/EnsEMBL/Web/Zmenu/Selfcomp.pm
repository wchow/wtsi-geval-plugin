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

package EnsEMBL::Web::ZMenu::Selfcomp;
use strict;
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::ZMenu);

#-------------------------------------#
#				      #			
#  This Zmenu is specifically used    #
#  for the selfcomp track in the      #
#  pgpviewer.			      #	
#  				      #
#   wc2@sanger.ac.uk 		      #	
#-------------------------------------#

#-------------–––--------#
# content  
#  main code for control
#  and display of the info 
#  for the zmeunu.
#------------------------#
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

    my $fs = $feat_adap->can( 'fetch_all_by_hit_name' ) ? $feat_adap->fetch_all_by_hit_name($hit_name)
        : $feat_adap->can( 'fetch_all_by_probeset' ) ? $feat_adap->fetch_all_by_probeset($hit_name)
        :                                              []
        ;

    my $logic_name = "";
    $logic_name = ($feature) ? ($feature->analysis->logic_name) : ($fs->[0]->analysis->logic_name) if ($fs->[0]);


# ZMENU TYPE: 
# selfcomp track zmenu  
# print STDERR "========== SELFCOMP ================ \n";

    my ($name, $start, $end) = $region =~ /^(.*):(.*)-(.*)/;

    my $slice_adaptor =  $db_adaptor->get_SliceAdaptor();
    my $dafa          =  $db_adaptor->get_DnaAlignFeatureAdaptor();
    my $region_slice  =  $slice_adaptor->fetch_by_region(undef, $name, $start, $end);

    my @region_features = sort {$a->seq_region_start <=> $b->seq_region_end } @{$dafa->fetch_all_by_Slice( $region_slice, $logic_name )};


    #############################################################################################
    # WILL ADD :: To get hit information NOTE: Will be dangerous for human clones within clones #
    #############################################################################################
    my $hit_location = $region_features[0]->hseqname;
    my ($accession, $int_name, $ext_name, $attrib_type); #ext_num for misc_attrib table, which is diff in zfish and human.
    if ($id =~ /:/){
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

    ## Zebrafish format using internal names as key, and accessions as attribs, needs to be taken into account. ##
    my @zfish_accessions = @{$hit_slice->get_all_Attributes('accession')};
    my $zfish_accession;
    if (@zfish_accessions > 0){
        $zfish_accession = "[".$zfish_accessions[0]->value."]";
    }

    my @projection = @{ $hit_slice->project('toplevel') };
    my $hit_chr    = $projection[0]->to_Slice->seq_region_name;

    my $mfa  = $db_adaptor->get_MiscFeatureAdaptor();
    my @feat = @{$mfa->fetch_all_by_attribute_type_value($attrib_type, $ext_name)};

    my ($mf_start, $mf_end) = (undef, undef);
    ###This was added to work with unfinished misc_features, taking the first ctg, and last ctg and getting the start/end (chr level).
    if (@feat < 1){
	
        ($mf_start, $mf_end) = &get_unfin_clone_coord($mfa, $attrib_type, $hit_slice);
	($mf_start, $mf_end) = (undef, undef) if (!$mf_start && !$mf_end);
    }
    else{
         $mf_start = $feat[0]->start;
         $mf_end   = $feat[0]->end;
    }
    my ($region_start, $region_end, $region_strand) = (0,0,undef);
    my $url        = $hub->url({'type' => 'Location', 'action' => 'View', 'region' => $accession, '__clear' => 1});

    #------ Add entries to zmenu ------#	
    $self->add_entry({
        'label'    => "Center on $id $zfish_accession",
        'link'     => $url,
    });

# --- wc2 Not really used, but will keep around if anyone asks for it again.#
#
#    my $shown_region      = $hub->param('region');
#    my $url2  = $hub->url({'type' => 'Location', 'action' => 'Dotplot', 'r' => $shown_region, 'id' => $accession, '__clear' => 1});
#    $self->add_entry({
#        'label'    => "Show dotplot",
#        'link'     => $url2,
#    });

    #--- Show query/target hit coordinates ---#
    foreach my $region_feature ( @region_features ) {
        next if ( $region_feature->hseqname !~ /$id/);

        my ($hit_start, $hit_end);
        if ($region_feature->hstrand eq 1){
            $hit_start = $mf_start + ($region_feature->hstart);
            $hit_end   = $mf_start + ($region_feature->hend);
        }
        else {
            $hit_start = (!$mf_start) ? ($region_feature->hstart) : ($mf_start + ($region_feature->hstart));
            $hit_end   = (!$mf_end)   ? ($region_feature->hend)   : ($mf_end   + ($region_feature->hstart));
        }

        my $entry = "[chr.".$region_feature->seq_region_name."]:". $region_feature->seq_region_start . "-" . $region_feature->seq_region_end . "(" . $region_feature->seq_region_strand .")";
        #$entry .= " :: [".$int_name."]:". $region_feature->hstart . "-" . $region_feature->hend . "(" . $region_feature->hstrand .")";
        $entry .= " :: [".$int_name."]:". $hit_start  . "-" . $hit_end. "(" . $region_feature->hstrand .")";

        $self->add_entry({
            'label' => $entry,
        });

        #get range of the hit.
        if (($region_feature->seq_region_strand eq 1)     && ($region_start eq 0)){          $region_start = $hit_start;  }
        if (($region_feature->seq_region_strand eq 1)     && ($hit_end > $region_end)){      $region_end   = $hit_end;  }
        if (($region_feature->seq_region_strand eq -1)    && ($region_end eq 0)){            $region_end   = $hit_end;  }
        if (($region_feature->seq_region_strand eq -1)    && ($region_start eq 0)){          $region_start = $hit_start;  }
        elsif (($region_feature->seq_region_strand eq -1) && ($hit_start < $region_start)){  $region_start = $hit_start;  }
	
    }

    $self->caption("$id (chr:$hit_chr) $region_start - $region_end");

    my $hit_region = "$hit_chr:$region_start-$region_end";
    

    my $hiturl     = $hub->url({'type' => 'Location', 'action' => 'View', 'r' => $hit_region, '__clear' => 1});
    $self->add_entry({
        'label'    => "Center on these hit(s)",
        'link'     => $hiturl,
    });
                                                                  
}	


#-------------------------#
# get_unfin_clone_coord
#  used to fetch the real
#  start and end of an
#  unfinished clone.
#-------------------------#
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





