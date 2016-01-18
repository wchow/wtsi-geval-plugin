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

package EnsEMBL::Web::Component::Location::TPFlist;

### This is a List view of the TPF, indicating options like htgs phases and such.
###  wc2 11/2012

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
  $self->configurable( 0 );
}



sub content {
  my $self = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $species = $object->species;

  my $chr_name = $object->seq_region_name;
  my $label = "Component $chr_name";
  
  my $db_adaptor = $self->hub->database('core');
  my $sa         = $db_adaptor->get_SliceAdaptor();

  my $html = "";

  if ($species !~ /fish/){
	return "<h3>This page is currently only available for zebrafish assemblies</h3>\n";
  }

  # Two options, project to clone slices, but lose out on clone in pipelines, or use misc_feats then project
  # to appropriate slices to extract clone seq_region attrib.

  my @clone_mfs = @{$object->slice->get_all_MiscFeatures('clone')};
  if (@clone_mfs < 1){
      return "<h3>There are no clone miscfeatures for this assembly</h3>\n";
  }
  
  # Group by features, for those that are unfinished can be grouped.

  my %features;
  foreach my $f ( @clone_mfs ){  
    
      my $fgroup_name = $self->feature_group( $f );
      push @{$features{$fgroup_name}}, [$f->seq_region_start,$f->seq_region_end,$f];
  }

  my @columns = (
		 
		 { key => 'name',       sort => 'string',   title => 'Name'           },
		 { key => 'htgs',       sort => 'numeric',  title => 'HTGS phase'     },
		 { key => 'status',     sort => 'string',   title => 'Status'         },
		 { key => 'accession',  sort => 'string',   title => 'Accession'      },
		 { key => 'length',     sort => 'string',   title => 'Length'         },
		 { key => 'start',      sort => 'numeric',  title => 'Region Start'   },
		 { key => 'end',        sort => 'numeric',  title => 'Region End'     },
		 { key => 'jira',       sort => 'string',   title => 'Unresolved Jira'},
		 );
  




  my @rows;
  foreach my $clone ( sort { ${${$features{$a}}[0]}[0] <=> ${${$features{$b}}[0]}[0] }   keys %features){

      my $clone_slice = $sa->fetch_by_region('clone', $clone);
     
      my @cmps = @{$features{$clone}};
     

 

      my ($feat_start, $feat_end);
      # if cmps > 1, its an unfinished clone with multiple ctgs.
      if (@cmps > 1){
	  ($feat_start, $feat_end) =  ($cmps[0][0], $cmps[-1][1]);

      }
      else {
	  ($feat_start, $feat_end) =  ($cmps[0][0], $cmps[0][1]);
      }

      my $url = $hub->url({ type => 'Location', action => 'View', r=> "$chr_name:$feat_start-$feat_end", __clear=>1 });
      my $region_href = qq(<a href=$url rel="_self" style="text-decoration:none">$clone</a><br>);

      my $row;
      if (!$clone_slice){
	  # clone in pipeline;
	  $row =  {
	      name       => {value=>$clone, class => 'bold', style=> 'background-color:lightgrey'},
	      htgs       => {value=>"", style=> 'background-color:lightgrey'}, 
	      status     => {value=>"picked/in pipeline", class => 'bold', style=> 'background-color:lightgrey'}, 
	      accession  => {value=>"", style=> 'background-color:lightgrey'},
	      length     => {value=>"", style=> 'background-color:lightgrey'},	      
	      start      => {value=>"$feat_start", style=> 'background-color:lightgrey'},
	      end        => {value=>"$feat_end", style=> 'background-color:lightgrey'},
	      jira       => {value=>"", style=> 'background-color:lightgrey'},
	  };


	 ;
      }
      else {
	  my ($htgs)      = @{$clone_slice->get_all_Attributes('htgs_phase')};
	  my ($status)    = @{$clone_slice->get_all_Attributes('status_desc')};
	  my ($acc)       = @{$clone_slice->get_all_Attributes('accession')};
	  my $accession = ($acc) ? $acc->value : $clone;
	  my $length      = $clone_slice->seq_region_length;
	  
	  my $htgs_entry = ($htgs) ? $htgs->value : "";
	  $htgs_entry .= " (".@cmps." components)" if (@cmps >1 );
	  if ($htgs) {
	      $htgs_entry = {value=>$htgs_entry, style=>'background-color:#D7DF01'} if ($htgs->value == 2);
	      $htgs_entry = {value=>$htgs_entry, style=>'background-color:orange'} if ($htgs->value == 1);
	  }
	  my $accession_url = qq(<a href="http://www.ebi.ac.uk/ena/data/view/$accession" rel="_self" style="text-decoration:none">$accession</a><br>);

	  # fetch jira issues.
	  my ($clone_proj) = @{$clone_slice->project('toplevel')};
	  my @jira_mf = @{$clone_proj->to_Slice->get_all_MiscFeatures('jira_entry')};
	  my @jira_entries;
	  foreach my $mf (@jira_mf){
	      if ($mf->get_scalar_attribute('jira_status') !~ /resolved/i){
		  push @jira_entries, $mf->get_scalar_attribute('jira_id');
	      }
	  }




	  $row = {
	      name       => {value=>$region_href},
	      htgs       => $htgs_entry, 
	      status     => ($status) ? $status->value : "", 
	      accession  => $accession_url,
	      length     => $length,
	      start      => "$feat_start",
	      end        => "$feat_end",
	      jira       => @jira_entries,
	  };
      }
      push @rows, $row;

  }




  my $table = $self->new_table(\@columns, \@rows, {
      data_table        => 1,
      data_table_config => { asStripClasses => [ '', '' ], oSearch => { sSearch => '', bRegex => 'false', bSmart => 'false' } },
      #class             => 'toggle_table fixed_width',
      id                => 'TPFlist',
      #style             => "", #'display:none' ,
      sorting           => [ 'start asc' ] ,
      exportable        => 0
      });
  
  $html .= $table->render;
  
  $html .= "<br>";



  return $html;
}



sub feature_group{
  my( $self, $f ) = @_;

  my $id = $f->get_scalar_attribute('internal_clone');
  (my $group_name = $id) =~ s/\..*//;
  return $group_name;
}




1;
