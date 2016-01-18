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

package Bio::EnsEMBL::GlyphSet::gEVAL_scaf;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::FeaturePair;

use constant MAX_VIEWABLE_ASSEMBLY_SIZE => 5e6;

use Data::Dumper;

sub genoverse_attributes { return ( color => $_[0]{'config'}->colourmap->hex_by_name('blue1'), labelColor => '#FFFFFF' ); }

sub features {
  my ($self) = @_;
  
  return $self->render_text if $self->{'text_export'};

  my $Container = $self->{'container'};
  my $length = $Container->length();
  my $module = ref($self);
     $module = $1 if $module=~/::([^:]+)$/;

  my @features = ();

  my @segments = @{$Container->project("scaffold")};

  foreach my $segment (@segments) {
    my $start      = $segment->from_start;
    my $end        = $segment->from_end;
    my $ctg_slice  = $segment->to_Slice;
    my $feature = { 'start' => $start, 'end' => $end, 'name' => $ctg_slice->seq_region_name, 'slice'=> $ctg_slice };
    my $name       = $ctg_slice->seq_region_name;

    $feature->{'locations'}{ 'scaffold' } = [ $ctg_slice->seq_region_name, $ctg_slice->start, $ctg_slice->end, $ctg_slice->strand  ];

    my $feature = Bio::EnsEMBL::FeaturePair->new( -hseqname => $name,
						  -start    => $start,
						  -strand   => 1,
						  -end      => $end);
    push @features, $feature;
    
  }

  my %results = ( $self->my_config('name') => [\@features] );
  return %results;
}


sub feature_group {
  my( $self, $f ) = @_;
  return $f->hseqname;
}


sub href {
### Links to /Location/Genome
  my( $self, $f ) = @_;

  my $r = $f->seq_region_name;
  
  return $self->_url({
    'action' => 'Genome',
    'ftype'  => $self->my_config('object_type') || 'Slice',
    'r'      => $r,
    'id'     => $f->display_id,
    'dbid'   => $f->dbID, # add dbid information when clicking the glyyph. This is needed for the menus.
    'db'     => $self->my_config('db'),
  });
}


