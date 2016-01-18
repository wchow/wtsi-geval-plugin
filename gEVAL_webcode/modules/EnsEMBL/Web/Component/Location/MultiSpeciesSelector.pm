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


package EnsEMBL::Web::Component::Location::MultiSpeciesSelector;

use strict;
use base qw(EnsEMBL::Web::Component::MultiSelector);

sub _init {
  my $self = shift;
  
  $self->SUPER::_init;

  $self->{'link_text'}       = 'Select species';
  $self->{'included_header'} = 'Selected species';
  $self->{'excluded_header'} = 'Unselected species';
  $self->{'panel_type'}      = 'MultiSpeciesSelector';
  $self->{'url_param'}       = 's';
  $self->{'rel'}             = 'modal_select_species';
}

sub content_ajax {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $params          = $hub->multi_params; 
  my $alignments      = $species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'} || {};
  my $primary_species = $hub->species;
  my %shown           = map { $params->{"s$_"} => $_ } grep s/^s(\d+)$/$1/, keys %$params; # get species (and parameters) already shown on the page
  my $object          = $self->object;
  my $start           = $object->seq_region_start;
  my $end             = $object->seq_region_end;
  my $intra_species   = ($hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'INTRA_SPECIES_ALIGNMENTS'} || {})->{'REGION_SUMMARY'}{$primary_species}{$object->seq_region_name};
  my $chromosomes     = $species_defs->ENSEMBL_CHROMOSOMES;
  my %species;
  
  foreach my $alignment (grep $start < $_->{'end'} && $end > $_->{'start'}, @$intra_species) {
    my $type = lc $alignment->{'type'};
    my ($s)  = grep /--$alignment->{'target_name'}$/, keys %{$alignment->{'species'}};
    my ($sp, $target) = split '--', $s;
    s/_/ /g for $type, $target;
    
    $species{$s} = $species_defs->species_label($sp, 1) . (grep($target eq $_, @$chromosomes) ? ' chromosome' : '') . " $target - $type";
  }
  
  foreach my $i (grep { $alignments->{$_}{'class'} =~ /pairwise/ } keys %$alignments) {
    foreach (keys %{$alignments->{$i}->{'species'}}) {
	 
     next if ($species_defs->species_label($_,1) =~ /Ancestral sequence/);  ### wc2 do not display.
     if ($alignments->{$i}->{'species'}->{$primary_species} && $_ ne $primary_species) {
        my $type = lc $alignments->{$i}->{'type'};
           $type =~ s/_net//;
           $type =~ s/_/ /g;
	   $type = "MUMmer";  # its all MUMmer now.
        
        if ($species{$_}) {
          $species{$_} .= "/$type";
        } else {
          $species{$_} = $species_defs->species_label($_, 1) . " - $type";
        }
      }
    }
  }
  
  if ($shown{$primary_species}) {
    my ($chr) = split ':', $params->{"r$shown{$primary_species}"};
    $species{$primary_species} = $species_defs->species_label($primary_species, 1) . " - chromosome $chr";
  }
  
  $self->{'all_options'}      = \%species;
  $self->{'included_options'} = \%shown;
  
  $self->SUPER::content_ajax;
}

1;
