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


package Bio::EnsEMBL::GlyphSet::gEVAL_cdna;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

#--------------------------------#
#--------------------------------#
# Glyph for cdnas                #
#                                #
#   -wc2@sanger                  # 
#--------------------------------#
#--------------------------------#

#-------------------------------------#
# feature_group
#  Inherited from clone_ends, this will 
#   be used to avoid duplicate hits.
#  
#-------------------------------------#
sub feature_group {
  my( $self, $f ) = @_;  

  my $extra_data = $f->extra_data;  
  my $groupname  = $f->hseqname;
  $groupname    .= "-$extra_data" if ($extra_data);

  return $groupname;   
}

#-------------------------------------#
# feature_label
#  As the name says.
#-------------------------------------#
sub feature_label {
  my( $self, $f) = @_;

  ## With some cdnas having gene name, this may be a good placeholder
  ##  for parsing out the genename from the feature name, and using
  ##  that as the feature label.

  return $f->hseqname;
}

#-------------------------------------#
# feature_title
#  Alt to the name, usually returned
#  when things don't go right.
#-------------------------------------#
sub feature_title {
  my( $self, $f ) = @_;
  return "gEVAL feature: ".$f->hseqname;
}

#-------------------------------------#
# features
#  Returns all the features of a 
#  specific logic_name in the window
#  of interest.
#-------------------------------------#
sub features {
  my ($self) = @_;

  my $method      = 'get_all_'.( $self->my_config('object_type') || 'DnaAlignFeature' ).'s';
  my $db          = $self->my_config('db');
  my @logic_names = @{ $self->my_config( 'logicnames' )||[] };

  $self->timer_push( 'Initializing don', undef, 'fetch' );
  my @results = map { $self->{'container'}->$method($_,undef,$db)||() } @logic_names;
  $self->timer_push( 'Retrieved features', undef, 'fetch' );
  my %results = ( $self->my_config('name') => [@results] );

  return %results;
}


#-------------------------------------#
# href
#  This is used to return the neccesary
#  data to the Zmenu.
#  It now points to its specific Zmenu
#  cdna.pm.  Previously Genome.pm
#  Additional data may not be needed
#  but helps in compara view (species).
#-------------------------------------#
sub href {
  my( $self, $f ) = @_;

  my $display_id = $f->display_id;
  $display_id =~ s/\+/%2B/g; # <--Helminth reads have + and must be replaced.
  my $dbid = $f->dbID || undef;
  
  return $self->_url({
      'type'          => 'Location',
      'action'        => 'CDNA',
      'ftype'         => $self->my_config('object_type') || 'DnaAlignFeature',
      'logic_name'    => @{ $self->my_config( 'logicnames' )||[] }[0], 
      'r'             => $self->{'config'}->core_objects->{'location'}->param('r'),
      'id'            => $display_id,
      'db'            => $self->my_config('db'),
      'cov'           => $f->hcoverage,
      'perc'          => $f->percent_id,
      'extra'         => $f->extra_data,
      'species'       => $self->species(),
      'dbid'          => $dbid,
  });
}