sub render_normal {
  my $self = shift;

  use Time::HiRes qw(gettimeofday tv_interval);
 
  return $self->render_text if $self->{'text_export'};
  
  my $tfh    = $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'});
  my $h      = @_ ? shift : ($self->my_config('height') || 8);
  my $dep    = @_ ? shift : ($self->my_config('dep'   ) || 10);
  my $gap    = $h<2 ? 1 : 2;   
## Information about the container...
  my $strand         = $self->strand;
  my $strand_flag    = $self->my_config('strand');

#  $dep = 20;

  my $length = $self->{'container'}->length();
## And now about the drawing configuration
  my $pix_per_bp     = $self->scalex;
  my $DRAW_CIGAR     = ( $self->my_config('force_cigar') eq 'yes' )|| ($pix_per_bp > 0.2) ;
## Highlights...
  my %highlights = map { $_ =~ s/^(.*?) .*/$1/; $_,1 } $self->highlights;
  my $outline    = 0; 

#  print STDERR "RENDER NORMAL (height: $h, strand: $strand, length: $length, ppb: $pix_per_bp) \n";


  if( $self->{'extras'} && $self->{'extras'}{'height'} ) {
    $h = $self->{'extras'}{'height'};
  }

## Get array of features and push them into the id hash...
  my %features = $self->features;

  my $y_offset = 0;

  my $features_drawn  = 0;
  my $features_bumped = 0;
  my $label_h         = 0;

  my( $fontname, $fontsize ) ;
  if( $self->{'show_labels'} ) {
    ( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
    my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, 'X', '', 'ptsize' => $fontsize, 'font' => $fontname );
    $label_h = $th;
  }
  
  foreach my $feature_key ( keys %features ) {
    $self->_init_bump( undef, $dep );
    my %id               = ();
    $self->{'track_key'} = $feature_key;


    foreach my $features ( @{$features{$feature_key}} ) {
      foreach my $f (
        map { $_->[2] }
        sort{ $a->[0] <=> $b->[0] }
        map { [$_->start,$_->end, $_ ] }
        @{$features || []}
      ){
        my $hstrand     = $f->can('hstrand')  ? $f->hstrand : 1;
        my $fgroup_name = $self->feature_group( $f );
        my $s           = $f->start;
        my $e           = $f->end;

        my $db_name = '';
        next if $strand_flag eq 'b' && $strand != ( ($hstrand||1)*$f->strand || -1 ) || $e < 1 || $s > $length ;
        push @{$id{$fgroup_name}}, [$s,$e,$f,int($s*$pix_per_bp),int($e*$pix_per_bp),$db_name];
      }
    }

## Now go through each feature in turn, drawing them
    my $y_pos;
    my $feature_colour = "blue4";
    my $block_colour   = "686CC4";
    my $arrow_scale    = int(5/$pix_per_bp);

    my $logic_name = @{ $self->my_config( 'logicnames' )||[] }[0];
    my $regexp     = $pix_per_bp > 0.1 ? '\dI' : ( $pix_per_bp > 0.01 ? '\d\dI' : '\d\d\dI' );

    next unless keys %id;
    foreach my $i ( 
		    sort {
		      @{$id{$b}} <=> @{$id{$a}} 
			} 
		    keys %id){
      my @F          = @{$id{$i}}; # sort { $a->[0] <=> $b->[0] } @{$id{$i}};
      my $START      = $F[0][0] < 1 ? 1 : $F[0][0];
      my $END        = $F[-1][1] > $length ? $length : $F[-1][1];
      my $db_name    = $F[0][5];
      my( $txt, $bit, $w, $th );
      my $bump_start = int($START * $pix_per_bp) - 1;
      my $bump_end   = int(($END) * $pix_per_bp);

      if( $self->{'show_labels'} ) {
        my $title                 = $self->feature_label( $F[0][2],$db_name );
        my( $txt, $bit, $tw,$th ) = $self->get_text_width( 0, $title, '', 'ptsize' => $fontsize, 'font' => $fontname );
        my $text_end              = $bump_start + $tw + 1;
        $bump_end                 = $text_end if $text_end > $bump_end;
      }
      my $s_time     = [gettimeofday()];
      my $row        = $self->bump_row( $bump_start, $bump_end );

      if( $row > $dep ) {
        $features_bumped++;
        next;
      }
      $y_pos = $y_offset - $row * int( $h + $gap * $label_h ) * $strand ;

      my $Composite = $self->Composite({
        'href'  => $self->href( $F[0][2] ),
        'x'     => $F[0][0]> 1 ? $F[0][0]-1 : 0,
        'width' => 0,
        'y'     => 0,

      });
      my $X = -1e8;

      foreach my $f ( @F ){ ## Loop through each feature for this ID!
        my( $s, $e, $feat ) = @$f;
	my $feat_strand = $feat->strand;

        $features_drawn++;

	my $START = $s < 1 ? 1 : $s;
	my $END   = $e > $length ? $length : $e;
	
	my (@pair1, @pair2, @pair3);
	
	if ($feat_strand == 1 ){   #draw triangle either downstream or upstream.

	  $Composite->push($self->Rect({
	    'x'          => $START-1,
	    'y'          => 0,
	    'width'      => $END-$START+1,
	    'height'     => $h,
	    'colour'     => $feature_colour,
	    'absolutey'  => 1,
	  }));
     
	}
	elsif ($feat_strand == -1 ){
	  
	  $Composite->push($self->Rect({
	    'x'          => $START-1,
	    'y'          => 0, # $y_pos,
	    'width'      => $END-$START+1,
	    'height'     => $h,
	    'colour'    => $feature_colour,
	    'absolutey'  => 1,
	  }));
	}
      }
    
      if( $h > 1 ) {
        $Composite->bordercolour($feature_colour);
      }
      
      $Composite->y( $Composite->y + $y_pos);
      $self->push( $Composite );

      if( $self->{'show_labels'} ) {
        $self->push( $self->Text({
          'font'      => $fontname,
          'colour'    => $feature_colour,
          'height'    => $fontsize,
          'ptsize'    => $fontsize,
          'text'      => $self->feature_label($F[0][2],$db_name),
          'halign'    => 'left',
          'valign'    => 'center',
          'x'         => $Composite->{'x'},
          'y'         => $Composite->{'y'} + $h + 2,
          'width'     => $Composite->{'x'} + ($bump_end-$bump_start) / $pix_per_bp,
          'height'    => $label_h,
          'absolutey' => 1
        }));
      }
      if( exists $highlights{$i} ) {
        $self->unshift( $self->Rect({
          'x'         => $Composite->{'x'} - 1/$pix_per_bp,
          'y'         => $Composite->{'y'} - 1,
          'width'     => $Composite->{'width'} + 2/$pix_per_bp,
          'height'    => $h + 2,
          'colour'    => $block_colour,
          'absolutey' => 1,
        }));

      }
    }
    
    $y_offset -= $strand * ( ($self->_max_bump_row ) * ( $h + $gap + $label_h ) + 6 );
    
  }
  $self->errorTrack( "No features from '".$self->my_config('name')."' in this region" )
    unless( $features_drawn || $self->get_parameter( 'opt_empty_tracks')==0 );

  if( $self->get_parameter( 'opt_show_bumped') && $features_bumped ) {
    my $y_pos = $strand < 0
              ? $y_offset
              : 2 + $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'})
              ;
    $self->errorTrack( sprintf( q(%s features from '%s' omitted), $features_bumped, $self->my_config('name')), undef, $y_offset );
  }
  $self->timer_push( 'Features drawn' );
## No features show "empty track line" if option set....
}

sub render_text {
  my $self = shift;
  
  return if $self->species_defs->NO_SEQUENCE;
  
  my $container = $self->{'container'};
  my $sa        = $container->adaptor;
  my $export;  
  
  foreach (@{$container->project('seqlevel')||[]}) {
    my $ctg_slice     = $_->to_Slice;
    my $feature_name  = $ctg_slice->coord_system->name eq 'ancestralsegment' ? $ctg_slice->{'_tree'} : $ctg_slice->seq_region_name;
    my $feature_slice = $sa->fetch_by_region('seqlevel', $feature_name)->project('toplevel')->[0]->to_Slice;
    
    $export .= $self->_render_text($_, 'Contig', { 'headers' => [ 'id' ], 'values' => [ $feature_name ] }, {
      'seqname' => $feature_slice->seq_region_name,
      'start'   => $feature_slice->start, 
      'end'     => $feature_slice->end, 
      'strand'  => $feature_slice->strand
    });
  }
  
  return $export;
}

1;



__END__

