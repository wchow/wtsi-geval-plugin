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

package EnsEMBL::Web::ImageConfig;

use strict;

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities decode_entities);
use JSON qw(from_json);
use URI::Escape qw(uri_unescape);
use Bio::EnsEMBL::ExternalData::DAS::Coordinator;
use Sanger::Graphics::TextHelper;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::Tree;

#########
# 'user' settings are restored from cookie if available
#  default settings are overridden by 'user' settings
#

# Takes two parameters
# (1) - the hub (i.e. an EnsEMBL::Web::Hub object)
# (2) - the species to use (defaults to the current species)

sub new {
  my $class   = shift;
  my $hub     = shift;
  my $species = shift || $hub->species;
  my $code    = shift;
  my $type    = $class =~ /([^:]+)$/ ? $1 : $class;
  my $style   = $hub->species_defs->ENSEMBL_STYLE || {};
  
  my $self = {
    hub              => $hub,
    _font_face       => $style->{'GRAPHIC_FONT'} || 'Arial',
    _font_size       => ($style->{'GRAPHIC_FONTSIZE'} * $style->{'GRAPHIC_LABEL'}) || 20,
    _texthelper      => Sanger::Graphics::TextHelper->new,
    code             => $code,
    type             => $type,
    species          => $species,
    altered          => 0,
    _tree            => EnsEMBL::Web::Tree->new,
    transcript_types => [qw(transcript alignslice_transcript tsv_transcript gsv_transcript TSE_transcript)],
    _parameters      => { # Default parameters
      storable     => 1,      
      has_das      => 1,
      datahubs     => 0,
      image_width  => $ENV{'ENSEMBL_IMAGE_WIDTH'} || 800,
      image_resize => 0,      
      margin       => 5,
      spacing      => 2,
      label_width  => 113,
      show_labels  => 'yes',
      slice_number => '1|1',
      toolbars     => { top => 1, bottom => 0 },
    },
    extra_menus => {
      active_tracks    => 1,
      favourite_tracks => 1,
      search_results   => 1,
      display_options  => 1,
    },
    unsortable_menus => {
      decorations => 1,
      information => 1,
      options     => 1,
      other       => 1,
    },
    alignment_renderers => [
      'off',         'Off',
      'normal',      'Normal',
      'labels',      'Labels',
      'half_height', 'Half height',
      'stack',       'Stacked',
      'unlimited',   'Stacked unlimited',
      'ungrouped',   'Ungrouped',
    ],
  };
  
  return bless $self, $class;
}

sub initialize {
  my $self      = shift;
  my $class     = ref $self;
  my $species   = $self->species;
  my $code      = $self->code;
  my $cache     = $self->hub->cache;
  my $cache_key = $self->cache_key;
  
  # Check memcached for defaults
  if (my $defaults = $cache && $cache_key ? $cache->get($cache_key) : undef) {
    my $user_data = $self->tree->user_data;
    
    $self->{$_} = $defaults->{$_} for keys %$defaults;
    $self->tree->push_user_data_through_tree($user_data);
  } else {
    # No cached defaults found, so initialize them and cache
    $self->init;
    $self->modify;
    
    if ($cache && $cache_key) {
      $self->tree->hide_user_data;
      
      my $defaults = {
        _tree       => $self->{'_tree'},
        _parameters => $self->{'_parameters'},
        extra_menus => $self->{'extra_menus'},
      };
      
      $cache->set($cache_key, $defaults, undef, 'IMAGE_CONFIG', $species);
      $self->tree->reveal_user_data;
    }
  }
  
  my $sortable = $self->get_parameter('sortable_tracks');
  
  $self->set_parameter('sortable_tracks', 1) if $sortable eq 'drag' && $ENV{'HTTP_USER_AGENT'} =~ /MSIE (\d+)/ && $1 < 7; # No sortable tracks on images for IE6 and lower
  $self->{'extra_menus'}{'track_order'} = 1  if $sortable;
  
  $self->{'no_image_frame'} = 1;
  
  # Add user defined data sources
  $self->load_user_tracks;
  
  # Combine info and decorations into a single menu
  my $decorations = $self->get_node('decorations') || $self->get_node('other');
  my $information = $self->get_node('information');
  
  if ($decorations && $information) {
    $decorations->set('caption', 'Information and decorations');
    $decorations->append_children($information->nodes);
  }
}

