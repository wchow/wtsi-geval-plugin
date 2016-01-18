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

package EnsEMBL::Web::ZMenu::CDNA;
use strict;
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::ZMenu);


########################################
#  zmenu for cdna glyphs in PGPviewer  #
#   wc2@sanger may2013                 #
#                                      #
#  -Separated from Genome.pm           #
########################################

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

    my $hcoverage       = $hub->param('cov')   || $feature->hcoverage;
    my $perc_id         = $hub->param('perc')  || $feature->percent_id;
    my $extradata       = $hub->param('extra') || $feature->extra_data;
    my $species         = $hub->param('species');


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
   
    my $logic_name           = $hub->param('logic_name');    
    my ($name, $start, $end) = $region =~ /^(.*):(.*)-(.*)/;

    my $priority = 1000;

#----------------------------------------------------------------------------------------------------------------------------------------------#
#---- This section was used to list all the rows from the hits ie) 1000-2000::1-1000. Removed, may want to implement again in the future   ----#
if (0){

    ## Used with below to fetch the parts of the hits in the region.
    my $coord_sys_name = "toplevel";
    if ($db_adaptor->dbname =~ /wgs/i){
	$coord_sys_name = "supercontig";	
    }

    my $slice_adaptor =  $db_adaptor->get_SliceAdaptor();
    my $dafa          =  $db_adaptor->get_DnaAlignFeatureAdaptor();        
    my $region_slice    = $slice_adaptor->fetch_by_region($coord_sys_name, $name, $start, $end);
    my @region_features = sort {$a->seq_region_start <=> $b->seq_region_end } @{$dafa->fetch_all_by_Slice( $region_slice, $logic_name )};
     foreach my $region_feature ( @region_features ) {
            
       next if ( $region_feature->hseqname ne $id);
       my $entry = $region_feature->seq_region_name.":". $region_feature->seq_region_start . "-" . $region_feature->seq_region_end . "(" . $region_feature->seq_region_strand .")";
       $entry .= " :: ".  $region_feature->hstart . "-" . $region_feature->hend . "(" . $region_feature->hstrand .")";
            
       $self->add_entry({
             'label'    => $entry,
             'priority' => $priority--,
       });

     }
}
#----------------------------------------------------------------------------------------------------------------------------------------------#
    
    my ($cdna_length, $hrank) = (0,"");
    
    ## --Extra data may contain the hitrank, but will definitely have the query length, separated by ":".
    if ($extradata =~ /:/){
	($hrank, $cdna_length) = split (/:/, $extradata);
    }
    else {
	$cdna_length = $extradata;
    }
    
    ## --If there is a gene name then split it. As well create the external record link.    
    my $URL = CGI::escapeHTML( "http://www.ncbi.nlm.nih.gov/nuccore/$id" );
    my ($genename, $acc);
    
    if ($id =~ /\(|\)/){	    
	($genename, $acc)  = ($id =~ /(.*)\((.*)\)/);	    
	$self->caption($genename);
	$URL =  CGI::escapeHTML( "http://www.ncbi.nlm.nih.gov/nuccore/$acc" );	    
    }
    
    if ($id =~ /ccds/i){
	my $ccds_id = ($genename) ? $acc : $id;
	$URL = CGI::escapeHTML( "http://www.ncbi.nlm.nih.gov/projects/CCDS/CcdsBrowse.cgi?REQUEST=CCDS&DATA=$ccds_id" );
    }

    #--------------------------------------------------------------------#
    # ---- This is where the entries for the zmenu will be located. ---- # 
    #--------------------------------------------------------------------#

    ## Caption is the header for the box.
    $self->caption($id);
    $self->caption($id . " ($hrank)") if ($hrank);
    
    ## NCBI Record Link.
    $self->add_entry({
	'type'     => "NCBI:",
	'label'    => ($acc) ? "$acc" : "$id",
	'link'     => $URL,
	'priority' => 10,
    });
        
    ## Gene Name if available.
    $self->add_entry({ 
	'type'    => "Gene Name",
	'label'     => $genename,
	'priority' => 9,
    }) if ($genename);
    
    ## cDNA Length.
    $self->add_entry({
	'type'     => "cDNA length",
	'label'    => "$cdna_length",
	'priority' => 8,
    }) if ($cdna_length);
    
    ## Coverage.
    $self->add_entry({
	'type'     => "Coverage",
	'label'    => "$hcoverage %",
	'priority' => 7,
    }) if ($hcoverage);

    ## Percent Id.
    $self->add_entry({
	'type'     => "Perc ID",
	'label'    => "$perc_id %",
	'priority' => 6,
    }) if ($perc_id);
    
    ## View all the hits.
    my $fv_url = $hub->url({'species'=>$species,'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'db'=>$db, __clear=>1});
    $self->add_entry({ 
	'label'    => "View all hits",
	'link'     => $fv_url,
	'priority' => 5,
    });

    return;    
    
}


1;
