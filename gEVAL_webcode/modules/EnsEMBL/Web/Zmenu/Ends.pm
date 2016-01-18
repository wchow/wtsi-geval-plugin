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

package EnsEMBL::Web::ZMenu::Ends;

use strict;
use base qw(EnsEMBL::Web::ZMenu);

#--------------------------------#
#--------------------------------#
# Zmenu for clone ends/reads     #
#  Currently linked with the     #
#  geval_ends_link.pm glyph      #
#  Will need an audit of this    #
#  with human and mouse, as only #
#  zfish uses geval_ends_link.   #
#                                #
#   -wc2@sanger                  # 
#--------------------------------#
#--------------------------------#



#----------------------------------------------------#
# Main Bit.
#  Fetches glyph info and proceeds to add to zmenu.
#----------------------------------------------------#

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;


  ## Read in the params from the glyph.
  my $id                = $hub->param('id');
  my $dbID              = $hub->param('dbid');
  my $obj_type          = $hub->param('ftype');
  my $db                = $hub->param('fdb') || $hub->param('db') || 'core'; 
  my $logic_name        = $hub->param('logic_name');
  my $grp_items         = $hub->param('grpitems');
  my $span_status       = $hub->param('span');
  my $species           = $hub->param('s1');      # Name of the 'other' species primarily added for compara
  my $totalcounts       = $hub->param('totalcounts');
  my $fpccheck          = $hub->param('fpccheck');
  my $logic_name        = $hub->param('logic_name');      
  my $percent           = $hub->param('perc_id') || undef;
  my $hlength           = $hub->param('hlength') || undef;  
  my $extra_data        = $hub->param('extra_data');

 # e73 code has made the caption to become a function instead of a obj attrib. 
  $self->caption($id);

  if ( ($logic_name =~ /end_|fos|bac/ || $logic_name =~ /cap_wgs|capillary|ungrouped|454_20kb/) && $dbID ) {
      
      my ($clone_name, $distance) = $id =~ /^(.*) distance: (.*)/;

      my ($int_name, $chem, $matepair_id) = split (/\./, $extra_data);
      my @mpids = split (",", $matepair_id);
      
      ## If the id has distance in it (legacy thing), but represents paired reads.ends.
      if ( $id =~ /distance/ ) { # This is the paired read blocks
	  
	  ## Caption and clone name to display.
	  $self->caption($clone_name);
	  $self->add_entry({
	      'type'     => "Clone id",
	      'label'    => "$clone_name",
	      'priority' => 101,
	  });
	  
	  ## Distance between items, nuff said.
	  $self->add_entry({
	      'type'     => "Distance",
	      'label'    => "$distance ",
	      'priority' => 100,
	  });
	  
	  ## priority for listing items in zmenu.
	  my $priority = 90;

	  ## Since these are read/end pair joins, return the readnames and featcounts in this link.
	  my @region_features = split("&", $grp_items);
	  
	  foreach my $region_feature ( @region_features ) {
	      my ($rfeat_name, $rfeat_count, $rfeat_region) = ($region_feature =~ /(.*)(\(\d+\))\[(.*)\]/);
	      
	      my $hit_url =  $hub->url({   'type'    => 'Location', 
					   'action'  => 'View', 
					   'r'       => $rfeat_region, 
					   'h'       => $rfeat_name, 
					   'species' => $species,  
					   __clear   => 1,});
	      
	      $self->add_entry({
		  'label'    => $rfeat_name.$rfeat_count,
		  'link'     => $hit_url,
		  'priority' => $priority--,
	      });
	  }

	  ## This link highlights the read in the window(s). Originally created for compara comparison.
	  (my $end2tag = $region_features[0]) =~ s/\(\d+\).*//;
	  my $uri = ($hub->referer)->{absolute_url};
	  
	  $uri =~ s/h=.+?;//;
	  $uri =~ s/;h=.+?$//;
	  $uri .= ";h=$end2tag";
	  $self->add_entry({ 
	      'label'    => "Highlight Seq",
	      'link'     => $uri,
	      'priority' => 60,
	  }); 
	  
      }
      else {
	  
	  ## Clone name, minus all the record ids.
	  $self->caption($id);
	  (my $clone_name = $id)=~ s/\..*|SP6|T7//;
	  $self->add_entry({
	      'type'     => "Clone id",
	      'label'    => $clone_name,
	      'priority' => 101,
	  });

	  ## Internal name, with chem, nuff said.
	  $self->add_entry({
	      'type'     => "Internal name",
	      'label'    => "$int_name.$chem ",
	      'priority' => 100,
	  }) if ($int_name);
	  

	  ## Hit length, nuff said.
	  $self->add_entry({
	      'type'     => "Hit length",
	      'label'    => $hlength,
	      'priority' => 100,
	  });

	  ## Percent, nuff said.
	  $self->add_entry({
	      'type'     => "Percent id",
	      'label'    => $percent,
	      'priority' => 90,
	  });
	  

	  ## This link is to point to the external records.
	  (my $ext_id = $id) =~ s/.*\.//;	  
	  my $ext_url = "http://www.ncbi.nlm.nih.gov/Traces/trace.cgi?cmd=retrieve&val=$ext_id";    		
	  $ext_url    = "http://www.ncbi.nlm.nih.gov/nucgss/$ext_id" if ($id =~/rp/i); #RP libraries only in gss
	  
	  if ($ext_id =~ /^\d+$/){
	      $self->add_entry({
		  'type'    => "Record",
		  'label'    => $id,
		  'link'     => $ext_url,
		  'priority' => 80,
	      });
	  }
	  

	  ## This link lists the total hits of the read in norep/rep.
	  $self->add_entry({ 
	      'type'     => "Total hits",
	      'label'    => $totalcounts,
	      'priority' => 15,
	  });
	  
	  
	  ## This link lists all the mate/end pairs the read in question is linked with. 
	  foreach my $mp (@mpids){
	      my $mp_url = $hub->url({   'type'     => 'Location',
					 'action'   => 'Genome',
					 'ftype'    => $obj_type,
					 'id'       => "$clone_name.$mp",
					 'db'       => $db, 
					 'species'  => $species,  
					 __clear    => 1,});
	      $self->add_entry({ 
		  'type'     => "matepair",
		  'label'    => "$clone_name.$mp",
		  'link'     => $mp_url,
		  'priority' => 10,
	      });
	  }
	  

	  ## This link is for viewing all hits of the read.
	  my $fv_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>$obj_type,'id'=>$id,'db'=>$db,'species' => $species, __clear=> 1, });
	  $self->add_entry({ 
	      'label'    => "View all hits",
	      'link'     => $fv_url,
	      'priority' => 10,
	  });
	  
	  
	  ## This link highlights the read in the window(s). Originally created for compara comparison.
	  my $uri = ($hub->referer)->{absolute_url};	  
	  $uri =~ s/h=.+?;//;
	  $uri =~ s/;h=.+?$//;
	  $uri .= ";h=$id";
	  $self->add_entry({ 
	      'label'    => "Highlight Seq",
	      'link'     => $uri,
	      'priority' => 60,
	  });
	  
  
      }

      ## This is to add the spanner link for single reads (spanner, or gapspanner).
      if ($span_status){	  
	  my ($span_type, $cmp_name, $span_region) = split (":", $span_status);
	  
	  my $fv_url = $hub->url({'type'    => 'Location',
				  'action'  => 'View',
				  'ftype'   => $obj_type,
				  'r'       =>"$cmp_name:$span_region",
				  'db'      => $db,
				  'species' => $species,
				  __clear   => 1,
			      });	    
	  
	  if ($span_type eq "gapspan"){
	      $self->add_entry({ 
		  'label'    => "Show gap spanning pair",
		  'link'     => $fv_url,
		  'priority' => 60,
	      });
	  }
	  elsif ($span_type eq "span"){
	      $self->add_entry({ 
		  'label'    => "Show spanning pair",
		  'link'     => $fv_url,
		  'priority' => 60,
		});
	  }	    
      }
      
      ## Somewhat of a legacy thing, but I have included, this is to highlight what fpc the end read
      ##   was predicted to be on, but of course fpc's have been changing so much, that its not the most
      ##   accurate information.
      if ($fpccheck){
	  my $fpc_url = $hub->url({'type'=>'Location','action'=>'View','r'=>undef, 'region'=>$fpccheck,});
	  $self->add_entry({
	      'label'    => "FPC: $fpccheck",
	      'link'     => $fpc_url,
	      'priority' => 85,
	  });
      }   
  }
}

1;