sub menus {
  return $_[0]->{'menus'} ||= {
    # Sequence
    seq_assembly        => 'Sequence and assembly',
    sequence            => [ 'Sequence',                'seq_assembly' ],
    misc_feature        => [ 'Clones & misc. regions',  'seq_assembly' ],
    genome_attribs      => [ 'Genome attributes',       'seq_assembly' ],
    marker              => [ 'Markers',                 'seq_assembly' ],
    simple              => [ 'Simple features',         'seq_assembly' ],
    ditag               => [ 'Ditag features',          'seq_assembly' ],
    dna_align_other     => [ 'DNA alignments',          'seq_assembly' ],
    dna_align_compara   => [ 'Imported alignments',     'seq_assembly' ],
    
    # Transcripts/Genes
    gene_transcript     => 'Genes and transcripts',
    transcript          => [ 'Genes',                  'gene_transcript' ],
    prediction          => [ 'Prediction transcripts', 'gene_transcript' ],
    lrg                 => [ 'LRG transcripts',        'gene_transcript' ],
    rnaseq              => [ 'RNASeq models',          'gene_transcript' ],
    
    # Supporting evidence
    splice_sites        => 'Splice sites',
    evidence            => 'Evidence',
    
    # Alignments
    mrna_prot           => 'mRNA and protein alignments',
    dna_align_cdna      => [ 'mRNA alignments',    'mrna_prot' ],
    dna_align_est       => [ 'EST alignments',     'mrna_prot' ],
    protein_align       => [ 'Protein alignments', 'mrna_prot' ],
    protein_feature     => [ 'Protein features',   'mrna_prot' ],
    dna_align_rna       => 'ncRNA',
    
    # Proteins
    domain              => 'Protein domains',
    gsv_domain          => 'Protein domains',
    feature             => 'Protein features',
    
    # Variations
    variation           => 'Variation',
    recombination       => [ 'Recombination & Accessibility', 'variation' ],
    somatic             => 'Somatic mutations',
    ld_population       => 'Population features',
    
    # Regulation
    functional          => 'Regulation',
    
    # Compara
    compara             => 'Comparative genomics',
    pairwise_blastz     => [ 'BLASTz/LASTz alignments',    'compara' ],
    pairwise_other      => [ 'Pairwise alignment',         'compara' ],
    pairwise_tblat      => [ 'Translated blat alignments', 'compara' ],
    multiple_align      => [ 'Multiple alignments',        'compara' ],
    conservation        => [ 'Conservation regions',       'compara' ],
    synteny             => 'Synteny',
    
    # Other features
    repeat              => 'Repeat regions',
    oligo               => 'Oligo probes',
    trans_associated    => 'Transcript features',
    
    # Info/decorations
    information         => 'Information',
    decorations         => 'Additional decorations',
    other               => 'Additional decorations',
    
    # External data
    user_data           => 'Your data',
    external_data       => 'External data',

    #
    # wc2 :: gEVAL Specific Menus
    gEVAL_all             => 'gEVAL Specific',
    gEVAL_om              => 'Genome/Optical Maps',
    optical_map           => ['Optical Maps',            'gEVAL_om' ],               
    genome_map            => ['Genome Maps',             'gEVAL_om'],
    gEVAL_ends            => ['Mapped Clone Ends',       'gEVAL_all'],
    gEVAL_other           => ['gEVAL Other',             'gEVAL_all'],
    misc_feature          => [ 'Misc. regions & clones', 'gEVAL_all'],
    gEVAL_digest          => [ 'Insilico Digests',       'gEVAL_all'],
    gEVAL_mf_clone        => [ 'Clone Annotations',      'gEVAL_all'],
    gEVAL_daf_aln         => [ 'gEVAL Alignments',       'gEVAL_all'],
  };
}




