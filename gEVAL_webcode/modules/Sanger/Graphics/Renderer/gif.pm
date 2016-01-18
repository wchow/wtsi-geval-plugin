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

#########
# Author:        rmp@sanger.ac.uk
# Maintainer:    webmaster@sanger.ac.uk
# Created:       2001
# Last Modified: dj3 2005-09-01 add chevron line style a la UCSC (ticket 25769)
#                dj3 2005-08-31 add tiling ability to Polys (was just Rects)
#                rmp 2005-08-09 hatched fill-pattern support (subs tile and render_Rect): set $glyph->{'hatched'} = true|false and $glyph->{'hatchcolour'} = 'darkgrey';
#                rmp 2004-12-14 initial stringFT support
#
package Sanger::Graphics::Renderer::gif;
use strict;
#use warnings;
use base qw(Sanger::Graphics::Renderer);
use GD;
## use GD::Text::Align;
# use Math::Bezier;

sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;
  $self->{'im_width'}     = $im_width;
  $self->{'im_height'}    = $im_height;

  if( $self->{'config'}->can('species_defs') ) {
    my $ST = $self->{'config'}->species_defs->ENSEMBL_STYLE || {};
    $self->{'ttf_path'} ||= $ST->{'GRAPHIC_TTF_PATH'};
  }
  $self->{'ttf_path'}   ||= '/usr/local/share/fonts/ttfonts/';

  my $canvas           = GD::Image->new(
	  $im_width  * $self->{'sf'},
		$im_height * $self->{'sf'}
  );

  $canvas->colorAllocate($config->colourmap->rgb_by_name($config->bgcolor()));
  $self->canvas($canvas);
}

sub add_canvas_frame {
  my ($self, $config, $im_width, $im_height) = @_;
	
  return;
  return if (defined $config->{'no_image_frame'});
	
  # custom || default image frame colour
  my $imageframecol = $config->{'image_frame_colour'} || 'black';
  my $framecolour   = $self->colour($imageframecol);

  # for contigview bottom box we need an extra thick border...
  if ($config->script() eq 'contigviewbottom'){		
    $self->{'canvas'}->rectangle(1, 1, $im_width * $self->{sf} -2, $im_height * $self->{sf}-2, $framecolour);		
  }
	
  $self->{'canvas'}->rectangle(
	  0, 0, $im_width * $self->{sf} -1, $im_height * $self->{sf} -1, $framecolour
  );
}

sub canvas {
  my ($self, $canvas) = @_;

  if(defined $canvas) {
    $self->{'canvas'} = $canvas;

  } else {
    return $self->{'canvas'}->gif();
  }
}

#########
# colour caching routine.
# GD can only store 256 colours, so need to cache the ones we colorAllocate. (Doh!)
#
sub colour {
  my ($self, $id) = @_;
  $id           ||= 'black';
  $self->{'_GDColourCache'}->{$id} ||= $self->{'canvas'}->colorAllocate($self->{'colourmap'}->rgb_by_name($id));
  return $self->{'_GDColourCache'}->{$id};
}

#########
# build mini GD images which can be used as fill patterns
# should probably support different density hatching too
#
sub tile {
  my ($self, $id, $pattern) = @_;
  my $bg_color = 'white';
  $id      ||= 'darkgrey';
  $pattern ||= 'hatch_ne';

  my $key = join ':', $bg_color, $id, $pattern;
  unless($self->{'_GDTileCache'}->{$key}) {
    my $tile;
    my $pattern_def = $Sanger::Graphics::Renderer::patterns->{$pattern};
    if( $pattern_def ) {
      $tile = GD::Image->new(@{ $pattern_def->{'size'}} );
      my $bg   = $tile->colorAllocate($self->{'colourmap'}->rgb_by_name($bg_color));
      my $fg   = $tile->colorAllocate($self->{'colourmap'}->rgb_by_name($id));
      $tile->transparent($bg);
      $tile->line(@$_, $fg ) foreach( @{$pattern_def->{'lines'}||[]});
      foreach my $poly_def ( @{$pattern_def->{'polys'}||[]} ) {
        my $poly = new GD::Polygon;
        foreach( @$poly_def ) {
          $poly->addPt( map { $_ } @$_ );
        } 
        $tile->filledPolygon($poly,$fg);
      }
    }
    $self->{'_GDTileCache'}->{$key} = $tile;
  }
  return $self->{'_GDTileCache'}->{$key};
}

