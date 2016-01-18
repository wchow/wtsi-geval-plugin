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

package EnsEMBL::Web::ViewConfig::Location::MultiBottom;

use strict;
use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->set_defaults({
    show_bottom_panel => 'yes'
  });
  
  $self->add_image_config('MultiBottom', 'nodas');
  $self->title = 'Multi-species Image';
  
  $self->set_defaults({
    opt_pairwise_blastz   => 'compact', # wc2, changed default setting to compact
    opt_pairwise_tblat    => 'normal',
    opt_pairwise_lpatch   => 'normal',
    opt_join_genes_bottom => 'off',
  });
}

sub extra_tabs {
  my $self = shift;
  my $hub  = $self->hub;
  
  return [
    'Select species',
    $hub->url('Component', {
      action   => 'Web',
      function => 'MultiSpeciesSelector/ajax',
      time     => time,
      %{$hub->multi_params}
    })
  ];
}

sub form {
  my $self = shift;
  
  $self->add_fieldset('Comparative features');

# wc2 :: Other options not used in PGP viewer
  
  foreach ([ 'blastz', 'PGP Compara alignments (MUMmer)' ]) {
    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => "opt_pairwise_$_->[0]",
      label  => $_->[1],
      values => [
        { value => 0,         name => 'Off'     },
        { value => 'normal',  name => 'Normal'  },
        { value => 'compact', name => 'Compact' },
      ],
    });
  }
  
  $self->add_fieldset('Display options');
  $self->add_form_element({ type => 'YesNo', name => 'show_bottom_panel', select => 'select', label => 'Show panel' });
}

1;