# load_tracks - loads in various database derived tracks; 
# loop through core like dbs, compara like dbs, funcgen like dbs, variation like dbs
sub load_tracks { 
  my $self         = shift;
  my $species      = $self->{'species'};
  my $species_defs = $self->species_defs;
  my $dbs_hash     = $self->databases;

  my %data_types = (
    core => [

#---"The ones below are omitted are removed, as they will be controlled by add_pgp_track or the add_gEVAL_XXX tracks"; 
#      'add_dna_align_features',     # Add to cDNA/mRNA, est, RNA, other_alignment trees
#      'add_ditag_features',         # Add to ditag_feature tree
#      'add_marker_features',        # Add to marker tree
#      'add_misc_features',          # Add to misc_feature tree

      'add_data_files',             # Add to gene/rnaseq tree
      'add_genes',                  # Add to gene, transcript, align_slice_transcript, tsv_transcript trees
      'add_trans_associated',       # Add to features associated with transcripts
      'add_qtl_features',           # Add to marker tree
      'add_genome_attribs',         # Add to genome_attribs tree
      'add_prediction_transcripts', # Add to prediction_transcript tree
      'add_protein_align_features', # Add to protein_align_feature_tree
      'add_protein_features',       # Add to protein_feature_tree
      'add_repeat_features',        # Add to repeat_feature tree
      'add_simple_features',        # Add to simple_feature tree
      'add_decorations'
    ],
    compara => [
      'add_synteny',                # Add to synteny tree
      'add_alignments'              # Add to compara_align tree
    ],
    funcgen => [
      'add_regulation_builds',      # Add to regulation_feature tree
      'add_regulation_features',    # Add to regulation_feature tree
      'add_oligo_probes'            # Add to oligo tree
    ],
    variation => [
      'add_sequence_variations',          # Add to variation_feature tree
      'add_structural_variations',        # Add to variation_feature tree
      'add_copy_number_variant_probes',   # Add to variation_feature tree
      'add_phenotypes',                   # Add to variation_feature tree
      'add_recombination',                # Moves recombination menu to the end of the variation_feature tree
      'add_somatic_mutations',            # Add to somatic tree
      'add_somatic_structural_variations' # Add to somatic tree
    ],
  );
  
  foreach my $type (keys %data_types) {
    my ($check, $databases) = $type eq 'compara' ? ($species_defs->multi_hash, $species_defs->compara_like_databases) : ($dbs_hash, $self->sd_call("${type}_like_databases"));
    
    foreach my $db (grep exists $check->{$_}, @{$databases || []}) {
      my $key = lc substr $db, 9;
      $self->$_($key, $check->{$db}{'tables'} || $check->{$db}, $species) for @{$data_types{$type}}; # Look through tables in databases and add data from each one
    }
  }
  
  $self->add_options('information', [ 'opt_empty_tracks', 'Display empty tracks', undef, undef, 'off' ]) unless $self->get_parameter('opt_empty_tracks') eq '0';
  $self->tree->append_child($self->create_option('track_order')) if $self->get_parameter('sortable_tracks');
}





#----------------------------------------------------------------------#
# Functions to add tracks from core like databases                     #
#----------------------------------------------------------------------#

# add_dna_align_features
# loop through all core databases - and attach the dna align
# features from the dna_align_feature tables...
# these are added to one of four menus: cdna/mrna, est, rna, other
# depending whats in the web_data column in the database
sub add_dna_align_features {
  my ($self, $key, $hashref) = @_;
  
  return unless $self->get_node('dna_align_cdna');
  
  my ($keys, $data) = $self->_merge($hashref->{'dna_align_feature'}, 'dna_align_feature');
  
  foreach my $key_2 (@$keys) {
    my $k    = $data->{$key_2}{'type'} || 'other';
    my $menu = ($k =~ /rnaseq|simple/) ? $self->tree->get_node($k) : $self->tree->get_node("dna_align_$k");
    if ($menu) {
      my $alignment_renderers = ['off','Off'];
      $alignment_renderers = [ @{$self->{'alignment_renderers'}} ] unless($data->{$key_2}{'no_default_renderers'});
      if (my @other_renderers = @{$data->{$key_2}{'additional_renderers'} || [] }) {
        my $i = 0;
        while ($i < scalar(@other_renderers)) {
          splice @$alignment_renderers, $i+2, 0, $other_renderers[$i];
          splice @$alignment_renderers, $i+3, 0, $other_renderers[$i+1];
          $i += 2;
        }
      }
      my $display = $data->{$key_2}{'display'} ? $data->{$key_2}{'display'} : 'off';
#      my $display  =  (grep { $data->{$key_2}{'display'} eq $_ } @$alignment_renderers )             ? $data->{$key_2}{'display'}
#                    : (grep { $data->{$key_2}{'display'} eq $_ } @{$self->{'alignment_renderers'}} ) ? $data->{$key_2}{'display'}
#                    : 'off'; # needed because the same logic_name can be a gene and an alignment
      my $glyphset = '_alignment';
      my $strand   = 'b';

      if ($key_2 eq 'alt_seq_mapping') {
        $display             = 'simple';
        $alignment_renderers = [ 'off', 'Off', 'normal', 'On' ];  
        $glyphset            = 'patch_ref_alignment';
        $strand              = 'f';
      }
      
      $self->generic_add($menu, $key, "dna_align_${key}_$key_2", $data->{$key_2}, {
        glyphset  => $glyphset,
        sub_type  => lc $k,
        colourset => 'feature',
        display   => $display,
        renderers => $alignment_renderers,
        strand    => $strand,
      });
    }
  }
  
  $self->add_track('information', 'diff_legend', 'Alignment Difference Legend', 'diff_legend', { strand => 'r' });
}



