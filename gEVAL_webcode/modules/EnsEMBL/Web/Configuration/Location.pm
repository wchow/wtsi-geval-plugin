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

package EnsEMBL::Web::Configuration::Location;
use strict;
use Bio::EnsEMBL::Registry;

use base qw(EnsEMBL::Web::Configuration);

sub caption { return 'Location'; }

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = $self->object ? $self->object->default_action : 'Genome';
}

sub init {
  my $self = shift;
  my $hub  = $self->hub;
  
  $self->SUPER::init;
  
  if (!scalar grep /^s\d+$/, keys %{$hub->multi_params}) {
    my $multi_species = $hub->session->get_data(type => 'multi_species', code => 'multi_species');
    $self->tree->get_node('Multi')->set('url', $hub->url({ action => 'Multi', function => undef, %{$multi_species->{$hub->species}} })) if $multi_species && $multi_species->{$hub->species};
  }
}

sub populate_tree {
  my $self = shift;
  my $hub  = $self->hub;
  
  #--- PGPViewer Additions ---#	

  my $genome_menu = $self->create_node('Genome', 'Whole genome',
    			[qw( genome EnsEMBL::Web::Component::Location::Genome )],
    			{ 'availability' => 1 },
  			);
  
  #-- Add Component Stats sub menu --#
  $genome_menu->append($self->create_node('ComponentStats', 'Component Stats',
                                       [qw ( bottom  EnsEMBL::Web::Component::Location::ComponentStats)],
                                       {'availability' =>   'chromosome'},
                                       ));

  
  my $chr_menu = $self->create_node('Chromosome', 'Chromosome summary',
 	        [qw(
      		    summary EnsEMBL::Web::Component::Location::Summary
      		    image   EnsEMBL::Web::Component::Location::ChromosomeImage
    		)],
    		{'availability' => 'chromosome', 'disabled' => 'This sequence region is not part of an assembled chromosome' }
  		);

  #-- Add TPF View sub menu --#	
  $chr_menu->append($self->create_node('TPFlist', 'TPF View',
                                       [qw ( bottom  EnsEMBL::Web::Component::Location::TPFlist)],
                                       {'availability' =>  1 },
                                       ));

  #-- Add Marker Overview Sub Menu--#
  $chr_menu->append($self->create_node('MarkerOverview', 'Marker Overview',
                                       [qw (bottom  EnsEMBL::Web::Component::Location::MarkerOverview)],
                                       {'availability' => 1 },
                                       ));


  $self->create_node('Overview', 'Region overview',
    [qw(
      summary EnsEMBL::Web::Component::Location::Summary
      nav     EnsEMBL::Web::Component::Location::ViewBottomNav/region
      top     EnsEMBL::Web::Component::Location::Region
    )],
    { 'availability' => 'slice'}
  );

  $self->create_node('View', 'Region in detail',
    [qw(
      summary EnsEMBL::Web::Component::Location::Summary
      top     EnsEMBL::Web::Component::Location::ViewTop
      botnav  EnsEMBL::Web::Component::Location::ViewBottomNav
      bottom  EnsEMBL::Web::Component::Location::ViewBottom
    )],
    { 'availability' => 'slice' }
  );

  my $align_menu = $self->create_node('Multi', 'Comparative Analysis',
    [qw(
      summary  EnsEMBL::Web::Component::Location::MultiIdeogram
      selector EnsEMBL::Web::Component::Location::MultiSpeciesSelector
      top      EnsEMBL::Web::Component::Location::MultiTop
      botnav   EnsEMBL::Web::Component::Location::MultiBottomNav
      bottom   EnsEMBL::Web::Component::Location::MultiBottom
    )],
    { 'availability' => 'slice database:compara has_pairwise_alignments', 'concise' => 'Region Comparison' }
   );

  
  $align_menu->append($self->create_subnode('ComparaGenomicAlignment', '',
    [qw( gen_alignment EnsEMBL::Web::Component::Location::ComparaGenomicAlignment )],
    { 'no_menu_entry' => 1 }
  ));
  
  
  $self->create_node('Marker', 'Markers',
    [qw(
      summary EnsEMBL::Web::Component::Location::Summary
      botnav  EnsEMBL::Web::Component::Location::ViewBottomNav
      marker  EnsEMBL::Web::Component::Location::MarkerList
    )],
    { 'availability' => 'slice has_markers' }
  );

  $self->create_node('Soma', 'Soma',
    [qw(
      botnav  EnsEMBL::Web::Component::Location::ViewBottomNav
      soma  EnsEMBL::Web::Component::Location::SomaList
    )],
    { 'availability' => 1, 'no_menu_entry' => 1}
  );

  $self->create_subnode(
    'Output', 'Export Location Data',
    [qw( export EnsEMBL::Web::Component::Export::Output )],
    { 'availability' => 'slice', 'no_menu_entry' => 1 }
  );
}
    

sub get_other_browsers_menu {
  my $self = shift;
  # The menu may already have an other browsers sub menu from Ensembl, if so we add to this one, otherwise create it
  return $self->{'browser_menu'} ||= $self->get_node('OtherBrowsers') || $self->create_submenu('OtherBrowsers', 'Other genome browsers');
}

1;