sub render_Rect {
  my ($self, $glyph) = @_;
  my $canvas         = $self->{'canvas'};
  my $gcolour        = $glyph->{'colour'};
  my $gbordercolour  = $glyph->{'bordercolour'};

  # (avc)
  # this is a no-op to let us define transparent glyphs
  # and which can still have an imagemap area BUT make
  # sure it is smaller than the carrent largest glyph in
  # this glyphset because its height is not recorded!
  if (defined $gcolour && $gcolour eq 'transparent') {
    return;
  }

  my $bordercolour  = $self->colour($gbordercolour);
  my $colour        = $self->colour($gcolour);

  my $x1 = $self->{sf} *   $glyph->{'pixelx'};
  my $x2 = $self->{sf} * ( $glyph->{'pixelx'} + $glyph->{'pixelwidth'} );
  my $y1 = $self->{sf} *   $glyph->{'pixely'};
  my $y2 = $self->{sf} * ( $glyph->{'pixely'} + $glyph->{'pixelheight'} );

  $canvas->filledRectangle($x1, $y1, $x2, $y2, $colour) if(defined $gcolour);
  if($glyph->{'pattern'}) {
    $canvas->setTile($self->tile($glyph->{'patterncolour'}, $glyph->{'pattern'}));
    $canvas->filledRectangle($x1, $y1, $x2, $y2, gdTiled);
  }

  $canvas->rectangle($x1, $y1, $x2, $y2, $bordercolour) if(defined $gbordercolour);
}

sub render_Text {
  my ($self, $glyph) = @_;

  return unless $glyph->{'text'};
  my $font   = $glyph->font();
  my $colour = $self->colour($glyph->{'colour'});

  ########## Stock GD fonts
  my $left       = $self->{sf} * $glyph->{'pixelx'}    || 0;
  my $textwidth  = $self->{sf} * $glyph->{'textwidth'} || 0;
  my $top        = $self->{sf} * $glyph->{'pixely'}    || 0;
  my $textheight = $self->{sf} * $glyph->{'pixelheight'} || 0;
  my $halign     = $glyph->{'halign'}    || '';

  if($halign eq 'right' ) {
    $left += $glyph->{'pixelwidth'} * $self->{sf} - $textwidth;

  } elsif($halign ne 'left' ) {
    $left += ($glyph->{'pixelwidth'} * $self->{sf} - $textwidth)/2;
  }

  if($font eq 'Tiny') {
    if ($glyph->rotated() ) {
      $self->{'canvas'}->stringUp(gdTinyFont,  $left, $top, $glyph->text(), $colour);
    }
    else {
      $self->{'canvas'}->string(gdTinyFont,  $left, $top, $glyph->text(), $colour);
    }
  } elsif($font eq 'Small') {
    if ($glyph->rotated() ) {
      $self->{'canvas'}->stringUp(gdSmallFont,  $left, $top, $glyph->text(), $colour);
    }
    else {
      $self->{'canvas'}->string(gdSmallFont, $left, $top, $glyph->text(), $colour);
    }
  } elsif($font eq 'MediumBold') {
    if ($glyph->rotated() ) {
      $self->{'canvas'}->stringUp(gdMediumBoldFont,  $left, $top, $glyph->text(), $colour);
    }
    else {
      $self->{'canvas'}->string(gdMediumBoldFont, $left, $top, $glyph->text(), $colour);
    }
  } elsif($font eq 'Large') {
    if ($glyph->rotated() ) {
      $self->{'canvas'}->stringUp(gdLargeFont,  $left, $top, $glyph->text(), $colour);
    }
    else {
      $self->{'canvas'}->string(gdLargeFont, $left, $top, $glyph->text(), $colour);
    }
  } elsif($font eq 'Giant') {
    if ($glyph->rotated() ) {
      $self->{'canvas'}->stringUp(gdGiantFont,  $left, $top, $glyph->text(), $colour);
    }
    else {
      $self->{'canvas'}->string(gdGiantFont, $left, $top, $glyph->text(), $colour);
    }
  } elsif($font) {
    #########
    # If we didn't recognise it already, assume it's a TrueType font
    if ($glyph->rotated() ) {
      $self->{'canvas'}->stringTTF( $colour, $self->{'ttf_path'}.$font.'.ttf', $self->{sf} * $glyph->ptsize, 1.57, $left, $top+$textheight, $glyph->{'text'} );
    }
    else {
      $self->{'canvas'}->stringTTF( $colour, $self->{'ttf_path'}.$font.'.ttf', $self->{sf} * $glyph->ptsize, 0, $left, $top+$textheight, $glyph->{'text'} );
    }
###  my ($cx, $cy)      = $glyph->pixelcentre();
###  my $xpt = $glyph->{'pixelx'} + 
###            ( $glyph->{'halign'} eq 'left' ? 0 : $glyph->{'halign'} eq 'right' ? 1 : 0.5 ) * $glyph->{'pixelwidth'};
###    my $X = GD::Text::Align->new( $self->{'canvas'},
###      'valign' => $glyph->{'valign'} || 'center', 'halign' => $glyph->{'halign'} || 'center',
###      'colour' => $colour,                        'font'   => "$self->{'ttf_path'}$font.ttf",
###      'ptsize' => $glyph->ptsize(),               'text'   => $glyph->text()
###    );
###    $X->draw( $xpt, $cy, $glyph->angle()||0 );
  }
}