sub add_repeat_features {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('repeat');
  
  return unless $menu && $hashref->{'repeat_feature'}{'rows'} > 0;
  
  my $data    = $hashref->{'repeat_feature'}{'analyses'};
  my %options = (
    glyphset    => 'gEVAL_repeats',
    optimizable => 1,
    depth       => 5, #0.5, previous ensembl defaults
    bump_width  => 0,
    strand      => 'r',
  );
  
  $menu->append($self->create_track("repeat_$key", 'All repeats', {
    db          => $key,
    logic_names => [ undef ], # All logic names
    types       => [ undef ], # All repeat types
    name        => 'All repeats',
    description => 'All repeats (Everything)',
    colourset   => 'repeat',
    display     => 'off',
    renderers   => [qw(off Off normal On)],
    %options
  }));
  
  my $flag    = keys %$data > 1;
  my $colours = $self->species_defs->colour('repeat');
  
  foreach my $key_2 (sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data) {
    if ($flag) {
      # Add track for each analysis

      #
      # ::CHANGE:: wc2.  with pgp, analysis_description isn't used, so name is irrelevant.  What you want is
      #                 to use the logic_name.  This has been switched instead. also used pgp_repeat glyph
      #
                                                                            
        $menu->append($self->create_track('repeat_' . $key . '_' . $key_2, "All $key_2", { #wc2 ::: 0910; second element name changed.
            db          => $key,
            #glyphset    => 'pgp_repeats',  # wc2 ::: 0910
            logic_names  => [ $key_2 ], # Restrict to a single supset of logic names
            types       => [ undef ],
            name        => "All $key_2", # wc2 ::: 0910
            description => "All $key_2 analysis results only", # wc2 ::: 0910
            colours     => $colours,
            display     => 'off',
            renderers   => [qw(off Off normal Normal)],
            #optimizable => 1,
            #depth       => 0.5,
            #bump_width  => 0,
            #strand      => 'r'
	    %options,
            }));
    }
    
    my $d2 = $data->{$key_2}{'types'};
    
    if (keys %$d2 > 1) {
      foreach my $key_3 (sort keys %$d2) {
        my $n  = $key_3;
           $n .= " ($data->{$key_2}{'name'})" unless $data->{$key_2}{'name'} eq 'Repeats';
         
        # Add track for each repeat_type;        
        $menu->append($self->create_track('repeat_' . $key . '_' . $key_2 . '_' . $key_3, $n, {
          db          => $key,
          logic_names => [ $key_2 ],
          types       => [ $key_3 ],
          name        => $n,
          colours     => $colours,
          description => "$data->{$key_2}{'desc'} ($key_3)",
          display     => 'off',
          renderers   => [qw(off Off normal On)],
          %options
        }));
      }
    }
  }
}


