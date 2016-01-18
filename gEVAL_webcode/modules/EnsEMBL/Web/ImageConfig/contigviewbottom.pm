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

package EnsEMBL::Web::ImageConfig::contigviewbottom;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init_user           { return $_[0]->load_user_tracks; }
sub get_sortable_tracks { return grep { $_->get('sortable') && ($_->get('menu') ne 'no' || $_->id eq 'blast') } @{$_[0]->glyphset_configs}; } # Add blast to the sortable tracks
sub load_user_tracks    { return $_[0]->SUPER::load_user_tracks($_[1]) unless $_[0]->code eq 'set_evidence_types'; } # Stops unwanted cache tags being added for the main page (not the component)

sub init {
  my $self = shift;
  
  $self->set_parameters({
    sortable_tracks   => 'drag', # allow the user to reorder tracks on the image
    title             => 'Main panel',
    show_buttons      => 'no',  # show +/- buttons
    button_width      => 8,     # width of red "+/-" buttons
    show_labels       => 'yes', # show track names on left-hand side
    label_width       => 113,   # width of labels on left-hand side
    margin            => 5,     # margin
    spacing           => 2,     # spacing
    opt_halfheight    => 0,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_lines         => 1,     # draw registry lines
    opt_restrict_zoom => 1      # when we get "zoom" working draw restriction enzyme info on it
  });
  
  # First add menus in the order you want them for this display
  $self->create_menus(qw(
    sequence
    marker
    trans_associated
    transcript
    prediction
    dna_align_cdna
    dna_align_est
    dna_align_rna
    dna_align_other
    protein_align
    protein_feature
    gEVAL_other
    gEVAL_all
    gEVAL_ends
    gEVAL_digest
    gEVAL_mf_clone
    gEVAL_daf_aln
    optical_map
    genome_map			 
    rnaseq
    ditag
    simple
    misc_feature
    variation
    somatic
    functional
    multiple_align
    conservation
    pairwise_blastz
    pairwise_tblat
    pairwise_other
    oligo
    repeat
    external_data
    user_data
    decorations
    information
  ));


# Note these tracks get added before the "auto-loaded tracks" get added...
  $self->add_tracks( 'sequence', 
    [ 'contig',    'Contigs',              'gEVAL_contig',    { 'display' => 'normal',  'strand' => 'r', 'description' => 'Track showing underlying assembly contigs'  } ],
    [ 'seq',       'Sequence',             'sequence',        { 'display' => 'off',  'strand' => 'b', 'threshold' => 0.2, 'colourset' => 'seq',      'description' => 'Track showing sequence in both directions'  } ],
    [ 'codon_seq', 'Translated sequence',  'codonseq',        { 'display' => 'off',  'strand' => 'b', 'threshold' => 0.5, 'colourset' => 'codonseq', 'description' => 'Track showing 6-frame translation of sequence'  } ],
    [ 'codons',    'Start/stop codons',    'codons',          { 'display' => 'off',  'strand' => 'b', 'threshold' => 50,  'colourset' => 'codons' ,  'description' => 'Track indicating locations of start and stop codons in region'  } ],);
  $self->add_tracks( 'decorations',
    [ 'gc_plot',   '%GC',                  'gcplot',          { 'display' => 'normal',  'strand' => 'r', 'description' => 'Shows %age of Gs & Cs in region'  } ],
  );


#----- gEVAL Generic Tracks -----#
  ## Note add_pgp_track loads name, description from the database, and if its not available then will use the attribs fed in.
  $self->add_pgp_track(  'sequence',  'fpc_contig', 'FPC contig',  'gEVAL_fpc',   { 'display' => 'off', 'strand' => 'f', 'description' => 'FPC Contigs on assembly path'}, 'sequence');
  $self->add_pgp_track(  'sequence',  'scaffold',  'Scaffolds',   'gEVAL_scaf',  { 'display' => 'off', 'strand' => 'f', 'description' => 'Scaffolds on assembly path'}, 'sequence');
  $self->add_gEVAL_cloneend_tracks('gEVAL_ends', 'gEVAL_ends_link', 'all');
  $self->add_gEVAL_digest('gEVAL_digest','gEVAL_digest');
  $self->add_gEVAL_mf_clone('gEVAL_mf_clone');
  $self->add_gEVAL_markers('marker');
  $self->add_gEVAL_other('gEVAL_daf_aln');
  $self->add_gEVAL_OpAlign('optical_map');

#----- gEVAL Manual Loaded Tracks (legacy and one-time what nots)-----#
  #-------ADD your local species DnaAlignFeat tracks Here--------#
  $self->add_pgp_track('gEVAL_other', 'human36_pool', 'Human36 Fosmid Pool', 'gEVAL_simple_blat', { 'display' => 'off', 'renderers' => [qw(off Off normal Normal)], 'strand' => 'b', 'description' => 'human36_pool'}); 
  $self->add_pgp_track('gEVAL_other', 'al_block_current', 'al_blocks', 'gEVAL_alblocks',  { 'display' => 'off', 'renderers'   => [qw(off Off normal Normal)], 'strand' => 'b', 'description'  => 'al_blocks'  }, 'block_alignment' );
  #--This should be added to Imageconfig under add_gEVAL_OpAlign--#
  $self->add_pgp_track('optical_map', 'soma', 'Soma', 'gEVAL_soma', { 'display' => 'off', 'renderers' => [qw(off Off normal Normal)], 'strand' => 'f', 'description' => 'Soma Optical Map Alignments'}); 



  #-------ADD your local species MiscFeat tracks Here--------#
  my @gen_mf_tracks = ( 
                         ['gEVAL_other', 'eichler_prob', 'Eichler Problems',      'gEVAL_gff',            'off', 'r', 'eichler_prob', 'Eichler Lab identifed assembly problems'],
                         ['gEVAL_other', 'bionano_sv_gff', 'Bionano SV(gff3)',    'gEVAL_fileSV',         'off', 'r', 'bionano_sv_gff', 'Bionano Structural Variation (gff3)'],
                         ['gEVAL_other', 'bionano_sv_bed', 'Bionano SV(bed)',     'gEVAL_fileSV',         'off', 'r', 'bionano_sv_bed', 'Bionano Structural Variation (BED)'],
                         ['gEVAL_other', 'pacbio_toplevel', 'pacbio_toplevel',    'gEVAL_pacbio',         'off', 'r', 'pacbio_toplevel', 'pacbio_toplevel'],
                         ['gEVAL_other', 'MEI', 'mobile element insertions',      'gEVAL_simple_triangle','off', 'b', 'MEI', 'Mobile element insertions from 1000 genomes phase 3'],
                         ['gEVAL_other', 'MP_covered', 'MP Coverage  ',           'gEVAL_mf_box',         'off', 'r', 'MP_covered', 'MP Coverage'],      

      );  
  # -- Add Pipeline Clones tracks to gen_mf_tracks [currently zfish only] -- #
  my %pipe_type = (
      tpf_clone                     => ['TPF clone', 'Clone positions based on end-pairs for clones in the current TPF'],
      active_non_tpf_clone          => ['Active non-TPF clone', 'Clone positions based on end-pairs for clones not in the current TPF that have not been cancelled'],
      cancelled_non_tpf_clone       => ['Cancelled non_TPF clone', 'Clone positions based on end-pairs for clones not in the current TPF that have been cancelled'],
      cancelled_non_tpf_clone_s     => ['Cancelled +seq non-TPF clone','Clone positions based on end-pairs for clones not in the current TPF that have been cancelled, with sequence available'],
      );  
  foreach my $miscset_name (keys %pipe_type){
      my ($title, $desc) = @{$pipe_type{$miscset_name}};
      push @gen_mf_tracks, ['misc_feature', $miscset_name, $title, 'gEVAL_pipeline_clone', 'off', 'r', $miscset_name, $desc];
  }


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
  


#--------- Helminth Legacy Items -----------#
  $self->add_pgp_track( 'gEVAL_other','selfcomp_mum', 'Selfcomp (MUM)', 'gEVAL_selfcomp',  { 'display'      => 'off',
											     'renderers'    => [qw(off Off normal Normal)],
											     'strand'       => 'b',
											     'description'  => 'A mirror to show the true nature of the DNA'  } );


  my @helminth_rdgrp = qw( cap_wgs cap_Gpcr capillary_fos1 capillary_fos2 maybe_solexa illumina_gapclose shredded ungrouped capillary_bac1);
  @helminth_rdgrp = map {($_, $_."_span", $_."_multi", $_."_span_multi")} @helminth_rdgrp;

  foreach my $readgroup (@helminth_rdgrp) {
      $self->add_pgp_track
        ('gEVAL_ends', # which menu it goes in
         $readgroup, # analysis.logic name
         "reads in $readgroup", # track display name
         'gEVAL_ends', # glyph that draws it
         { # configuration of menu
          display => 'normal',
          size_range => [ 500, 5000 ],
          feature_group =>
          [
           # Capillary(-like) reads, standard primer.
           # Reads with an iteration letter may be paired.
           qr{^(.*)\.[pq]1k[a-z]?$},

           # FOSmids WC
           qr{^((.*)\.[pq]1k[a-z]?T7|(.*)\.[pq]1k[a-z]?SP6)$},


           # Capillary primer walk or similar, probably from Staden primer picking
           qr{^(.*)\.[pq]2kA[0-9A-Za-x]{1,3}$},

           # Capillary genomic PCR, probably from ABACAS2Crusade
           qr{^G\S+_S\S{1,3}_A\S{1,3}-(\d{1,4}[a-p]\d{2})\.w2k[a-z]?[SA]\S{1,3}$},

           # Possibly specific to the fosmids in EMU & RATTI?
           # Capillary read with different "standard primer"
           qr{^(.*)\.(?:q1k[a-z]?pIBR|p1k[a-z]?pIBF)$},

           qr{^(afake_Sol)\.[35]end\.(ext\.\d{3,6}[A-Z]?)$},

           qr{^(454contig.*)$},
          ],
          renderers => [qw(off Off normal Normal)],
          strand => 'r',
          description => 'Displayed as ends, but may be other reads'
         } );
  }
  
  $self->add_pgp_track( 'gEVAL_other','cufflinks', 'cufflink transcript models', 'gEVAL_cdna',  { 'display'      => 'off',
												  'renderers'    => [qw(off Off normal Normal)],
												  'strand'       => 'b',
												  'description'  => 'Mapped cDNAs. Green means that the whole cDNA is mapped...'  } );
  
  $self->add_pgp_track( 'gEVAL_other','gth_cegma', 'gth_cegma transcript models', 'gEVAL_cdna',  { 'display'      => 'off',
												   'renderers'    => [qw(off Off normal Normal)],
												   'strand'       => 'b',
												   'description'  => 'Mapped cDNAs. Green means that the whole cDNA is mapped...'  } );
  
  $self->add_pgp_track( 'gEVAL_other','gth_ferencs', 'gth_ferencs transcript models', 'gEVAL_cdna',  { 'display'      => 'off',
												       'renderers'    => [qw(off Off normal Normal)],
												       'strand'       => 'b',
												       'description'  => 'Mapped cDNAs. Green means that the whole cDNA is mapped...'  } );
  
  $self->add_pgp_track( 'gEVAL_ends','noarc_end_norep', 'no_arc ends (norep)', 'gEVAL_ends',  {    'display'     => 'off',
												   'renderers'   => [qw(off Off normal Normal)],
												   'strand'      => 'r',
												   'description' => 'Ends are nothing but  ...'  } );
  
  $self->add_pgp_track( 'gEVAL_ends','noarc_end_rep', 'no_arc ends(rep)', 'gEVAL_ends',  { 'display'     => 'off',
											   'renderers'   => [qw(off Off normal Normal)],
											   'strand'      => 'r',
											   'description' => 'Ends are nothing but  ...'  } );
  
  $self->add_pgp_track( 'markers','marker_ins_rep', 'markers', 'gEVAL_marker_ins',  { 'display'     => 'on',
										      'renderers'   => [qw(off Off normal Normal)],
										      'strand'      => 'r',
										      'description' => 'Schisto markers  ...'  } );
  
  $self->add_pgp_track( 'gEVAL_ends','454_20kb_norep', '454 reads (norep)', 'gEVAL_ends',  {    'display' => 'off',
												'renderers'   => [qw(off Off normal Normal)],
												'strand' => 'r',
												'description' => 'Ends are nothing but  ...'  } );

  # Add in additional tracks
  $self->load_tracks;
  $self->load_configured_das;
  
  # These tracks get added after the "auto-loaded tracks get addded
  if ($self->species_defs->ENSEMBL_MOD) {
    $self->add_track('information', 'mod', '', 'text', {
      name    => 'Message of the day',
      display => 'normal',
      menu    => 'no',
      strand  => 'r', 
      text    => $self->species_defs->ENSEMBL_MOD
    });
  }

  $self->add_tracks('information',
    [ 'missing', '', 'text', { display => 'normal', strand => 'r', name => 'Disabled track summary', description => 'Show counts of number of tracks turned off by the user' }],
    [ 'info',    '', 'text', { display => 'normal', strand => 'r', name => 'Information',            description => 'Details of the region shown in the image' }]
  );
  
  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );

  #switch on default compara multiple alignments (check track name each release)
  $self->modify_configs(
    [ 'alignment_compara_436_scores' ],
    { qw(display tiling) }
  );
  $self->modify_configs(
    [ 'alignment_compara_436_constrained' ],
    { qw(display compact) }
  );
}

1;
