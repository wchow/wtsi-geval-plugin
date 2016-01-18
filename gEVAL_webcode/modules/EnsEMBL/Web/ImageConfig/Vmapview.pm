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

package EnsEMBL::Web::ImageConfig::Vmapview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Chromosome panel',
    'label'         => 'above',     # margin
    'band_labels'   => 'on',
    'image_height'  => 450,
    'image_width'   => 500,
    'top_margin'    => 40,
    'band_links'    => 'yes',
    'spacing'       => 10
  });

  $self->create_menus( 
      'features' => 'Features', 
      'user_data'  => 'User attached data', # DAS/URL tracks/uploaded data/blast responses
  );

  $self->add_tracks( 'features',
    [ 'drag_left', '', 'Vdraggable', { 'display' => 'normal', 'part' => 0, 'menu' => 'no' } ],
    [ 'Videogram', 'Ideogram', 'Videogram', {
      'display'   => 'normal',
      'colourset' => 'ideogram',
      'renderers' => [qw(normal normal)],
    } ],
# kb8: disable these in the chromosome overview page
#    [ 'Vgenes',    'Genes',    'Vdensity_features', {
#      'same_scale' => 1,
#      'display'   => 'density_outline',
#      'colourset' => 'densities',
#      'renderers' => ['off' =>  'Off',
#                      'density_outline' => 'Bar chart',
#                      'density_graph'  =>  'Lines'],
#      'keys'      => [qw(geneDensity knownGeneDensity)],
#    }],
#    [ 'Vpercents',  'Percent GC/Repeats',    'Vdensity_features', {
#      'same_scale' => 1,
#      'display'   => 'density_mixed',
#      'colourset' => 'densities',
#      'renderers' => ['off' => 'Off', 'density_mixed' => 'Histogram and line'],
#      'keys'      => [qw(PercentGC PercentageRepeat)]
#    }],
#    [ 'Vsnps',      'Variations',    'Vdensity_features', {
#      'display'   => 'density_outline',
#      'colourset' => 'densities',
#      'maxmin'    => 1,
#      'renderers' => ['off' => 'Off', 
#                      'density_line'    => 'Line graph', 
#                      'density_bar'     => 'Bar chart - filled',
#                      'density_outline' => 'Bar chart - outline',
#                      ],
#      'keys'      => [qw(snpDensity)],
#    }],
    [ 'drag_right', '', 'Vdraggable', { 'display' => 'normal', 'part' => 1, 'menu' => 'no' } ],
  );
}


1;