sub add_alignments {
  my ($self, $key, $hashref, $species) = @_;
  
  return unless grep $self->get_node($_), qw(multiple_align pairwise_tblat pairwise_blastz pairwise_other conservation);
  
  my $species_defs = $self->species_defs;
  
  return if $species_defs->ENSEMBL_SITETYPE eq 'Pre';
  
  my $alignments = {};
  my $self_label = $species_defs->species_label($species, 'no_formatting');
  my $static     = $species_defs->ENSEMBL_SITETYPE eq 'Vega' ? '/info/data/comparative_analysis.html' : '/info/docs/compara/analyses.html';
 
  foreach my $row (values %{$hashref->{'ALIGNMENTS'}}) {
    next unless $row->{'species'}{$species};
    
    if ($row->{'class'} =~ /pairwise_alignment/) {
      my ($other_species) = grep { !/^$species$|ancestral_sequences$/ } keys %{$row->{'species'}};
         $other_species ||= $species if scalar keys %{$row->{'species'}} == 1;
      my $other_label     = $species_defs->species_label($other_species, 'no_formatting');
      my ($menu_key, $description, $type);
      
      ## wc2, skip if ancestral, and add the MUMmer type.
      next if ($other_label =~ /Ancestral sequence/i);
      $type        = 'MUMmer';
      $menu_key    = 'pairwise_blastz';
      $description = 'Pairwise alignments';
      
      $description  = qq{$description between $self_label and $other_label"};
      $description .= " $1" if $row->{'name'} =~ /\((on.+)\)/;

      $alignments->{$menu_key}{$row->{'id'}} = {
        db                         => $key,
        glyphset                   => '_alignment_pairwise',
        name                       => $other_label . ($type ?  " - $type" : ''),
        caption                    => $other_label,
        type                       => $row->{'type'},
        species                    => $other_species,
        method_link_species_set_id => $row->{'id'},
        description                => $description,
        order                      => $other_label,
        colourset                  => 'pairwise',
        strand                     => 'r',
        display                    => 'off',
        renderers                  => [ 'off', 'Off', 'compact', 'Compact', 'normal', 'Normal' ],
      };
    } else {
      my $n_species = grep { $_ ne 'ancestral_sequences' } keys %{$row->{'species'}};
      
      my %options = (
        db                         => $key,
        glyphset                   => '_alignment_multiple',
        short_name                 => $row->{'name'},
        type                       => $row->{'type'},
        species_set_id             => $row->{'species_set_id'},
        method_link_species_set_id => $row->{'id'},
        class                      => $row->{'class'},
        colourset                  => 'multiple',
        strand                     => 'f',
      );
      
      if ($row->{'conservation_score'}) {
        my ($program) = $hashref->{'CONSERVATION_SCORES'}{$row->{'conservation_score'}}{'type'} =~ /(.+)_CONSERVATION_SCORE/;
        
        $options{'description'} = qq{<a href="/info/docs/compara/analyses.html#conservation">$program conservation scores</a> based on the $row->{'name'}};
        
        $alignments->{'conservation'}{"$row->{'id'}_scores"} = {
          %options,
          conservation_score => $row->{'conservation_score'},
          name               => "Conservation score for $row->{'name'}",
          caption            => "$n_species way $program scores",
          order              => sprintf('%12d::%s::%s', 1e12-$n_species*10, $row->{'type'}, $row->{'name'}),
          display            => 'off',
          renderers          => [ 'off', 'Off', 'tiling', 'Tiling array' ],
        };
        
        $alignments->{'conservation'}{"$row->{'id'}_constrained"} = {
          %options,
          constrained_element => $row->{'constrained_element'},
          name                => "Constrained elements for $row->{'name'}",
          caption             => "$n_species way $program elements",
          order               => sprintf('%12d::%s::%s', 1e12-$n_species*10+1, $row->{'type'}, $row->{'name'}),
          display             => 'off',
          renderers           => [ 'off', 'Off', 'compact', 'On' ],
        };
      }
      
      $alignments->{'multiple_align'}{$row->{'id'}} = {
        %options,
        name        => $row->{'name'},
        caption     => $row->{'name'},
        order       => sprintf('%12d::%s::%s', 1e12-$n_species*10-1, $row->{'type'}, $row->{'name'}),
        display     => 'off',
        renderers   => [ 'off', 'Off', 'compact', 'On' ],
        description => qq{<a href="/info/docs/compara/analyses.html#conservation">$n_species way whole-genome multiple alignments</a>.; } . 
                       join('; ', sort map { $species_defs->species_label($_, 'no_formatting') } grep { $_ ne 'ancestral_sequences' } keys %{$row->{'species'}}),
      };
    } 
  }
  
  foreach my $menu_key (keys %$alignments) {
    my $menu = $self->get_node($menu_key);
    next unless $menu;
    
    foreach my $key_2 (sort { $alignments->{$menu_key}{$a}{'order'} cmp  $alignments->{$menu_key}{$b}{'order'} } keys %{$alignments->{$menu_key}}) {
      my $row = $alignments->{$menu_key}{$key_2};
      $menu->append($self->create_track("alignment_${key}_$key_2", $row->{'caption'}, $row));
    }
  }
}




# function will check and make sure that the logic_name is represented
# in the corresponding table before it gets added to the menu.
#
# Kim Brugger (02 Jun 2009)
sub add_pgp_track {
  my ( $self, $menu, $key, $caption, $glyphset, $params, $table ) = @_;

  $table ||= 'dna_align_feature';

  my $table_hash = ();
  if ( $table eq 'dna_align_feature' ) {
    $table_hash = $self->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'dna_align_feature'}{'analyses'};
  }
  elsif ( $table eq 'misc_feature' ) {
    $table_hash = $self->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'misc_feature'}{'sets'};
  }
  elsif ( $table eq 'block_alignment' ) {
    $table_hash = $self->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'block_alignment'};
  }
  # -- added marker/sequence, as tracks appeared even if not needed. wc2
  elsif ( $table eq 'marker' ) {
    $table_hash = $self->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'marker'};
  }
  elsif ( $table eq 'sequence' ) {
    my $dbs        = EnsEMBL::Web::DBSQL::DBConnection->new($self->{'species'});
    my $dba        = $dbs->get_DBAdaptor('core');
    my $csa        = $dba->get_CoordSystemAdaptor;
	
    if ($csa->fetch_by_name($key)){
      $self->add_track( $menu, $key, $caption, $glyphset, $params );
    }	

  }

  if ( (!$$table_hash{ $key } || !$$table_hash{ $key }{'count'}) && !$$table_hash{'rows'} ) {
#    print STDERR "$key does not have any values in the $table table, skipping this one...\n";
    return;
  }

  ## Take the info from the database;
  my $name = $$table_hash{$key}{'name'} || $caption || $key;
  my $desc = $$table_hash{$key}{'desc'} || $caption || $key;
  my $disp = $$table_hash{$key}{'disp'};

  ### if database say not to display return nothing.
  if (!$disp && $table eq 'dna_align_feature'){
	return;
  }	

  ### if description is a web address
  if ($desc =~ /http/){
     $desc = qq(<a href="$desc">$desc</a>);	
  }

  $$params{'description'} = $desc;
  $$params{'logicnames'} = ["$key"] if ( ! $$params{'logicnames'} );
  $self->add_track( $menu, $key, $name, $glyphset, $params );