#----------------------------------------#
# colour_key
#  Default call for colouring of features
#  Not necessarily used extensively
#----------------------------------------#
sub colour_key {
  my( $self, $feature_key ) = @_;
  return $self->my_config( 'sub_type' );
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
    
    return $self->render_text if $self->{'text_export'};
    
    my $tfh    = $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'});
    my $h      = @_ ? shift : ($self->my_config('height') || 8);
    my $dep    = @_ ? shift : ($self->my_config('dep'   ) || 6);
    my $gap    = $h<2 ? 1 : 2;   

    ## Information about the container...
    my $strand         = $self->strand;
    my $strand_flag    = $self->my_config('strand');    
    my $length         = $self->{'container'}->length();

    ## And now about the drawing configuration
    my $pix_per_bp     = $self->scalex;
    my $DRAW_CIGAR     = ( $self->my_config('force_cigar') eq 'yes' )|| ($pix_per_bp > 0.2) ;
    ## Highlights...
    my %highlights = map { $_,1 } $self->highlights;
    my $hi_colour  = 'highlight1';
            
    if( $self->{'extras'} && $self->{'extras'}{'height'} ) {
	$h = $self->{'extras'}{'height'};
    }
    
    
    ## Fetch features using the features call from above.
    my %features = $self->features;
    
    #get details of external_db - currently only retrieved from core since they should be all the same
    my $db     = 'DATABASE_CORE';
    my $extdbs = $self->species_defs->databases->{$db}{'tables'}{'external_db'}{'entries'};
    
    my $y_offset = 0;
    
    my $features_drawn  = 0;
    my $features_bumped = 0;
    my $label_h = 0;
    my( $fontname, $fontsize ) ;
    if( $self->{'show_labels'} ) {
	( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
	my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, 'X', '', 'ptsize' => $fontsize, 'font' => $fontname );
	$label_h = $th;
    }
    
    foreach my $feature_key ( $strand < 0 ? sort keys %features : reverse sort keys %features ) {
	$self->_init_bump( undef, $dep );
	my %id             = ();
	$self->{'track_key'} = $feature_key;
		
	foreach my $features ( @{$features{$feature_key}} ) {
	    foreach my $f (
			   map { $_->[2] }
			   sort{ $a->[0] <=> $b->[0] }
			   map { [$_->start,$_->end, $_ ] }
			   @{$features || []}
			   ){
		my $hstrand  = $f->can('hstrand')  ? $f->hstrand : 1;
		my $fgroup_name = $self->feature_group( $f );
		my $s =$f->start;
		my $e =$f->end;
		
		
		my $db_name = $f->can('external_db_id') ? $extdbs->{$f->external_db_id}{'db_name'} : 'OLIGO';
		next if $strand_flag eq 'b' && $strand != ( ($hstrand||1)*$f->strand || -1 ) || $e < 1 || $s > $length ;
		push @{$id{$fgroup_name}}, [$s,$e,$f,int($s*$pix_per_bp),int($e*$pix_per_bp),$db_name];
	    }
	}

	## Now go through each feature in turn, drawing them
	my $y_pos;
	my $colour_key     = $self->colour_key( $feature_key );
	my $feature_colour = $self->my_colour( $self->my_config( 'sub_type' ), undef  );
	my $join_colour    = $self->my_colour( $self->my_config( 'sub_type' ), 'join' );	
	
	
	next unless keys %id;
	
	foreach my $i ( sort {
	    @{$id{$b}} cmp @{$id{$a}}    || 
		$id{$a}[0][3] <=> $id{$b}[0][3]  ||
		$id{$b}[-1][4] <=> $id{$a}[-1][4]
	    } keys %id) {
	    my @F          = @{$id{$i}}; # sort { $a->[0] <=> $b->[0] } @{$id{$i}};
	    my $START      = $F[0][0] < 1 ? 1 : $F[0][0];
	    my $END        = $F[-1][1] > $length ? $length : $F[-1][1];
	    my $db_name    = $F[0][5];

	    my( $txt, $bit, $w, $th );
	    my $bump_start = int($START * $pix_per_bp) - 1;
	    my $bump_end   = int(($END) * $pix_per_bp);
	    
	    my @high_lights;
	    	    
	    if( $self->{'show_labels'} ) {
		my $title = $self->feature_label( $F[0][2] );
		my( $txt, $bit, $tw,$th ) = $self->get_text_width( 0, $title, '', 'ptsize' => $fontsize, 'font' => $fontname );
		my $text_end = $bump_start + $tw + 1;
		$bump_end    = $text_end if $text_end > $bump_end;
	    }

	    my $row        = $self->bump_row( $bump_start, $bump_end );
	    if( $row > $dep ) {
		$features_bumped++;
		next;
	    }
	    $y_pos = $y_offset - $row * int( $h + $gap * $label_h ) * $strand;	    
	    
	    my $comp_x = $F[0][0]> 1 ? $F[0][0]-1 : 0;

	    ## Composite shell base for drawing.
	    my $Composite = $self->Composite({
		'href'  => $self->href( $F[0][2] ),
		'x'     => $F[0][0]> 1 ? $F[0][0]-1 : 0,
		'width' => 0,
		'y'     => 0,
		'title' => $self->feature_title($F[0][2])
		});
	    my $X = -1e8;



	    ## Colouring aspects of the hit, through coverage.
	    ##  Zfish uses the hcoverage, human/mouse uses the attrib tag.
	    ##  See if both can be added, but eventually need to
	    $feature_colour = "orange";
	    $hi_colour = 'ffd280';
	    
	    ## Human and mouse using attribs.
	    my %attrib_hash = map { $_->code  => $_} @{$F[0][2]->get_all_Attributes()};

	    if ( ($F[0][2]->hcoverage) && ($F[0][2]->hcoverage > 98) && ($F[0][2]->percent_id > 98) ){
		$feature_colour = "green3";
		$hi_colour = 'highlight1';
		
	    }
	    elsif ($F[0][2]->hcoverage < 50){
		$feature_colour = "fa5858";
		$hi_colour = 'ffe8cc';

	    }
	    elsif ( $attrib_hash{ "perfect" } ) {
		$feature_colour = "green3";
		$hi_colour = 'highlight1';
		#$hi_colour = 'purple';
	    }
	    elsif ( $attrib_hash{ "imperfect" } ) {
		$feature_colour = "orange";
		$hi_colour = 'ffd280';
		#$hi_colour = 'red';
	    }

	    for (my $j=0; $j < @F; $j++ ) {
		my $f = $F[$j];
		my( $s, $e, $feat ) = @$f;
		next if int($e * $pix_per_bp) <= int( $X * $pix_per_bp );
		my $feat_strand = $feat->strand;

		$features_drawn++;
		
		my $START = $s < 1 ? 1 : $s;
		my $END   = $e > $length ? $length : $e;
		$X = $END;		
		
		## draw triangle either downstream or upstream.
		if ($feat_strand == 1 ){   

		    $Composite->push($self->Rect({
			'x'          => $START-1,
			'y'          => 0,
			'width'      => $END-$START+1,
			'height'     => $h,
			'colour'     => $feature_colour,
			'absolutey'  => 1,
		    }));
		    
		    ## add connecting lines
		    if (@F > 1 && $j < @F - 1 ) {
			
			$Composite->push($self->Line({
			    'x'          => $F[$j][ 1 ],
			    'y'          => $h / 2,
			    'width'      => ($F[$j + 1][ 0 ] - $F[ $j ][ 1 ] + 1)/2,
			    'height'     => -$h/2,
			    'colour'     => $feature_colour,
			    'absolutey'  => 1,
			}));
			
			$Composite->push($self->Line({
			    'x'          => $F[$j][ 1 ] + ($F[$j + 1][ 0 ] - $F[$j][1 ] + 1)/2,
			    'y'          => 0, # $y_pos,
			    'width'      => ($F[$j + 1][ 0 ] - $F[$j][1 ] + 1)/2,
			    'height'     => $h/2,
			    'colour'     => $feature_colour,
			    'absolutey'  => 1,
			}));
		    }
		    
		}
		## Do the same for opp strand.
		elsif ($feat_strand == -1 ){
		    
		    $Composite->push($self->Rect({
			'x'          => $START-1,
			'y'          => 0, # $y_pos,
			'width'      => $END-$START+1,
			'height'     => $h,
			'colour'     => $feature_colour,
			'absolutey'  => 1,
		    }));
		    
		    ## add connecting lines
		    if (@F > 1 && $j < @F - 1 ) {
						
			$Composite->push($self->Line({
			    'x'          => $F[$j][ 1 ],
			    'y'          => $h / 2,
			    'width'      => ($F[$j + 1][ 0 ] - $F[ $j ][ 1 ] + 1)/2,
			    'height'     => -$h/2,
			    'colour'     => $feature_colour,
			    'absolutey'  => 1,
			}));
			
			$Composite->push($self->Line({
			    'x'          => $F[$j][ 1 ] + ($F[$j + 1][ 0 ] - $F[$j][1 ] + 1)/2,
			    'y'          => 0, # $y_pos,
			    'width'      => ($F[$j + 1][ 0 ] - $F[$j][1 ] + 1)/2,
			    'height'     => $h/2,
			    'colour'     => $feature_colour,
			    'absolutey'  => 1,
			}));
		    }
		    
		    
		}
	    }
	    
	    
	    
       	   $Composite->unshift( $self->Rect({
		    'x'         => $Composite->{'x'},
		    'y'         => $Composite->{'y'},
		    'width'     => $Composite->{'width'},
		    'height'    => $h,
		    'colour'    => $join_colour,
		    'absolutey' => 1
	    }));
	    $Composite->y( $Composite->y + $y_pos );
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
		    'colour'    => $hi_colour,
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
