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

package EnsEMBL::Web::ImageConfig::cytoview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title             => 'Overview panel',
    show_buttons      => 'no',  # do not show +/- buttons
    button_width      => 8,     # width of red "+/-" buttons
    show_labels       => 'yes', # show track names on left-hand side
    label_width       => 113,   # width of labels on left-hand side
    margin            => 5,     # margin
    spacing           => 2,     # spacing
    opt_halfheight    => 1,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks  => 0,     # include empty tracks..
    opt_lines         => 1,     # draw registry lines
    opt_restrict_zoom => 1,     # when we get "zoom" working draw restriction enzyme info on it!!
  });
  
  $self->create_menus(
    sequence      => 'Sequence',
    marker        => 'Markers',
    transcript    => 'Genes',
    misc_feature  => 'Misc. regions',
    simple        => 'Simple Features',	

    # wc2 :: gEVAL Specific Menus
    gEVAL_all             => 'gEVAL Specific',
    gEVAL_om              => 'Genome/Optical Maps',
    optical_map           => ['Optical Maps',           'gEVAL_om' ],               
    genome_map            => ['Genome Maps',             'gEVAL_om' ],
    gEVAL_ends            => ['Mapped Clone Ends',       'gEVAL_all'],
    gEVAL_other           => ['gEVAL Other',             'gEVAL_all'],
    misc_feature          => [ 'Misc. regions & clones', 'gEVAL_all'],
    gEVAL_digest          => [ 'Insilico Digests',       'gEVAL_all'],
    gEVAL_mf_clone        => [ 'Clone Annotations',      'gEVAL_all'],
    gEVAL_daf_aln         => [ 'gEVAL Alignments',       'gEVAL_all'],

    synteny       => 'Synteny',
    variation     => 'Variations', 
    external_data => 'External data',
    user_data     => 'User attached data',
    decorations   => 'Additional decorations',
    information   => 'Information',


  );

#----- gEVAL Generic Tracks -----#
  $self->add_pgp_track( 'sequence','fpc_contig','FPC contig','gEVAL_fpc',  { 'display' => 'normal', 'description' => 'FPC contig on assembly', 'strand' => 'f' }, 'sequence' );
  $self->add_pgp_track( 'sequence','scaffold','Scaffolds','gEVAL_scaf', { 'display' => 'off', 'description' => 'scaffold on assembly', 'strand' => 'f' }, 'sequence' );
  $self->add_gEVAL_markers('marker');
  $self->add_gEVAL_digest('gEVAL_digest','gEVAL_digest');
  $self->add_gEVAL_mf_clone('gEVAL_mf_clone');
  $self->add_gEVAL_OpAlign('optical_map');


#----- gEVAL Manual Loaded Tracks (legacy and one-time what nots)-----#
  #-------ADD your local species DnaAlignFeat tracks Here--------# 
   #--This should be added to Imageconfig under add_gEVAL_OpAlign--#
  $self->add_pgp_track('optical_map', 'soma', 'Soma', 'gEVAL_soma', { 'display' => 'off', 'renderers' => [qw(off Off normal Normal)], 'strand' => 'f', 'description' => 'Soma Optical Map Alignments'});
 
  my @gen_mf_tracks = (  
                         ['misc_feature', 'eichler_prob', 'Eichler Problems', 'gEVAL_gff', 'normal', 'r', 'eichler_prob', 'Eichler Lab identifed assembly problems'],
                         ['misc_feature', 'bionano_sv', 'Bionano SV', 'gEVAL_gffSV', 'normal', 'r', 'bionano_sv', 'Bionano Structural Variation'],
                         ['misc_feature', 'bng_unalign_WUGSC_070814', 'WUGSC_070814 BNG UnAlign', 'gEVAL_bng_unalign', 'normal', 'r', 'bng_unalign_WUGSC_070814', 'Bionano AGP Results'],
                         ['misc_feature', 'bng_align_WUGSC_070814', 'WUGSC_070814 BNG Align', 'gEVAL_bng_align', 'normal', 'r', 'bng_align_WUGSC_070814', 'Bionano AGP Results'],
                         ['gEVAL_other', 'MP_covered', 'MP Coverage', 'gEVAL_mf_box', 'off', 'r', 'MP_covered', 'MP Coverage'],

  );
  
 # Add each itemset.
  foreach my $mfset (@gen_mf_tracks){
      my ($group, $type, $title, $glyph, $display, $dir, $set, $desc) = @{$mfset};

      $self->add_pgp_track($group, $type, $title, $glyph,
                           {  'display'      => $display,
                              'renderers'    => [qw(off Off normal Normal)],
                              'strand'       => $dir,
                              'set'          => $set,
                              'description'  => $desc  },
                           'misc_feature');
  }




  $self->add_tracks( 'information',
    [ 'missing',   '', 'text', { 'display' => 'normal', 'strand' => 'r', 'name' => 'Disabled track summary' } ],
    [ 'info',      '', 'text', { 'display' => 'normal', 'strand' => 'r', 'name' => 'Information'  } ],
  );
  
  if ($self->species_defs->ALTERNATIVE_ASSEMBLIES) {
    foreach my $alt_assembly (@{$self->species_defs->ALTERNATIVE_ASSEMBLIES}) {
      $self->add_track('misc_feature', "${alt_assembly}_assembly", "$alt_assembly assembly", 'alternative_assembly', { 
        display       => 'off',  
        strand        => 'r',  
        colourset     => 'alternative_assembly' ,  
        description   => "Track indicating $alt_assembly assembly", 
        assembly_name => $alt_assembly
      });
    }
  }

  $self->load_tracks;
  $self->load_configured_das('strand' => 'r');

  $self->modify_configs(
    [ 'transcript' ],
    { qw(render gene_label strand r) }
  );

  $self->modify_configs(
    [ 'marker' ],
    { qw(labels off) }
  );

  $self->modify_configs(
    [ 'variation' ],
    { qw(display off menu no) }
  );
  $self->modify_configs(
    [ 'variation_feature_structural' ],
    { qw(display normal menu yes) }
  );

  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );
}

1;