#  print STDERR "ADD-PGP-TRACK :: ADDED $key under $menu...\n";

  return;
}

###--------------------------------###
### add_gEVAL_cloneend_tracks      ###
###  adds all the clone end tracks ###
###  that are tagged as displayed  ###
###  in the database               ###
###  Just feed in the menu to have ###
###  the tracks on, glyph and      ###
###  norep or all tracks.          ###
###                                ###
###  wc2@sanger 2015               ###
###--------------------------------###
sub add_gEVAL_cloneend_tracks {

    my ( $self, $menu, $glyphset, $type ) = @_;

    my $table_hash = $self->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'dna_align_feature'}{'analyses'};

    foreach my $key (sort {$a cmp $b} keys %$table_hash){

	## next if no entries in table.
	next if ( (!$$table_hash{ $key } || !$$table_hash{ $key }{'count'}) && !$$table_hash{'rows'} );
	## next if not a bac/fosend track.
	next if ($key !~ /bacend|fosend|fos/i);
	## if the option is not all but only norep, then skip all those with no norep in them. 
	next if (($type ne "all") && ($key !~ /norep/));

	## Take the info from the database;
	my $name = $$table_hash{$key}{'name'} || $key;
	my $desc = $$table_hash{$key}{'desc'} || $key;
	my $disp = $$table_hash{$key}{'disp'};
	
	### if database say not to display, skip & do not add track.
	next if (!$disp);	
	
	### if description is a web address
	$desc = qq(<a href="$desc">$desc</a>)	if ($desc =~ /http/);
	
	my $params =  { 'display'     => 'off',  
			'renderers'   => [qw(off Off normal Normal)],
			'strand'      => 'r',
			'description' => $desc,
	};

	$$params{'logicnames'}  = ["$key"] if ( ! $$params{'logicnames'} );
	$self->add_track( $menu, $key, $name, $glyphset, $params);	
    }
    return;
}

