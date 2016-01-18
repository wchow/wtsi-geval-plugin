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

package EnsEMBL::Web::Component::Location::ComponentStats;

use strict;
use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::Controller::SSI;
use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}



sub content {
  my $self = shift;
  my $id   = $self->hub->param('id'); 

  my $hub          = $self->hub;
  my $species      = $hub->species;
  my $species_defs = $hub->species_defs;
  my $chromosomes  = $species_defs->ENSEMBL_CHROMOSOMES || [];
  my %chromosome   = map {$_ => 1} @$chromosomes;
  my $sa           = $hub->database('core')->get_SliceAdaptor();
  my $csa          = $hub->database('core')->get_CoordSystemAdaptor();
  my $top_slices   = $sa->fetch_all('toplevel');
  my $html;

  my $coordcheck = $csa->fetch_by_name('clone');

  if ( (@$top_slices > 100) || (!$coordcheck) ){

      $html .= "<h4>The statistics is currently not available with this viewer</h4>";
      return $html;
  }


  # sequencing stats per chromosome
  my @rows;
  foreach my $topslice (@{$top_slices}){
      next if (!( $chromosome{$topslice->seq_region_name}));
      
      my ($htgs1, $htgs2, $htgs3, $pickedclones) = (0,0,0,0);

      ($htgs1) = @{$topslice->get_all_Attributes('htgs1_stat')};
      ($htgs2) = @{$topslice->get_all_Attributes('htgs2_stat')};
      ($htgs3) = @{$topslice->get_all_Attributes('htgs3_stat')};
      ($pickedclones) = @{$topslice->get_all_Attributes('picked_stat')};
      
      $htgs1 = $htgs1->value if ($htgs1);
      $htgs2 = $htgs2->value if ($htgs2);
      $htgs3 = $htgs3->value if ($htgs3);
      $pickedclones = $pickedclones->value if ($pickedclones);

      
      # If there are no seq_region_attribs, calculate via DB...SLOW!!!!
      if (!$htgs1 && !$htgs2 && !$htgs3 && !$pickedclones){
	  #$html .= "<small>Stats</small><br>";

	  ($htgs1, $htgs2, $htgs3) = &fetch_chr_stats($topslice);

	  if ($htgs1 == -1){
	      $html .= "<h4>The statistics is currently not available with this viewer</h4>";
	      return $html;
	  }
	      
	  $pickedclones            = &fetch_clones_picked($topslice);
      }

      my $row  =  {   'name'   => $topslice->seq_region_name,  
		      'htgs1'  => $htgs1 || 0,
		      'htgs2'  => $htgs2 || 0,
		      'htgs3'  => $htgs3 || 0,
		      'picked' => $pickedclones || 0,
		  };     	            
      push @rows, $row if ($htgs1 || $htgs2 || $htgs3 || $pickedclones);
  }
  
  if (@rows > 0){
      
      my @columns = (
		     {  key => 'name',    sort => 'string',   title => 'Chr/Region'   },
		     {  key => 'htgs1',   sort => 'numeric',  title => 'htgs phase 1' }, 
		     {  key => 'htgs2',   sort => 'numeric',  title => 'htgs phase 2' }, 
		     {  key => 'htgs3',   sort => 'numeric',  title => 'htgs phase 3' }, 
		     {  key => 'picked',  sort => 'numeric',  title => 'Clones yet to be sequenced' }, 

		     );

      my $table = $self->new_table(\@columns, \@rows, {
	  data_table        => 1,
	  data_table_config => { asStripClasses => [ '', '' ], oSearch => { sSearch => '', bRegex => 'false', bSmart => 'false' } },
	  id                => 'htgscounts',
	  sorting           => [ 'name asc' ] ,
	  exportable        => 0
	  });
      
      $html .= $table->render;
  }
  else {
      $html .= "<h4>The statistics is currently not available with this viewer</h4>";
  }
  
  return $html;
}



sub fetch_chr_stats{
    my $slice = shift;

    my @projections = @{$slice->project('clone')};

    my ($htgsstat1, $htgsstat2, $htgsstat3) = (0,0,0);

    if (@projections > 0){
	my @clone_slices = map ($_->to_Slice, @projections);
	
	foreach my $clone (@clone_slices){

	    my ($htgs)      = @{$clone->get_all_Attributes('htgs_phase')};
	    
	    if ($htgs){
		$htgsstat1++ if ($htgs->value == 1);
		$htgsstat2++ if ($htgs->value == 2);
		$htgsstat3++ if ($htgs->value == 3);
	    }
	    else {
		# this assembly has no htgs phase attrib so no counts available, return flag to end stats calc.
		return (-1);
	    }
	}
    }
    else {
	return (0,0,0);
    }

    return (0,0,0) if (!$htgsstat1 && !$htgsstat2 && !$htgsstat3);
    
    return ($htgsstat1, $htgsstat2, $htgsstat3);

    
}


sub fetch_clones_picked {

    my $slice = shift;

    my @miscfeats = @{$slice->get_all_MiscFeatures('clone')};
    
    my $pickedclones = 0;
    foreach my $feat (@miscfeats){

	$pickedclones++ if ($feat->get_scalar_attribute('clone_status') =~ /not yet sequenced/);
    }

    return $pickedclones;

}


1;
