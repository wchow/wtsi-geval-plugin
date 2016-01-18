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

package Bio::EnsEMBL::GlyphSet::gEVAL_clone;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

#--------------------------------#
#--------------------------------#
# Glyph for clone track          #
#                                #
#   -wc2@sanger                  # 
#--------------------------------#
#--------------------------------#


#-------------------------------------#
# feature_group
#  This helps in grouping those obj 
#   such as unfinished clones and/or
#   pools (ZGTC -NOT USED ANYMORE)
#  
#-------------------------------------#
sub feature_group{
  my( $self, $f ) = @_;

  my $id = $f->get_scalar_attribute('internal_clone');
  (my $group_name = $id) =~ s/\..*//;
  return $group_name;
}


#-------------------------------------#
# features
#  Returns all the features of a 
#  specific logic_name in the window
#  of interest.
#-------------------------------------#
sub features {
  my ($self) = @_;
  my $misc_sets = $self->my_config('set');
  my @T         = ($misc_sets);
  my $feats = $self->{'container'}->get_all_MiscFeatures( $T[0], undef );
  return $feats;

}


#-------------------------------------#
# get_colours
#  Returns appropriate colours of the
#  glyph itself.  Default is the yellow
#  goldenrod1 colour.
#-------------------------------------#
sub get_colours {
  my( $self, $f ) = @_;

  my $key     = 'clone';
  my $feature = 'goldenrod1';
  my $label   = 'black';
  my $part    = '';
  

  my $coverage = $f->get_scalar_attribute('dh_coverage');
  my $status   = $f->get_scalar_attribute('clone_status');

  ###########
  ## wc2
  ## This deals with the colouring of the glyphs based on status.  Most apparent with zfish DH coverage 
  if ($status =~ /not yet sequenced/){
      $feature = "grey";
  }
  elsif( $coverage ne '' && $coverage == 0) {
    $feature = "white";   
  }
  elsif( $coverage > 0 ) {

    my $coverage_proportion = $coverage / 100;
        
    my $red_proportion = ($coverage_proportion - 0.5) / 0.25;
    if($red_proportion < 0) {$red_proportion = 0}
    if($red_proportion > 1) {$red_proportion = 1}
    my $red = int($red_proportion * 255);
    
    my $blue_proportion = (0.5 - $coverage_proportion) / 0.25;
    if($blue_proportion < 0) {$blue_proportion = 0}
    if($blue_proportion > 1) {$blue_proportion = 1}
    my $blue = int($blue_proportion * 255);
    
    my $green_proportion = (0.5 - abs(0.5 - $coverage_proportion)) / 0.25;
    if($green_proportion > 1) {$green_proportion = 1}
    my $green = int($green_proportion * 255);

    $feature = sprintf("%02x%02x%02x", $red, $green, $blue);
  }

  return { key     => $key,
	   feature => $feature, 
	   label   => $label, 
	   part    => $part
	   };
  
}


#-------------------------------------#
# _colour_key
#  Little to zero Use!!!!
#-------------------------------------#
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


#-------------------------------------#
# feature_label
#  This generic call returns the label
#  for the glyph, overlaid in the 
#  middle of the glyph.
#-------------------------------------#
sub feature_label {
  my ($self, $f ) = @_;

  my $label = "clone";

  if ( $f->get_scalar_attribute('internal_clone') &&
       $f->get_all_Attributes('accession') ) {
    
    my $accession = $f->get_all_Attributes('accession');
    my $version   = ".".$f->get_all_Attribtues('version') || "";
    my $internal  = $f->get_scalar_attribute('internal_clone');
    $label = "$internal / $accession$version";
    return $label;

  }
  $label = $f->get_scalar_attribute('internal_clone') if ($f->get_scalar_attribute('internal_clone'));
  $label = $f->get_scalar_attribute('jira_id') if ($f->get_scalar_attribute('jira_id'));
 
  return ($label, 'overlaid');
  return  ( $self->my_config('no_label')) 
        ? ()
	: ($f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc)),'overlaid')
        ;
}

