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

package Bio::EnsEMBL::GlyphSet::gEVAL_pacbio;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

#------------------------------------#
#------------------------------------#
# this is a custom glyph to display  #
#  jt8's pacbio data                 #
#   -wc2@sanger                      # 
#------------------------------------#
#------------------------------------#



#-------------------------------------#
# feature_group
#  This is to extract cmp name from
#  read.  ( eg. paired ends)
#-------------------------------------#
sub feature_group {
  my( $self, $f ) = @_;

  my $gff_ID              = $f->get_scalar_attribute('gff_ID');
  my ($ctgname, $dir)     = split(/\./, $gff_ID);  
  return $ctgname;   
}

#-------------------------------------#
# feature_label
#  As the name says.
#-------------------------------------#
sub feature_label {
  my ($self, $f) = @_;
  return $f->get_scalar_attribute('gff_ID') || "";
}

#-------------------------------------#
# feature_title
#  Alt to the name, usually returned
#  when things don't go right.
#-------------------------------------#
sub feature_title {
  my ($self, $f) = @_;
  return $f->get_scalar_attribute('gff_ID') || "";	
}

#-------------------------------------#
# features
#  Returns all the features of a 
#  specific logic_name in the window
#  of interest.
#-------------------------------------#
sub features {

  my ($self) = @_;
  my $db        = $self->my_config('db');
  my $misc_sets = $self->my_config('set');
  my @T         = ($misc_sets);

  my @sorted  = map { @{$self->{'container'}->get_all_MiscFeatures( $_, $db )||[]} } @T;
  my %results = ( $self->my_config('name') => [@sorted] );
  return %results;

}

#-------------------------------------#
# href
#  This is used to return the neccesary
#  data to the Zmenu.
#  It now points to its specific Zmenu
#  Ends.pm.  Previously Genome.pm
#  Additional data may not be needed
#  but helps in compara view (species).
#-------------------------------------#
sub href {
    my ($self, $feature, $id, $group_items, $distance ) = @_;
   
    my $zmenu = {
	'type'            => 'Location',
	'action'          => 'View',
	'gff_ID'          => $id,
	'group_items'     => $group_items,
	'mfid'            => $feature->dbID(),
	'length'          => $distance,
        'gff_Gap'         => $feature->get_scalar_attribute('gff_GapSize'),

    };
    return $self->_url($zmenu);

}