###--------------------------------###
### add_gEVAL_digest               ###
###  adds all the insilico digest  ###
###  tracks in the database        ###
###                                ###
###  wc2@sanger 2015               ###
###--------------------------------###
sub add_gEVAL_digest {

    my ($self, $menu, $glyphset) = @_;
    my $table_hash = $self->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'misc_feature'}{'sets'};

    foreach my $key (sort {$a cmp $b} keys %$table_hash){
	## next if no entries in table.
	next if ( (!$$table_hash{ $key } || !$$table_hash{ $key }{'count'}) && !$$table_hash{'rows'} );

	my $name = $$table_hash{$key}{'name'};
	my $desc = $$table_hash{$key}{'desc'};

	next if ($desc !~ /digest/ );
	
	my $params =  { 'display'     => 'off',  
			'renderers'   => [qw(off Off normal Normal)],
			'strand'      => 'r',
			'description' => $desc,
			'set'         => $key,
	};

	$self->add_track( $menu, $key, $name, $glyphset, $params);	

    }
    return;
}

###--------------------------------###
### add_gEVAL_mf_clone             ###
###  adds the clone annotations    ###
###  such as the miscfeatures for  ###
###  blacktags, clone, jira        ###
###                                ###
###  wc2@sanger 2015               ###
###--------------------------------###
sub add_gEVAL_mf_clone {

    my ($self, $menu) = @_;

    my $table_hash = $self->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'misc_feature'}{'sets'};
    
    foreach my $key (sort {$a cmp $b} keys %$table_hash){	
	my $glyphset;
	if      ($key =~ /clone/)    {     $glyphset = "gEVAL_clone"; }
	elsif   ($key =~ /jira/)     {     $glyphset = "gEVAL_jira";  }
	elsif   ($key =~ /blacktag/) {     $glyphset = "gEVAL_blacktag";  }
	else { next; }
	
	next if ($key !~ /clone|blacktag|jira/);

	## next if no entries in table.	
	next if ( (!$$table_hash{ $key } || !$$table_hash{ $key }{'count'}) && !$$table_hash{'rows'} );    
	
	my $name = $$table_hash{$key}{'name'};
	my $desc = $$table_hash{$key}{'desc'};
	
	my $params =  { 'display'     => 'off',  
			'renderers'   => [qw(off Off normal Normal)],
			'strand'      => 'r',
			'description' => $desc,
			'set'         => $key,
	};

	$self->add_track( $menu, $key, ucfirst($name), $glyphset, $params);
	
    }
    return;
}

###--------------------------------###
### add_gEVAL_markers              ###
###  adds all the marker features  ###
###  separated by the analysis. If ###
###  marker analysis name is not   ###
###  clear, then all markers will  ###
###  be displayed                  ###
###                                ###
###  wc2@sanger 2015               ###
###--------------------------------###
sub add_gEVAL_markers {
    
    my ($self, $menu) = @_;

    my $table_hash = $self->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'marker_feature'}{'analyses'};

    foreach my $key (sort {$a cmp $b} keys %$table_hash){	
	## next if no entries in table.	
	next if ( (!$$table_hash{ $key } || !$$table_hash{ $key }{'count'}) && !$$table_hash{'rows'} );    

	my $name = $$table_hash{$key}{'name'} || $key;
	my $desc = $$table_hash{$key}{'desc'} || $key;

	$name  = ($name !~ /marker/) ? "All Markers" : $name;

	my $params =   {
	    'labels'      => 'on',
	    'colours'     => $self->species_defs->colour( 'marker' ),
	    'description' => $desc,
	    'display'     => 'off',
	    'renderers'   => [qw(off Off normal Normal labels Detailed_labels)],
	    'strand'      => 'r',
	    'logic_name'  => $key,
	};	

	$$params{'logicnames'}  = ["$key"] if ( ! $$params{'logicnames'} );
	$self->add_track( 'marker', $key, ucfirst($name), "gEVAL_marker", $params);

    }
    return;
}