sub render_Circle {
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $gcolour        = $glyph->{'colour'};
  my $colour         = $self->colour($gcolour);
  my $filled         = $glyph->filled();
  my ($cx, $cy)      = $glyph->pixelcentre();

  my $method = $filled ? 'filledEllipse' : 'ellipse';
  $canvas->$method( 
    $self->{sf} * ($cx-$glyph->{'pixelwidth'}/2),
    $self->{sf} * ($cy-$glyph->{'pixelheight'}/2),
    $self->{sf} *  $glyph->{'pixelwidth'},
    $self->{sf} *  $glyph->{'pixelheight'},
    $colour
   );
#  $canvas->fillToBorder($cx, $cy, $colour, $colour) if ($filled && $cx <= $self->{'im_width'});
}

sub render_Ellipse {
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $gcolour        = $glyph->{'colour'};
  my $colour         = $self->colour($gcolour);
  my $filled         = $glyph->filled();
  my ($cx, $cy)      = $glyph->pixelcentre();

  my $method = $filled ? 'filledEllipse' : 'ellipse';
  $canvas->$method( 
    $self->{sf} * ($cx-$glyph->{'pixelwidth'}/2),
    $self->{sf} * ($cy-$glyph->{'pixelheight'}/2),
    $self->{sf} *  $glyph->{'pixelwidth'},
    $self->{sf} *  $glyph->{'pixelheight'},
    $colour
   );
}

sub render_Intron {
  my ($self, $glyph) = @_;

  my ($colour, $xstart, $xmiddle, $xend, $ystart, $ymiddle, $yend, $strand, $gy);
  $colour  = $self->colour($glyph->{'colour'});
  $gy      = $self->{sf} * $glyph->{'pixely'};
  $strand  = $glyph->{'strand'};
  $xstart  = $self->{sf} * $glyph->{'pixelx'};
  $xend    = $xstart + $self->{sf} * $glyph->{'pixelwidth'};
  $xmiddle = $xstart + $self->{sf} * $glyph->{'pixelwidth'} / 2;
  $ystart  = $gy + $self->{sf} * $glyph->{'pixelheight'}/2;
  $yend    = $ystart;
  $ymiddle = $ystart + $self->{sf} * ( $strand == 1 ? -1 : 1 ) * $glyph->{'pixelheight'} * 3/8;

  $self->{'canvas'}->line($xstart, $ystart, $xmiddle, $ymiddle, $colour);
  $self->{'canvas'}->line($xmiddle, $ymiddle, $xend, $yend, $colour);
}

sub render_Line {
  my ($self, $glyph) = @_;

  my $colour = $self->colour($glyph->{'colour'});
  my $x1     = $self->{sf} * $glyph->{'pixelx'} + 0;
  my $y1     = $self->{sf} * $glyph->{'pixely'} + 0;
  my $x2     = $x1 + $self->{sf} * $glyph->{'pixelwidth'};
  my $y2     = $y1 + $self->{sf} * $glyph->{'pixelheight'};

  if(defined $glyph->dotted() && $glyph->dotted ) {
    $self->{'canvas'}->setStyle(gdTransparent,gdTransparent,gdTransparent,$colour,$colour,$colour);
    $self->{'canvas'}->line($x1, $y1, $x2, $y2, gdStyled);
  } else {
    $self->{'canvas'}->line($x1, $y1, $x2, $y2, $colour);
  }

  if($glyph->chevron()) {
    my $flip = ($glyph->{'strand'}<0);
    my $len  = $glyph->chevron(); $len=4 if $len<4;
    my $n    = int($self->{sf} * ($glyph->{'pixelwidth'} + $glyph->{'pixelheight'})/$len);
    my $dx   = $self->{sf} * $glyph->{'pixelwidth'}  / $n; $dx*=-1 if $flip;
    my $dy   = $self->{sf} * $glyph->{'pixelheight'} / $n; $dy*=-1 if $flip;
    my $ix   = int($dx);
    my $iy   = int($dy);
    my $i1x  = int(-0.5*($ix-$iy));
    my $i1y  = int(-0.5*($iy+$ix));
    my $i2x  = int(-0.5*($ix+$iy));
    my $i2y  = int(-0.5*($iy-$ix));

    for (;$n;$n--) {
      my $tx = int($n*$dx)+($flip ? $x2 : $x1);
      my $ty = int($n*$dy)+($flip ? $y2 : $y1);
      $self->{'canvas'}->line($tx, $ty, $tx+$i1x, $ty+$i1y, $colour);
      $self->{'canvas'}->line($tx, $ty, $tx+$i2x, $ty+$i2y, $colour);
    }
  }
}