#-------------------------------------#
# render_normal
#  the main code for drawing the glyph.
#  Most of the manipulation focuses on 
#  the groups of features processed 
#  to @F (array of arrays).
#  where $F[n] = (start, $end, $feat)
#  so $F[-1][2] would return $feat of
#  last entry in array.
#-------------------------------------#
sub render_normal {
  my $self = shift;

  use Time::HiRes qw(gettimeofday tv_interval); 
  return $self->render_text if $self->{'text_export'};
  
  my $tfh    = $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'});
  my $h      = @_ ? shift : ($self->my_config('height') || 8);
  my $dep    = @_ ? shift : ($self->my_config('dep'   ) || 100);
  my $gap    = $h<2 ? 1 : 2;   

  my $strand         = $self->strand;
  my $strand_flag    = $self->my_config('strand');
  my $l ength = $self->{'container'}->length();

  ## And now about the drawing configura#	    @region_features = undef;

  my $pix_per_bp     = $self->scalex;
  my $DRAW_CIGAR     = ( $self->my_config('force_cigar') eq 'yes' )|| ($pix_per_bp > 0.2) ;

  ## Highlights...
  my %highlights = map { $_ =~ s/^(.*?) .*/$1/; $_,1 } $self->highlights;
  my $hi_colour  = 'magenta', # Change colour here for highlighting search end hit.
  my $outline    = 0; 
  
  if( $self->{'extras'} && $self->{'extras'}{'height'} ) {
      $h = $self->{'extras'}{'height'};
  }

  my $y_offset = 0;
  my $label_h = 0;

  my $features_drawn  = 0;
  my $features_bumped = 0;

  my( $fontname, $fontsize ) ;
  if( $self->{'show_labels'} ) {
      ( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
      my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, 'X', '', 'ptsize' => $fontsize, 'font' => $fontname );
      $label_h = $th;
  }
  
  ##----------------------------##
  ## Fetch Features and Process ##
  ##----------------------------##

  my %features = $self->features;

  foreach my $feature_key ( keys %features ) {
    $self->_init_bump( undef, $dep );
    my %id = ();
    $self->{'track_key'} = $feature_key;
    
    ## Prepare and group features eg)by clone name #
    foreach my $f ( @{$features{$feature_key}} ) {

	my $hstrand             = $f->can('hstrand')  ? $f->hstrand : 1;
	my $fgroup_name         = $self->feature_group( $f );
	my $s                   = $f->start;
	my $e                   = $f->end;
	
	next if ( $strand_flag eq 'b' && 
		  $strand != ( ($hstrand||1)*$f->strand || -1 ) 
		  || $e < 1 || $s > $length );
	
	push @{$id{$fgroup_name}}, [$s,$e,$f,int($s*$pix_per_bp),int($e*$pix_per_bp),$f->get_scalar_attribute('gff_ID')];
	
    }

    ## Now go through each feature in turn, drawing them ##
    my $y_pos;
    my $feature_colour = "black";
    my $block_colour   = "e8ffcc";
    my $arrow_scale    = int(5/$pix_per_bp);
    
    my $logic_name = @{ $self->my_config( 'logicnames' )||[] }[0];

    my $regexp = $pix_per_bp > 0.1 ? '\dI' : ( $pix_per_bp > 0.01 ? '\d\dI' : '\d\d\dI' );
    next unless keys %id;

    foreach my $i (  sort { @{$id{$b}} <=> @{$id{$a}} 
			    #$id{$a}[0][3] <=> $id{$b}[0][3]  ||
			    #$id{$b}[-1][4] <=> $id{$a}[-1][4]
			} keys %id){
	my @F          = @{$id{$i}}; 
	
	my $START      = $F[0][0] < 1 ? 1 : $F[0][0];
	my $END        = $F[-1][1] > $length ? $length : $F[-1][1];
	my( $txt, $bit, $w, $th );
	my $bump_start = int($START * $pix_per_bp) - 1;
	my $bump_end   = int(($END) * $pix_per_bp);
	
	my @high_lights;	
	
	if( $self->{'show_labels'} ) {
	    my $title = $self->feature_label( $F[0][2] );
	    my( $txt, $bit, $tw,$th ) = $self->get_text_width( 0, 
							       $title, 
							       '', 
							       'ptsize' => $fontsize, 
							       'font' => $fontname );
	    my $text_end = $bump_start + $tw + 1;
	    $bump_end = $text_end if $text_end > $bump_end;
	}

	my $s_time     = [gettimeofday()];
	my $row        = $self->bump_row( $bump_start, $bump_end );

	if( $row > $dep ) {
	    $features_bumped++;
	    next;
	}
	$y_pos = $y_offset - $row * int( $h + $gap * $label_h ) * $strand ;
	
	$feature_colour = "black";
	$block_colour   = "e8ffcc";
	
	my $base_adaptor = $F[0][2]->adaptor();
	
	my $group_items;
	my $same_hit;
	   
	## Begin Setup for Paired reads in the window of interest @F>1 ##
	if ( @F > 1 ) {
	  	    	    
	    ## If highlighted via search then show the hi_colour else jump to orientation check below.
	    if ( (exists $highlights{ lc( $F[0][2]->display_id )}) || 
		 (exists $highlights{ lc( $F[-1][2]->display_id )}) || 
		 (exists $highlights{ lc( $F[1][2]->display_id )}) ){
		$feature_colour = $hi_colour; 
	    }
	    ## Orientation Colour Information ##
	    ##   If the directions point outwards or the same direction make it red ##
	    ##   precedence will be red(orientation) > pink(multiple hits) > orange(incorrect distance) ##
	    elsif ( ( ($F[0][2]->strand eq $F[-1][2]->strand || 
		       $F[0][2]->strand == -1 && $F[-1][2]->strand == 1) )&& 
		    abs($F[-1][0] - $F[0][0] + 1) > 50 ) 
	    {
		$feature_colour = "red";
		$block_colour   = "ffe8cc";
		#$hi_colour      = "ffd280";
	    }
      
	    
	    ## If they're the same hit, distance/oriention doesn't even matter.Purple colour.
	    if ( ($F[0][2]->display_id eq $F[-1][2]->display_id) && ($feature_colour ne $hi_colour) ){
		$feature_colour = "5F04B4";
		$block_colour   = "D8CEF6";
		$same_hit       = 1;
	    }
	    	    
	}

	my @featsInGrp = map {$_->[5]} @F;
	$group_items   = join (", ", @featsInGrp);
	my $distance   = $F[-1][1] - $F[0][0] +1;

	## Composite is the shell of the glyph, where the individual pieces can be built upon it like rect.
	my $Composite = $self->Composite({
	    'href'  => ($group_items) ? $self->href( $F[0][2], $i, $group_items, $distance ) :  $self->href( $F[0][2], $i ),
	    'x'     => $F[0][0]> 1 ? $F[0][0]-1 : 0,
	    'width' => 0,
	    'y'     => 0,
	    'title' => $self->feature_title($F[0][2])
					 });
	my $X = -1e8;

	## Loop through each feature for this ID!
	foreach my $f ( @F ){ 
	    my( $s, $e, $feat ) = @$f;
	    my $feat_strand     = $feat->strand;

	    $features_drawn++;
	    
	    my $START = $s < 1 ? 1 : $s;
	    my $END   = $e > $length ? $length : $e;
	    
	    my (@pair1, @pair2, @pair3);
	    
	    ## Border of the box colours
	    my $border_colour = "black";	    
	    
	    ## Draw triangle either downstream or upstream.
	    if ($feat_strand == 1 ){   
		
		$Composite->push($self->Rect({
		    'x'          => $START-1,
		    'y'          => 0,
		    'width'      => $END-$START+1,
		    'height'     => $h,
		    'colour'     => $feature_colour,
		    'absolutey'  => 1,
		}));
		
		
		# add the arrow to the image.
		$self->push($self->Poly({
		    'points' => [$END                ,0    + $y_pos,
				 $END + $arrow_scale ,$h/2 + $y_pos,
				 $END                ,$h   + $y_pos
				 ],
				     'colour'    => $feature_colour,
				     'absolutey' => 1
				 }));
		
		# do the highlighting ...
		
		# the arrow line
		push @high_lights, $self->Line({
		    'x'         => $END,
		    'y'         => 0 + $y_pos,
		    'width'     => $arrow_scale,
		    'height'    => $h/2,
		    'colour'    => $border_colour,
		    'absolutey' => 1});
		
		push @high_lights,$self->Line({
		    'x'         => $END,
		    'y'         => $h + $y_pos,
		    'width'     => $arrow_scale,
		    'height'    => -$h/2,
		    'colour'    => $border_colour,
		    'absolutey' => 1});
		
		
		# the back end (opposite the arrow)
		push @high_lights,$self->Line({
		    'x'         => $START - 1,
		    'y'         => 0 + $y_pos,
		    'width'     => 0,
		    'height'    => $h,
		    'colour'    => $border_colour,
		    'absolutey' => 1});
	  
		# top line 
		push @high_lights,$self->Line({
		    'x'         => $START - 1,
		    'y'         => 0 + $y_pos,
		    'width'     => $END - $START + 1,
		    'height'    => 0,
		    'colour'    => $border_colour,
		    'absolutey' => 1});
		
		
		# bottom line 
		push @high_lights,$self->Line({
		    'x'         => $START - 1,
		    'y'         => $h + $y_pos,
		    'width'     => $END - $START + 1,
		    'height'    => 0,
		    'colour'    => $border_colour,
		    'absolutey' => 1});
		
		
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
		
		# add the arrow to the image.
		$self->push($self->Poly({
		    'points' => [$START - $arrow_scale - 1, $h/2 + $y_pos,
				 $START                   , 0    + $y_pos,
				 $START                   , $h   + $y_pos
				 ],
				     'colour'    => $feature_colour,
				     'absolutey' => 1
				 }));
		
		# do the highlighting ...
		
		# the arrow line
		push @high_lights, $self->Line({
		    'x'         => $START - $arrow_scale,
		    'y'         => $h/2 + $y_pos,
		    'width'     => $arrow_scale,
		    'height'    => -$h/2,
		    'colour'    => $border_colour,
		    'absolutey' => 1});
		
		
		push @high_lights, $self->Line({
		    'x'         => $START - $arrow_scale,
		    'y'         => $h/2 + $y_pos,
		    'width'     => $arrow_scale,
		    'height'    => $h/2,
		    'colour'    => $border_colour,
		    'absolutey' => 1});
		
		
		
		# the back end (opposite the arrow)
		push @high_lights,$self->Line({
		    'x'         => $END - 1,
		    'y'         => 0 + $y_pos,
		    'width'     => 0,
		    'height'    => $h,
		    'colour'    => $border_colour,
		    'absolutey' => 1});
		
		# top line 
		push @high_lights,$self->Line({
		    'x'         => $START - 1,
		    'y'         => 0 + $y_pos,
		    'width'     => $END - $START + 1,
		    'height'    => 0,
		    'colour'    => $border_colour,
		    'absolutey' => 1});
		
		
		# bottom line 
		push @high_lights,$self->Line({
		    'x'         => $START - 1,
		    'y'         => $h + $y_pos,
		    'width'     => $END - $START + 1,
		    'height'    => 0,
		    'colour'    => $border_colour,
		    'absolutey' => 1});
	    }
	    
	    
	    
	}      
	
	if( $h > 1 ) {
	    $Composite->bordercolour($feature_colour);
	    #$Composite->bordercolour("blue");
	}
	
	$Composite->y( $Composite->y + $y_pos);
	$self->push( $Composite );
	
	
	if( $self->{'show_labels'} ) {
	    $self->push( $self->Text({
		'font'      => $fontname,
		'colour'    => $feature_colour,
		'height'    => $fontsize,
		'ptsize'    => $fontsize,
		'text'      => $self->feature_label($F[0][2]),
		'title'     => $self->feature_title($F[0][2]),
		'halign'    => 'left',
		'valign'    => 'center',
		'x'         => $Composite->{'x'},
		'y'         => $Composite->{'y'} + $h + 2,
		'width'     => $Composite->{'x'} + ($bump_end-$bump_start) / $pix_per_bp,
		'height'    => $label_h,
		'absolutey' => 1
		}));
	}
	if( 1 || exists $highlights{$i}) {
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

1;