###--------------------------------###
### add_gEVAL_other                ###
###  adds all the other gEVAL      ###
###  alignments such as selfcomp & ###
###  cdna, transcripts.            ###
###                                ###
###  wc2@sanger 2015               ###
###--------------------------------###
sub add_gEVAL_other {

    my ($self, $menu)      = @_;

    my $table_hash = $self->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'dna_align_feature'}{'analyses'};
    
    foreach my $key (sort {$a cmp $b} keys %$table_hash){
	next if ($key !~ /self|rna|cdna|refseq|ccds|overlap/);
	next if ( (!$$table_hash{ $key } || !$$table_hash{ $key }{'count'}) && !$$table_hash{'rows'} );    
	
	my $name = $$table_hash{$key}{'name'} || $key;
	my $desc = $$table_hash{$key}{'desc'} || $key;
	my $disp = $$table_hash{$key}{'disp'};

	my $params ={ 'display'      => 'off',  
		      'renderers'    => [qw(off Off normal Normal)],
		      'strand'       => 'b', 
		      'description'  => $desc  };  
	$$params{'logicnames'}  = ["$key"] if ( ! $$params{'logicnames'} );

	if ($key =~ /selfcomp/){	    
	    $self->add_track( $menu, $key, ucfirst($name), "gEVAL_selfcomp", $params);
	}
	elsif ($key =~ /cdna|ccds|refseq|rna/){
	    my $glyphset = ($self->species_defs->GEVAL_CDNA_LEGACY) ? "gEVAL_ccds" : "gEVAL_cdna";
	    $$params{'renderers'} = [qw(off Off normal Normal labels Labels)];
	    $self->add_track( $menu, $key, uc($name), $glyphset, $params);
	}
	elsif ($key =~ /overlap/){
	    $$params{'strand'} = 'r';
	    $self->add_track( 'gEVAL_mf_clone', $key, ucfirst($name), "gEVAL_overlap", $params);
	}
	else {
	    return;
	}
	    
    }	
    return;
}

###--------------------------------###
### add_gEVAL_OpAlign              ###
###  adds all the optical/genome   ###
###  mappings in miscfeature for   ###
###  Schwartz, Soma and Bionano    ###
###  built.                        ###
###                                ###
###  wc2@sanger 2015               ###
###--------------------------------###
sub add_gEVAL_OpAlign {
    
    my ($self, $menu)    = @_;

    my $table_hash = $self->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'misc_feature'}{'sets'};

    foreach my $key (sort {$a cmp $b} keys %$table_hash){
	
	next if ($key !~ /OM|bnano/);
	next if ( (!$$table_hash{ $key } || !$$table_hash{ $key }{'count'}) && !$$table_hash{'rows'} );    
	
	my $name = $$table_hash{$key}{'name'};
	my $desc = $$table_hash{$key}{'desc'};
		
	my $params     =   {'display'      => 'off',
			    'renderers'    => [qw(off Off normal Normal)],
			    'strand'       => 'r',
			    'set'          => $key,
			    'description'  => $desc  };
	my $glyphset;
	if      ($key =~ /OM_frag/)     {     $glyphset = 'gEVAL_om_frag';   }
	elsif   ($key =~ /OM_gap/)      {     $glyphset = 'gEVAL_om_gap';    }
	elsif   ($key =~ /OM_ref/)      {     $glyphset = 'gEVAL_digest';    }
	elsif   ($key =~ /bnano_ctgs/)  {     $glyphset = 'gEVAL_om_frag';   }
	else    {return;}
	    
	$menu = "genome_map" if ($key =~ /bnano/);
	
	$self->add_track( $menu, $key, $name, $glyphset, $params);
	
    }

    return;
}


1;