#-------------------------------------#
# href
#  returns the results into the zmenu
#-------------------------------------#
sub href {
  my ($self, $f_ref ) = @_;

  my @feats = @$f_ref;
  my $db    = $self->my_config('db');
  my ($zmenu, $name, $mfid, $r);
  
  my $f = $feats[0][2];
  $name = $f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc internal_clone));
  $mfid = $f->dbID;
  #my $seq_region_name = $f->seq_region_name;
  $r = $self->{'container'}->seq_region_name.":".$self->{'container'}->start ."-". $self->{'container'}->end;

  $name =~ s/\..*\d+//g;
      
  my $sa  = $self->{'container'}->adaptor;
  my $csa = $self->{'container'}->adaptor->db->get_CoordSystemAdaptor;

  # Make sure there is a clone csname, else use contig/seqlevel.
  my $csname = ($csa->fetch_by_name('clone') ) ? "clone" : "seqlevel";
		
  my $clone_slice = $sa->fetch_by_region($csname, $name) || undef;
  my $clone_seq_region_length;
  $clone_seq_region_length = ($clone_slice) ? $clone_slice->seq_region_length : undef;
  my @project;
  my $ctg_num = 0;
  #my $species = $self->species;
  $zmenu = {
      'type'          =>'Clone',
      'action'        =>'View',
      'mfid'          => $mfid,
      'hitname'       => $name,
      'db'            => $db,
      'species'       => $self->species,
      'length'        => $clone_seq_region_length || 0,	
  };


  # fetches the coord_systems for this organism and stores the names in a hash.
  my $csa = $sa->db->get_CoordSystemAdaptor();
  my %cs = map {$_->name, 1} @{ $csa->fetch_all() };

  if ($cs{'contig'} && $clone_slice){ 
      @project = @{$clone_slice->project('contig')};
      $ctg_num = @project;
  }

  ############	
  ## basic zmenu for fin clones, and not sequenced clones, 
  ##  the <2 solves the problem that if you zoom too close 
  ##  to an unfin clone to 1 ctg, it will not give you the 
  ##  generic menu but the full menu, in the next else step.
  if ((@feats eq 1) && ($ctg_num < 2)){
      my $f =$feats[0][2];
      $r = $self->{'container'}->seq_region_name.":".$f->seq_region_start.'-'.$f->seq_region_end;

      $zmenu->{'r'} = $r;
      $zmenu->{'misc_feature_n'} = $name;
  }
  else {

      my ($seq_region_start, $seq_region_end) =(0,0);
      my @ctgs;
      my %pool_clones;
      foreach (sort {$a->[0] <=> $b->[0] } @feats){
	  my $f = $_->[2];
	  
	  $seq_region_start = $f->seq_region_start if ($f->seq_region_start < $seq_region_start || $seq_region_start eq 0) ;
	  $seq_region_end   = $f->seq_region_end if ( $f->seq_region_end > $seq_region_end );
	  ############################
	  #GET FRAG Chain information#
	  ############################
	  my $int_clone_name = $f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc internal_clone));
	  
	  my $ctg_slice = $sa->fetch_by_region('contig', $int_clone_name);
	  my ($fragchain, $clone_end);

	  if (!$ctg_slice){goto DEFAULT;} # This is because the pool ctgs have a clone name zHABC123 but of course officially no seq in TPF

	  my @fc_list = @{$ctg_slice->get_all_Attributes('fragment_chain')};
	  my @ce_list = @{$ctg_slice->get_all_Attributes('clone_end')};

	  ###
	  
	  $fragchain = $fc_list[0]->value || "" if (@fc_list);
	  $clone_end = $ce_list[0]->value || "" if (@ce_list);
	  
	  $int_clone_name .= "::" if (($fragchain)||($clone_end));
	  $int_clone_name .= "[$fragchain]" if ($fragchain);
	  $int_clone_name .= "($clone_end)" if ($clone_end);
	  push ( @ctgs, $int_clone_name ) ;
      }
      
      my $clone_length = $clone_seq_region_length || ($seq_region_end - $seq_region_start +1) ;

    DEFAULT:

      my $ctg_list  = join(", ", @ctgs);
      my $pool_list = undef;
      foreach (keys %pool_clones){
	  $pool_list .= $_ .",";
      }

      $r = $self->{'container'}->seq_region_name.":".$seq_region_start.'-'.$seq_region_end;
      $zmenu->{'length'}         = $clone_length;   
      $zmenu->{'r'}              = $r;
      $zmenu->{'misc_feature_n'} = $name;
      $zmenu->{'unfin_ctgs'}     = $ctg_list;
      $zmenu->{'ctg_num'}        = $ctg_num;
      $zmenu->{'pool_clones'}    = $pool_list;
      
  }
  return $self->_url($zmenu);
}


###################################################
# START DRAW - WC
###################################################

# Next we have the _init function which chooses how to render the
# features...
#==============================================================================

sub render_unlimited {
  my $self = shift;
  $self->render_normal( 1, 1000 );
}

sub render_stack {
  my $self = shift;
  $self->render_normal( 1, 40 );
}

sub render_half_height {
  my $self = shift;
  $self->render_normal( $self->my_config('height')/2 || 4);
}

sub colour_key {
  my( $self, $feature_key ) = @_;
  return $self->my_config( 'sub_type' );
}

sub render_labels {
  my $self = shift;
  $self->{'show_labels'} = 1;
  $self->render_normal();
}


