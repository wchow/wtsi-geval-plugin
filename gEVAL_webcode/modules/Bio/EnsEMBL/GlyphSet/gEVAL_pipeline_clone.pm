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

package Bio::EnsEMBL::GlyphSet::gEVAL_pipeline_clone;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub _init {
  my ($self) = @_;
  
  return $self->render_text if $self->{'text_export'};
  
  my $slice   = $self->{'container'};
#  $self->_threshold_update();
  my $strand          = $self->strand();
  my $strand_flag     = $self->my_config( 'strand' );
  my($FONT,$FONTSIZE) = $self->get_font_details( $self->my_config('font') || 'innertext' );
  my $BUMP_WIDTH      = $self->my_config( 'bump_width');
  $BUMP_WIDTH         = 1 unless defined $BUMP_WIDTH;
  
  ## If only displaying on one strand skip IF not on right strand....
  return if $strand_flag eq 'r' && $strand != -1;
  return if $strand_flag eq 'f' && $strand != 1;

  # Get information about the VC - length, and whether or not to
  # display track/navigation               
  my $slice_length   = $slice->length( );
  my $max_length     = $self->my_config( 'threshold' )            || 200000000;
  my $navigation     = $self->my_config( 'navigation' )           || 'on';
  my $max_length_nav = $self->my_config( 'navigation_threshold' ) || 15000000;

  if( $slice_length > $max_length *1010 ) {
    $self->errorTrack( $self->my_config('caption')." only displayed for less than $max_length Kb.");
    return;
  }

  ## Decide whether we are going to include navigation (independent of switch) 
  $navigation = ($navigation eq 'on') && ($slice_length <= $max_length_nav *1010);

  ## Set up bumping bitmap

  ## Get information about bp/pixels    
  my $pix_per_bp     = $self->scalex;
  my $bitmap_length  = int($slice->length * $pix_per_bp);
  ## And the colours
  my $dep            = defined($self->my_config('depth')) ? $self->my_config('depth') : 100000;
  $self->_init_bump( undef, $dep );

  my $flag           = 1;
  my($temp1,$temp2,$temp3,$H) = $self->get_text_width(0,'X','','font'=>$FONT,'ptsize' => $FONTSIZE );
  my $th = $H;
  my $tw = $temp3;
  my $h  = $self->my_config('height') || $H+2;
  if(
    $dep>0 &&
    $self->get_parameter(  'squishable_features' ) eq 'yes' &&
    $self->my_config('squish')
  ) {
    $h = 4;
  }
  if( $self->{'extras'} && $self->{'extras'}{'height'} ) {
    #warn 
    $h = $self->{'extras'}{'height'};
  }
  my $previous_start = $slice_length + 1e9;
  my $previous_end   = -1e9 ;
  my ($T,$C,$C1) = 0;
  my $optimizable = $self->my_config('optimizable') && $dep<1 ; #at the moment can only optimize repeats...

  my $features = $self->features(); 

  unless(ref($features)eq'ARRAY') {
    # warn( ref($self), ' features not array ref ',ref($features) );
    return; 
  }

  my $aggregate = '';
  
  if( $aggregate ) {
    ## We need to set max depth to 0.1
    ## We need to remove labels (Zmenu becomes density score)
    ## We need to produce new features for each bin
    my $aggregate_function = "aggregate_$aggregate";
    $features = $self->$aggregate_function( $features ); 
  }

  foreach my $f ( @{$features} ) { 
    #print STDERR "Added feature ", $f->id(), " for drawing.\n";
    ## Check strand for display ##
    my $fstrand = $f->strand || -1;
    next if( $strand_flag eq 'b' && $strand != $fstrand );

    ## Check start are not outside VC.... ##
    my $start = $f->start();
    next if $start>$slice_length; ## Skip if totally outside VC

    $start = 1 if $start < 1;  
    ## Check end are not outside VC.... ##
    my $end   = $f->end();   
    next if $end<1;            ## Skip if totally outside VC
    $end   = $slice_length if $end>$slice_length;
    $T++;
    next if $optimizable && ( $slice->strand() < 0 ?
                                $previous_start-$start < 0.5/$pix_per_bp : 
                                $end-$previous_end     < 0.5/$pix_per_bp );
    $C ++;
    $previous_end   = $end;
    $previous_start = $end;
    $flag = 0;
    my $img_start = $start;
    my $img_end   = $end;
    my( $label,      $style ) = $self->feature_label( $f, $tw );
    my( $txt, $part, $W, $H ) = $self->get_text_width( 0, $label, '', 'font' => $FONT, 'ptsize' => $FONTSIZE );
    my $bp_textwidth = $W / $pix_per_bp;
    
    my( $tag_start ,$tag_end) = ($start, $end);
    if( $label && $style ne 'overlaid' ) {
      $tag_start = ( $start + $end - 1 - $bp_textwidth ) /2;
      $tag_start = 1 if $tag_start < 1;
      $tag_end   = $tag_start + $bp_textwidth;
    }
    $img_start = $tag_start if $tag_start < $img_start; 
    $img_end   = $tag_end   if $tag_end   > $img_end; 
    my @tags = $self->tag($f);
    foreach my $tag (@tags) { 
      next unless ref($tag) eq 'HASH';
      $tag_start = $start; 
      $tag_end = $end;    
      if($tag->{'style'} eq 'snp' ) {
        $tag_start = $start - 1/2 - 4/$pix_per_bp;
        $tag_end   = $start - 1/2 + 4/$pix_per_bp;
      } elsif( $tag->{'style'} eq 'left-snp' || $tag->{'style'} eq 'delta' || $tag->{'style'} eq 'box' ) {
        $tag_start = $start - 1 - 4/$pix_per_bp;
        $tag_end   = $start - 1 + 4/$pix_per_bp;
      } elsif($tag->{'style'} eq 'right-snp') {
        $tag_start = $end - 4/$pix_per_bp;
        $tag_end   = $end + 4/$pix_per_bp;
      } elsif($tag->{'style'} eq 'underline') {
        $tag_start = $tag->{'start'} if defined $tag->{'start'};
        $tag_end   = $tag->{'end'}   if defined $tag->{'end'};
      } elsif($tag->{'style'} eq 'fg_ends') {
        $tag_start = $tag->{'start'} if defined $tag->{'start'};
        $tag_end   = $tag->{'end'}   if defined $tag->{'end'};
      }
      $img_start = $tag_start if $tag_start < $img_start; 
      $img_end   = $tag_end   if $tag_end   > $img_end;  
    } 
    ## This is the bit we compute the width.... 
        
    my $row = 0;
    if ($dep > 0){ # we bump
      $img_start = int($img_start * $pix_per_bp);
      $img_end   = $BUMP_WIDTH + int( $img_end * $pix_per_bp );
      $img_end   = $img_start if $img_end < $img_start;
      $row = $self->bump_row( $img_start, $img_end );
      next if $row > $dep;
    }
    my @tag_glyphs = ();

    my $colours        = $self->get_colours($f);
    
    ## Lets see about placing labels on objects...        
    my $composite = $self->Composite();
    if($colours->{'part'} eq 'line') {
      #    print STDERR "PUSHING LINE\n"; 
      $composite->push( $self->Space({
        'x'          => $start-1,
        'y'          => 0,
        'width'      => $end - $start + 1,
        'height'     => $h,
        "colour"     => $colours->{'feature'},
        'absolutey'  => 1
                               }));
      $composite->push( $self->Rect({
        'x'          => $start-1,
        'y'          => $h/2+1,
        'width'      => $end - $start + 1,
        'height'     => 0,
        "colour"     => $colours->{'feature'},
        'absolutey'  => 1,
      }));
    } elsif( $colours->{'part'} eq 'invisible' ) {
      $composite->push( $self->Space({
        'x'          => $start-1,
        'y'          => 0,
        'width'      => $end - $start + 1,
        'height'     => $h,
        'absolutey'  => 1
      }) );
    } elsif( $colours->{'part'} eq 'align' ) {
      $composite->push( $self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'z' => 20,
          'width'      => $end - $start + 1,
          'height'     => $h+2,
          "colour"     => $colours->{'feature'},
          'absolutey'  => 1,
          'absolutez'  => 1,
      }) );
    } else { 
      $composite->push( $self->Rect({
        'x'          => $start-1,
        'y'          => 0,
        'width'      => $end - $start + 1,
        'height'     => $h,
        $colours->{'part'}."colour" => $colours->{'feature'},
        'absolutey'  => 1,
		'bordercolour' => $colours->{'border'},
      }) );
	  # add the arrow to the image.
	    my $end_anchor = $f->get_scalar_attribute('end_anchor');
		
		my $pix_per_bp     = $self->scalex;
		my $arrow_scale    = int(5/$pix_per_bp);
	    #my $y_offset -= $strand * ( ($self->_max_bump_row ) * ( $h + $gap + $label_h ) + 6 );
		my $y_offset = 0;
	  	my $gap    = $h<2 ? 4 : 5;   
      	my $y_pos = $y_offset - $row * int( $h + $gap ) * $strand ;
		if($end_anchor eq 'right') {
			$self->push($self->Poly({
	    		'points' => [$start                ,0 + $y_pos,
				 $start - $arrow_scale ,$h/2 + $y_pos,
				 $start                ,	$h + $y_pos,
				 ],
   	    		'colour'    => $colours->{'feature'},
	    		'absolutey' => 1,
				'bordercolour' => $colours->{'border'},
			}));
		}
		elsif($end_anchor eq 'left') {
		  $self->push($self->Poly({
	    	'points' => [$end                ,0 + $y_pos,
				 $end + $arrow_scale ,$h/2 + $y_pos,
				 $end                ,	$h + $y_pos,
				 ],
   	    	'colour'    => $colours->{'feature'},
	    	'absolutey' => 1,
			'bordercolour' => $colours->{'border'},
			}));
		}
    }
    my $rowheight = int($h * 1.5);

    foreach my $tag ( @tags ) {
      next unless ref($tag) eq 'HASH';
      if($tag->{'style'} eq 'left-end' && $start == $f->start) {
        ## Draw a line on the left hand end....
        $composite->push($self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'width'      => 0,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
      } elsif($tag->{'style'} eq 'right-end' && $end == $f->end) {
        ## Draw a line on the right hand end....
        $composite->push($self->Rect({
          'x'          => $end,
          'y'          => 0,
          'width'      => 0,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
      } elsif($tag->{'style'} eq 'insertion') {
        my $triangle_end   =  $start-1 - 2/$pix_per_bp;
        my $triangle_start =  $start-1 + 2/$pix_per_bp;
        push @tag_glyphs, $self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'width'      => 0,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }),$self->Poly({
          'points'    => [ $triangle_start, $h+2,
                           $start-1, $h-1,
                           $triangle_end, $h+2  ],
          'colour'    => $tag->{'colour'},
          'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'left-triangle') {
         my $triangle_end = $start -1 + 3/$pix_per_bp;
            $triangle_end = $end if( $triangle_end > $end);
         push @tag_glyphs, $self->Poly({
           'points'    => [ $start-1, 0,
                            $start-1, 3,
                            $triangle_end, 0  ],
           'colour'    => $tag->{'colour'},
           'absolutey' => 1,
         });
			} elsif($tag->{'style'} eq 'bound_triangle_left') {
				 my $x       = $tag->{start} - ($h/2)/$pix_per_bp;
				 my $y       = $h/2;
				 my $height  = $y/$pix_per_bp;
				 
				 if ($img_start < $tag->{start} and $img_end > $tag->{end}) {
				 		push @tag_glyphs, $self->Triangle({
					 		'x'            => $x,
					 		'y'            => 0,
					 		'mid_point'    => [ $x, $y ],
           		'colour'       => $tag->{'colour'},
           		'absolutey'    => 1,
					 		'width'        => $h,
         	 		'height'       => $height,
					 		'direction'    => 'left',
							'bordercolour' => 'black',
         		});
				 }
			} elsif($tag->{'style'} eq 'bound_triangle_right') {
				 my $x       = $tag->{start} + ($h/2)/$pix_per_bp;
				 my $y       = $h/2;
				 my $height  = $y/$pix_per_bp;
				 
				 if ($img_start < $tag->{start} and $img_end > $tag->{end}) {
				 		push @tag_glyphs, $self->Triangle({
					 		'x'            => $x,
					 		'y'            => 0,
					 		'mid_point'    => [ $x, $y ],
           		'colour'       => $tag->{'colour'},
           		'absolutey'    => 1,
					 		'width'        => $h,
         	 		'height'       => $height,
					 		'direction'    => 'right',
							'bordercolour' => 'black',
         		});
				 }
      } elsif($tag->{'style'} eq 'right-snp') {
        next if($end < $f->end());
        my $triangle_start =  $end - 1/2 + 4/$pix_per_bp;
        my $triangle_end   =  $end - 1/2 + 4/$pix_per_bp;
        $composite->push($self->Space({
          'x'          => $triangle_start,
          'y'          => $h,
          'width'      => 8/$pix_per_bp,
          'height'     => 0,
          'colour'     => $tag->{'colour'},
          'absolutey'  => 1
        }));
        push @tag_glyphs, $self->Poly({
           'points'    => [ $triangle_start, $h,
                            $end - 1/2,      0,
                            $triangle_end,   $h  ],
           'colour'    => $tag->{'colour'},
           'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'snp') {
        next if( $tag->{'start'} < 1) ;
        next if( $tag->{'start'} > $slice_length );
        my $triangle_start =  $tag->{'start'} - 1/2 - 4/$pix_per_bp;
        my $triangle_end   =  $tag->{'start'} - 1/2 + 4/$pix_per_bp;
        $composite->push($self->Space({
          'x'          => $triangle_start,
          'y'          => $h,
          'width'      => 8/$pix_per_bp,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
        push @tag_glyphs, $self->Poly({
          'points'    => [ $triangle_start, $h,
                           $tag->{'start'} - 1/2 , 0,
                           $triangle_end,   $h  ],
          'colour'    => $tag->{'colour'},
          'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'rect') {
        next if $tag->{'start'} > $slice_length;
        next if $tag->{'end'}   < 0;
        my $s = $tag->{'start'} < 1 ? 1 : $tag->{'start'};
        my $e = $tag->{'end'}   > $slice_length ? $slice_length : $tag->{'end'}; 
        $composite->push($self->Rect({
          'x'          => $s-1,
          'y'          => 0,
          'width'      => $e-$s+1,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
      } elsif($tag->{'style'} eq 'box') {
        next if($start > $f->start());
        my $triangle_start =  $start - 1/2 - 4/$pix_per_bp;
        my $triangle_end   =  $start - 1/2 + 4/$pix_per_bp;
        $composite->push($self->Rect({
          'x'          => $triangle_start,
          'y'          => 1,
          'width'      => 8/$pix_per_bp,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
        my @res = $self->get_text_width( 0, $tag->{'letter'},'', 'font'=>$FONT, 'ptsize' => $FONTSIZE );
        my $tmp_width = $res[2]/$pix_per_bp;
        $composite->push($self->Text({
          'x'          => ($end + $start - 1/4 - $tmp_width)/2,
          'y'          => ($h-$H)/2,
          'width'      => $tmp_width,
          'textwidth'  => $res[2],
          'height'     => $H,
          'font'       => $FONT,
          'ptsize'     => $FONTSIZE,
          'halign'     => 'center',
          'colour'     => $tag->{'label_colour'},
          'text'       => $tag->{'letter'},
          'absolutey'  => 1,
        }));
      } elsif($tag->{'style'} eq 'delta') {
        next if($start > $f->start());
        my $triangle_start =  $start - 1/2 - 4/$pix_per_bp;
        my $triangle_end   =  $start - 1/2 + 4/$pix_per_bp;
        $composite->push($self->Space({
          'x'          => $triangle_start,
          'y'          => $h,
          'width'      => 8/$pix_per_bp,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
        push @tag_glyphs, $self->Poly({
          'points'    => [ $triangle_start, 0,
                           $start - 1/2   , $h,
                           $triangle_end  , 0  ],
          'colour'    => $tag->{'colour'},
          'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'left-snp') {
        next if($start > $f->start());
        my $triangle_start =  $start - 1/2 - 4/$pix_per_bp;
        my $triangle_end   =  $start - 1/2 + 4/$pix_per_bp;
        $composite->push($self->Space({
          'x'          => $triangle_start,
          'y'          => $h,
          'width'      => 8/$pix_per_bp,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
        push @tag_glyphs, $self->Poly({
          'points'    => [ $triangle_start, $h,
                           $start - 1/2   , 0,
                           $triangle_end  , $h  ],
          'colour'    => $tag->{'colour'},
          'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'right-triangle') {
        my $triangle_start =  $end - 3/$pix_per_bp;
        $triangle_start = $start if( $triangle_start < $start);
        push @tag_glyphs, $self->Poly({
          'points'    => [ $end, 0,
                           $end, 3,
                           $triangle_start, 0  ],
          'colour'    => $tag->{'colour'},
          'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'underline') {
        my $underline_start = $tag->{'start'} || $start ;
        my $underline_end   = $tag->{'end'}   || $end ;
        $underline_start = 1          if $underline_start < 1;
        $underline_end   = $slice_length if $underline_end   > $slice_length;
        $composite->push($self->Rect({
          'x'          => $underline_start -1 ,
          'y'          => $h,
          'width'      => $underline_end - $underline_start + 1,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
      } elsif($tag->{'style'} eq 'fg_ends') {
        my $f_start = $tag->{'start'} || $start ;
        my $f_end   = $tag->{'end'}   || $end ;
        $f_start = 1          if $f_start < 1;
        $f_end   = $slice_length if $f_end   > $slice_length;
        $composite->push( $self->Rect({
          'x'          => $f_start -1 ,
          'y'          => ($h/2),
          'width'      => $f_end - $f_start + 1,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1,
          'zindex'     => 0  
        }),$self->Rect({
          'x'          => $f_start -1 ,
          'y'          => 0,
          'width'      => 0,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'zindex'  => 1
        }),$self->Rect({
          'x'          => $f_end,
          'y'          => 0,
          'width'      => 0,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'zindex'  => 1
        }) );
      } elsif($tag->{'style'} eq 'line') {
        my $underline_start = $tag->{'start'} || $start ;
        my $underline_end   = $tag->{'end'}   || $end ;
        $underline_start = 1          if $underline_start < 1;
        $underline_end   = $slice_length if $underline_end   > $slice_length;
        $composite->push($self->Rect({
          'x'          => $underline_start -1 ,
          'y'          => $h/2,
          'width'      => $underline_end - $underline_start + 1,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
      } elsif($tag->{'style'} eq 'join') { 
        my $A = $strand > 0 ? 1 : 0;
        $self->join_tag( $composite, $tag->{'tag'}, $A, $A , $tag->{'colour'}, 'fill', $tag->{'zindex'} || -10 ),
        $self->join_tag( $composite, $tag->{'tag'}, 1-$A, $A , $tag->{'colour'}, 'fill', $tag->{'zindex'} || -10 )
      }
    }

    if( $style =~ /^mark_/ ) {
      my $bcol = 'red';
      if( $style =~ /_exonstart/ ) {
        $composite->push($self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'z'          => 10,
          'width'      => 1,
          'height'     => 0,
          "colour"     => $bcol,
          'absolutey'  => 1,
          'absolutez'  => 1
        }),$self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'z'          => 10,
          'width'      => 0,
          'height'     => $th,
          "colour"     => $bcol,
          'absolutey'  => 1,
          'absolutez'  => 1
        }));
      } elsif( $style =~ /_exonend/ ) {
        $composite->push( $self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'z'          => 10,
          'width'      => 1,
          'height'     => 0,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }),$self->Rect({
          'x'          => ($start-1/$pix_per_bp),
          'y'          => 1,
          'z'          => 10,
          'width'      => 1/(2*$pix_per_bp),
          'height'     => $th,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }));
      } elsif( $style =~ /_rexonstart/ ) {
        $composite->push( $self->Rect({
          'x'          => $start-1,
          'y'          => $th+1,
          'z'          => 10,
          'width'      => 1,
          'height'     => 0,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }),$self->Rect({
          'x'          => $start-1,
          'y'          => 1,
          'z'          => 10,
          'width'      => 0,
          'height'     => $th,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }) );
      } elsif( $style =~ /_rexonend/ ) {
        $composite->push( $self->Rect({
          'x'          => $start-1,
          'y'          => $th+1,
          'z'          => 10,
          'width'      => 1,
          'height'     => 0,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }),$self->Rect({
          'x'          => ($start-1/$pix_per_bp),
          'y'          => 1,
          'z'          => 10,
          'width'      => 1/($pix_per_bp*2),
          'height'     => $th,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }) );
      }
      if( $style =~ /_snpA/ ) {
        $composite->push ($self->Poly({
          'points'    => [ $start-1, 0,
                           $end+1, 0,
                           $end+1, $th  ],
          'colour'    => 'brown',
          'bordercolour'=>'red',
          'absolutey' => 1,
        }));
      }

      if($bp_textwidth < ($end - $start+1)){
        my $tglyph = $self->Text({
          'x'          => $start - 1,
          'y'          => ($h-$H)/2,
          'z' => 5,
          'width'      => $end-$start+1,
          'height'     => $H,
          'font'       => $FONT,
          'ptsize'     => $FONTSIZE,
          'halign'     => 'center',
          'colour'     => $colours->{'label'},
          'text'       => $label,
          'textwidth'  => $bp_textwidth*$pix_per_bp,
          'absolutey'  => 1,
          'absolutez'  => 1,
        });
        $composite->push($tglyph);
      }
    } elsif( $style && $label ) {
      my $font_size = $FONTSIZE;
      if( $style eq 'overlaid' ) {
        ## Reduce text size slightly for wider letters (A,M,V,W)
        my $tmp_textwidth = $bp_textwidth;
        
        if ($bp_textwidth >= ($end - $start+1) && length $label == 1){
          $font_size = $FONTSIZE * 0.9;
          $tmp_textwidth = [$self->get_text_width( 0, $label, '', 'font' => $FONT, 'ptsize' => $font_size )]->[2] / $pix_per_bp;
        }
        
        ## Only add labels above a certain feature size
        if ($tmp_textwidth < ($end - $start+1)){
          $composite->push($self->Text({
            'x'          => $start-1,
            'y'          => ($h-$H)/2-1,
            'width'      => $end-$start+1,
            'textwidth'  => $tmp_textwidth*$pix_per_bp,
            'font'       => $FONT,
            'ptsize'     => $font_size,
            'halign'     => 'center',
            'height'     => $H,
            'colour'     => $colours->{'label'},
            'text'       => $label,
            'absolutey'  => 1,
          }));
        }
      } else {
        my $label_strand = $self->my_config('label_strand');
        unless( $label_strand eq 'r' && $strand != -1 || $label_strand eq 'f' && $strand != 1 ) {
          $rowheight += $H+2;
          my $t = $self->Composite();
          $t->push($composite,$self->Text({
            'x'          => $start - 1,
            'y'          => $strand < 0 ? $h+3 : 3+$h,
            'width'      => $bp_textwidth,
            'height'     => $H,
            'font'       => $FONT,
            'ptsize'     => $FONTSIZE,
            'halign'     => 'left',
            'colour'     => $colours->{'label'},
            'text'       => $label,
            'absolutey'  => 1,
          }));
          $composite = $t;
	      }
      }
    }

    ## Lets see if we can Show navigation ?...
    if($navigation) {
      $composite->{'title'} = $self->title( $f ) if $self->can('title');
      $composite->{'href'}  = $self->href(  $f ) if $self->can('href');
      $composite->{'class'} = $self->class(  $f ) if $self->can('class');
    }
    
    ## Are we going to bump ?
    if($row>0) {
      $composite->y( $composite->y() - $row * $rowheight * $strand );
      foreach(@tag_glyphs) {
        $_->y_transform( - $row * $rowheight * $strand );
      }
    }
    $C1++;
    $self->push( $composite );
    $self->push(@tag_glyphs);

    $self->highlight($f, $composite, $pix_per_bp, $h, 'highlight1');
  }
#   warn( ref($self)," $C1 out of $C out of $T features drawn\n" );
  ## No features show "empty track line" if option set....  ##
  $self->no_features if $flag; 
}

## Retrieve all BAC map clones - these are the clones in the
## subset "bac_map" - if we are looking at a long segment then we only
## retrieve accessioned clones ("acc_bac_map")

sub features {
  my ($self) = @_;
  my $db = $self->my_config('db');
  my $misc_sets = $self->my_config('set');
  my @T = ($misc_sets);

  my @sorted =  
    map { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map { [$_->seq_region_start - 
      1e9 * (
      $_->get_scalar_attribute('state') + $_->get_scalar_attribute('BACend_flag')/4
      ), $_]
    }
    map { @{$self->{'container'}->get_all_MiscFeatures( $_, $db )||[]} } @T;
  return \@sorted;
}

## If bac map clones are very long then we draw them as "outlines" as
## we aren't convinced on their quality... However draw ENCODE filled

sub get_colours {
  my( $self, $f ) = @_;

  my $T = $self->SUPER::get_colours( $f );


#  use Data::Dumper;
#  print STDERR Dumper ( $T );

  my $border_colour = "indianred";
  my $is_clone_in_tpf = $f->get_scalar_attribute('is_clone_in_tpf');
  if (defined($is_clone_in_tpf)) {
  	if($is_clone_in_tpf eq 'currently') {
		$border_colour = 'green3';
	}
	elsif($is_clone_in_tpf eq 'previously') {
		$border_colour = 'yellow2';
	}
  }

	my $feature_colour = 'grey80';
	my $repetitions = $f->get_scalar_attribute('repetitions');
	if(defined($repetitions) and $repetitions > 1) {
		$feature_colour = 'lightsalmon1';
	}

  return {
    'key'     => 'clone',
    'feature' => $feature_colour,
    'label'   => 'black',
    'part'    => '',
	'border'  => $border_colour,
      };
  

  if( ! $self->my_colour( $T->{'key'}, 'solid' ) ) {
    $T->{'part'} = 'border' if $f->get_scalar_attribute('inner_start');
    $T->{'part'} = 'border' if ($self->my_config('outline_threshold') && ($f->length > $self->my_config('outline_threshold')) );
  }
  return $T;
}

sub colour_key {
  my ($self, $f) = @_;
  (my $state = $f->get_scalar_attribute('state')) =~ s/^\d\d://;
  return lc( $state ) if $state;
  my $flag = 'default';
  if( $self->my_config('set','alt') ) {
    $flag = $self->{'flags'}{$f->dbID} ||= $self->{'flag'} = ($self->{'flag'} eq 'default' ? 'alt' : 'default');
  }
  return ( $self->my_config('set'), $flag );
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub feature_label {
  my ($self, $f ) = @_;

  my $label = "clone";
  my $internal  = $f->get_scalar_attribute('sanger_name');
  if(defined($internal)) {
	  $label = $internal;
	}
	
  return ($label, 'overlaid');

}


## Link back to this page centred on the map fragment
sub href {
  my ($self, $f ) = @_;
  my $db = $self->my_config('db');
  my $name = $f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc));
  my $mfid = $f->dbID;
  my $r = $f->seq_region_name.':'.$f->seq_region_start.'-'.$f->seq_region_end;
  my $zmenu = {
      'type'          =>'Location',
      'action'        =>'View',
      'r'             => $r,
      'misc_feature_n'=> $name,
      'mfid'          => $mfid,
      'db'            => $db,
  };
  return $self->_url($zmenu);
}

sub tag {
  my ($self, $f) = @_; 
  my @result = (); 
  my $bef = $f->get_scalar_attribute('BACend_flag');
  (my $state = $f->get_scalar_attribute('state')) =~ s/^\d\d://;
  my ($s,$e) = $self->sr2slice( $f->get_scalar_attribute('inner_start'), $f->get_scalar_attribute('inner_end') );
  if( $s && $e ){
    push @result, {
      'style'  => 'rect',
      'colour' => $f->{'_colour_flag'} || $self->my_colour($state),
      'start'  => $s,
      'end'    => $e
    };
  }
  if( $f->get_scalar_attribute('fish') ) {
    push @result, {
      'style' => 'left-triangle',
      'colour' => $self->my_colour('fish_tag'),
    };
  }
  push @result, {
    'style'  => 'right-end',
    'colour' => $self->my_colour('bacend'),
  } if ( $bef == 2 || $bef == 3 );
  push @result, { 
    'style'=>'left-end',  
    'colour' => $self->my_colour('bacend'),
  } if ( $bef == 1 || $bef == 3 );

  my $fp_size = $f->get_scalar_attribute('fp_size');
  if( $fp_size && $fp_size > 0 ) {
    my $start = int( ($f->start + $f->end - $fp_size)/2 );
    my $end   = $start + $fp_size - 1 ;
    push @result, {
      'style' => 'underline',
      'colour' => $self->my_colour('seq_len'),
      'start'  => $start,
      'end'    => $end
    };
  }
  return @result;
}

sub export_feature {
  my $self = shift;
  my ($feature, $feature_type) = @_;
  
  return $self->_render_text($feature, $feature_type, { 
    'headers' => [ 'id' ],
    'values' => [ [$self->feature_label($feature)]->[0] ]
  });
}


## Create the zmenu...
## Include each accession id separately

1;
