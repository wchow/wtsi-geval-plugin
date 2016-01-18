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

# $Id: contigviewtop.pm,v 1.38 2013-04-02 09:51:32 sb23 Exp $

package EnsEMBL::Web::ImageConfig::contigviewtop;

use strict;

use JSON;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    sortable_tracks  => 'drag', # allow the user to reorder tracks on the image
    opt_empty_tracks => 0,      # include empty tracks
    opt_lines        => 1,      # draw registry lines
    min_size         => 1e6 * ($self->hub->species_defs->ENSEMBL_GENOME_SIZE || 1),
  });
  
  $self->create_menus(qw(
    sequence
    marker
    transcript
    misc_feature
    synteny
    variation
    decorations
    information
  ));
  
  $self->add_track( 'sequence',    'contig', 'Contigs',     'contig', { display => 'normal', strand => 'f' });
#  $self->add_track( 'sequence',    'fpc_contig','FPC contig', 'gEVAL_fpc', { 'display' => 'normal', 'strand' => 'f', genoverse => { fixedHeight => JSON::true, cache => 'chr', allData => JSON::true, labels => 'overlay' }});
  $self->add_pgp_track( 'sequence',    'fpc_contig','FPC contig', 'gEVAL_fpc', { 'display' => 'normal', 'strand' => 'f', 'description' => 'FPC Contigs on assembly path', genoverse => { type => 'Contig', cache => 'chr' }}, 'sequence');
  $self->add_pgp_track( 'sequence',    'scaffold', 'Scaffolds', 'gEVAL_scaf',  { 'display' => 'off', 'strand' => 'f', 'description' => 'Scaffolds on assembly path', genoverse => { type => 'Contig', cache => 'chr' }}, 'sequence' );

  $self->add_pgp_track( 'marker',    'markers','Markers',          'gEVAL_marker',
		       {'labels'      => 'on',
                        'colours'     => $self->species_defs->colour( 'marker' ),
                        'description' =>'Project Specific Markers, (satellites, SNPs etc.)',
                        'display'     => 'off',
                        'renderers'   => [qw(off Off normal Normal labels Detailed_labels)],
                        'strand'      => 'r'  },  'marker');


  $self->add_track('information', 'info',   'Information', 'text',   { display => 'normal'                });
  
  $self->load_tracks;
  $self->image_resize = 1;
  
  $self->modify_configs([ 'transcript' ], { render => 'gene_label', strand => 'r' });
  $self->modify_configs([ 'variation',  'variation_legend', 'structural_variation_legend' ], { display => 'off', menu => 'no' });
  $self->modify_configs([ 'chr_band_core' ], { genoverse => { type => 'ChrBand', cache => 'chr' } });

  
  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', menu => 'no'                }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', menu => 'no', strand => 'f' }],
    [ 'draggable', '', 'draggable', { display => 'normal', menu => 'no'                }]
  );
}

1;