sub render_Poly {
  my ($self, $glyph) = @_;

  my $canvas         = $self->{'canvas'};
  my $bordercolour   = $self->colour($glyph->{'bordercolour'});
  my $colour         = $self->colour($glyph->{'colour'});
  my $poly           = new GD::Polygon;

  return unless(defined $glyph->pixelpoints());

  my @points = @{$glyph->pixelpoints()};
  my $pairs_of_points = (scalar @points)/ 2;

  for(my $i=0;$i<$pairs_of_points;$i++) {
    my $x = shift @points;
    my $y = shift @points;
    $poly->addPt($self->{sf} * $x,$self->{sf} * $y);
  }

  if($glyph->{colour}) {
    $canvas->filledPolygon($poly, $colour);
  }

  if($glyph->{'pattern'}) {
    $canvas->setTile($self->tile($glyph->{'patterncolour'}, $glyph->{'pattern'}));
    $canvas->filledPolygon($poly, gdTiled);
  }

  if($glyph->{bordercolour}) {
    $canvas->polygon($poly, $bordercolour);
  }
}

sub render_Composite {
  my ($self, $glyph, $Ta) = @_;

  #########
  # draw & colour the fill area if specified
  #
  $self->render_Rect($glyph) if(defined $glyph->{'colour'});

  #########
  # now loop through $glyph's children
  #
  $self->SUPER::render_Composite($glyph,$Ta);

  #########
  # draw & colour the bounding area if specified
  #
  $glyph->{'colour'} = undef;
  $self->render_Rect($glyph) if(defined $glyph->{'bordercolour'});
}

#sub render_Bezier {
#  my ($self, $glyph) = @_;
#
#  my $colour = $self->colour($glyph->{'colour'});
#
#  return unless(defined $glyph->pixelpoints());
#
#  my @coords = @{$glyph->pixelpoints()};
#  my $bezier = Math::Bezier->new(\@coords);
#  my $points = $bezier->curve($glyph->{'samplesize'}||20);
#
#  my ($lx,$ly);
#  while (@$points) {
#    my ($x, $y) = splice(@$points, 0, 2);
#
#    $self->{'canvas'}->line($lx, $ly, $x, $y, $colour) if(defined($lx) && defined($ly));
#    ($lx, $ly) = ($x, $y);
#  }
#}

sub render_Sprite {
  my ($self, $glyph) = @_;
  my $spritename     = $glyph->{'sprite'} || 'unknown';
  my $config         = $self->config();

  unless(exists $config->{'_spritecache'}->{$spritename}) {
    my $libref = $config->get_parameter(  'spritelib');
    my $lib    = $libref->{$glyph->{'spritelib'} || 'default'};
    my $fn     = "$lib/$spritename.gif";

    unless( -r $fn ){
      warn( "$fn is unreadable by uid/gid" );
      return;
    }

    $config->{'_spritecache'}->{$spritename} = GD::Image->newFromGif($fn);

    if( !$config->{'_spritecache'}->{$spritename} ) {
      $config->{'_spritecache'}->{$spritename} = GD::Image->newFromGif("$lib/missing.gif");
    }
  }

  my $sprite = $config->{'_spritecache'}->{$spritename};

  return unless $sprite;
  my ($width, $height) = $sprite->getBounds();

  my $METHOD = $self->{'canvas'}->can('copyRescaled') ? 'copyRescaled' : 'copyResized' ;
  $self->{'canvas'}->$METHOD($sprite,
			     $self->{sf} * $glyph->{'pixelx'},
			     $self->{sf} * $glyph->{'pixely'},
			     0,
			     0,
			     $self->{sf} * $glyph->{'pixelwidth'}  || 1,
			     $self->{sf} * $glyph->{'pixelheight'} || 1,
			     $width,
			     $height);
}

1;