#-------------------------------------#
# render_normal
#  The main component for drawing the
#  glyph.
#-------------------------------------#
sub render_normal {

  my ($self) = @_;
  
  return $self->render_text if $self->{'text_export'};
  
  my $slice   = $self->{'container'};
  #$self->_threshold_update();
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
  my $dep            = $self->my_config('depth')||100000;
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
    $h = $self->{'extras'}{'height'};
  }
  my $previous_start = $slice_length + 1e9;
  my $previous_end   = -1e9 ;
  my ($T,$C,$C1) = 0;
  my $optimizable = $self->my_config('optimizable') && $dep<1 ; #at the moment can only optimize repeats...
  
  my $top_features = $self->features(); 

  unless(ref($top_features)eq'ARRAY') {
    # warn( ref($self), ' features not array ref ',ref($features) );
    return; 
  }

  my $aggregate = '';
  
  if( $aggregate ) {
    ## We need to set max depth to 0.1
    ## We need to remove labels (Zmenu becomes density score)
    ## We need to produce new features for each bin
    my $aggregate_function = "aggregate_$aggregate";
    $top_features = $self->$aggregate_function( $top_features ); 
  }

  ##############################
  # Compile Features
  ##############################

  my %features;
  my $featcount =0;
  foreach my $f ( @$top_features ){      
      my $hstrand  = $f->can('hstrand')  ? $f->hstrand : 1;
      my $fgroup_name = $self->feature_group( $f );
      
      next if $strand_flag eq 'b' && $strand != ( $hstrand*$f->strand || -1 ) || $f->end < 1 || $f->start > $slice_length ;
      
      push @{$features{$fgroup_name}}, [$f->start,$f->end,$f];
      $featcount++;
  }

  ##############################


  foreach my $clone ( keys %features ) {
      my $X = -1000000;
      my $featnum;

      my @F     = sort { $a->[0] <=> $b->[0] } @{$features{$clone}};
      my $f     = $F[0][2];
      my $start = $F[0][0] < 1 ? 1 : $F[0][0];
      my $end   = $F[-1][1] > $slice_length ? $slice_length : $F[-1][1];
 
    ## Check strand for display ##
    my $fstrand = $f->strand || -1;
    next if( $strand_flag eq 'b' && $strand != $fstrand );

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
    my ($label, $style)       = ($clone, 'overlaid');
    my( $txt, $part, $W, $H ) = $self->get_text_width( 0, $label, '', 'font' => $FONT, 'ptsize' => $FONTSIZE );
    my $bp_textwidth          = $W / $pix_per_bp;
    
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
        'absolutey'  => 1
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
    } else { ## WC HERE we begin composite draw
	my $count=0;
	$featnum = @F;
	foreach  my $sub_f ( @F ){

	    #next if int($sub_f->[1] * $pix_per_bp) <= int( $X * $pix_per_bp );

	    my $START = $sub_f->[0] < 1 ? 1 : $sub_f->[0];
	    my $END   = $sub_f->[1] > $slice_length ? $slice_length : $sub_f->[1];
	    	    
	    $X = $END;
	    my $border_colour = $colours->{'feature'};
	    $border_colour = "black" if ($featnum>1);

	    $composite->push( $self->Rect({
		'x'          => $START-1,
		'y'          => 0, # $y_pos,
		'width'      => $END-$START+1,
		'height'     => $h,
		'bordercolour' => $border_colour,
		"colour" => $colours->{'feature'},
		'absolutey'  => 1,
	    }));
							   
	    $count++;

	}
	 
      #$composite->push( $self->Rect({
      #  'x'          => $start-1,
      #  'y'          => 0,
      #  'width'      => $end - $start + 1,
      #  'height'     => $h,
      #  $colours->{'part'}."colour" => $colours->{'feature'},
      #  'absolutey'  => 1
      #}) );
    }
      $composite->bordercolour('black') if ($featnum >1);

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
        # print STDERR "X: $label - $colours->{'label'}\n";
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
      if( $style eq 'overlaid' ) {
        if ($bp_textwidth < ($end - $start+1)){
          # print STDERR "X: $label - $colours->{'label'}\n";
	    if ($featnum<2){
		$composite->push($self->Text({
		    'x'          => $start-1,
		    'y'          => ($h-$H)/2-1,
		    'width'      => $end-$start+1,
		    'textwidth'  => $bp_textwidth*$pix_per_bp,
		    'font'       => $FONT,
		    'ptsize'     => $FONTSIZE,
		    'halign'     => 'center',
		    'height'     => $H,
		    'colour'     => $colours->{'label'},
		    'text'       => $label,
		    'absolutey'  => 1,
		}));
	    }
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
      $composite->{'href'}  = $self->href(  \@F ) if $self->can('href');
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
  # warn( ref($self)," $C1 out of $C out of $T features drawn\n" );
  ## No features show "empty track line" if option set....  ##
  $self->no_features() if $flag; 
}



sub highlight {
  my $self = shift;
  my ($f, $composite, $pix_per_bp, $h) = @_;

  ## Get highlights...
  my %highlights;
  @highlights{$self->highlights()} = ();

  ## Are we going to highlight this item...
  if($f->can('display_name') && exists $highlights{$f->display_name()}) {
    $self->unshift($self->Rect({
      'x'         => $composite->x() - 1/$pix_per_bp,
      'y'         => $composite->y() - 1,
      'width'     => $composite->width() + 2/$pix_per_bp,
      'height'    => $h + 2,
      'colour'    => 'highlight1',
      'absolutey' => 1,
    }));
  }
}


1;
