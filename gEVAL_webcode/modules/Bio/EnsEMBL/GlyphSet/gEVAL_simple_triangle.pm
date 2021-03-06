package Bio::EnsEMBL::GlyphSet::gEVAL_simple_triangle;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

#----------------------------------------------------------#
# Simple glyph for triangle pointing upwards/downwards.
#  
#   Originally created to represent very short features 
#   (1-500bp)
#
# wc2@sanger 2014
#----------------------------------------------------------#

##==  Creates the label under the glyph if option selected
sub feature_label {
  my( $self, $f, $db_name ) = @_;

  my $set    = @{$f->get_all_MiscSets()}[0]->code() || undef;
  return $f->get_scalar_attribute('name') || $set || $db_name;
}


##== Fetching the features of course!
sub features {
  my ($self) = @_;

  my $db        = $self->my_config('db');
  my $misc_sets = $self->my_config('set');
  my @T         = ($misc_sets);

  my @sorted = map { @{$self->{'container'}->get_all_MiscFeatures( $_, $db )||[]} } @T;

  my %results = ( $self->my_config('name') => [@sorted] );
  return %results;
}


##== Feeds in the data required for Zmenu -> MiscFeature.pm
sub href {
  my ($self, $f_ref ) = @_;

  my @F  = @$f_ref;
  my $db = $self->my_config('db');
  my (@frags);

  my $r     = $F[0][2]->seq_region_name.':'.$F[0][2]->seq_region_start.'-'.$F[-1][2]->seq_region_end;
  my $mfid  = $F[0][2]->dbID;

  my $set    = @{$F[0][2]->get_all_MiscSets()}[0]->code() || undef;
  my $zmenu = {
      'type'          => 'MiscFeature',
      'r'             => $r,
      'mfid'          => $mfid,
      'db'            => $db,
      'set_code'      => $set,
  };

  # -- Generic fetch of all misc_attribs -- #
  my @attribs  = @{$F[0][2]->get_all_Attributes()};

  foreach my $attrib (@attribs){
      my $code     = $attrib->code();
      my $value    = $attrib->value() || "-";      
      $$zmenu{$code} = $value;
  }
 
  return $self->_url($zmenu);

}



##== The main drawing code for normal display.
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
    my $hi_colour = 'highlight1';
            
    if( $self->{'extras'} && $self->{'extras'}{'height'} ) {
	$h = $self->{'extras'}{'height'};
    }
    
    ## -- FETCH FEATURES HERE -- ##
    ## Get array of features and push them into the id hash...
    my %features = $self->features;
    
    ## get details of external_db - currently only retrieved from core since they should be all the same
    my $db     = 'DATABASE_CORE';
    my $extdbs = $self->species_defs->databases->{$db}{'tables'}{'external_db'}{'entries'};
    
    my $y_offset        = 0;    
    my $features_drawn  = 0;
    my $features_bumped = 0;
    my $label_h         = 0;

    my( $fontname, $fontsize );
    ( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
    
    foreach my $feature_key ( keys %features ) {
	$self->_init_bump( undef, $dep );

	my %id               = ();
	$self->{'track_key'} = $feature_key;	
	
	my $count =1;
	foreach my $f ( @{$features{$feature_key}} ) {
	    
	    my $hstrand  = $f->can('hstrand')  ? $f->hstrand : 1;	    
	    my $s        = $f->start;
	    my $e        = $f->end;
	    
	    my $db_name = $f->can('external_db_id') ? $extdbs->{$f->external_db_id}{'db_name'} : 'OLIGO';
	    next if $strand_flag eq 'b' && $strand != ( ($hstrand||1)*$f->strand || -1 ) || $e < 1 || $s > $length ;

	    push @{$id{$count}}, [$s,$e,$f,int($s*$pix_per_bp),int($e*$pix_per_bp),$db_name];
	    $count++;
	}


        ## Now go through each feature in turn, drawing them
	my $y_pos;
	my $colour_key     = $self->colour_key( $feature_key );
	my $feature_colour = $self->my_colour( $self->my_config( 'sub_type' ), undef  );
	my $join_colour    = $self->my_colour( $self->my_config( 'sub_type' ), 'join' );

	next unless keys %id;
	
	foreach my $i ( sort { @{  $id{$b}} cmp @{$id{$a}}          ||  
				   $id{$a}[0][3] <=> $id{$b}[0][3]  ||  
				   $id{$b}[-1][4] <=> $id{$a}[-1][4]} keys %id) {
	    
	    my @F                    = @{$id{$i}}; 
	    
	    # Get all attributes for the misc_feature;
	    my $feat                 = $F[0][2];	    	    
	    my $START                = $F[0][0] < 1 ? 1 : $F[0][0];
	    my $END                  = $F[-1][1] > $length ? $length : ($F[-1][1]);
	    	    
	    my $db_name    = $F[0][5];
	    my( $txt, $bit, $w, $th );
	    my $bump_start = int($START * $pix_per_bp) - 1;
	    my $bump_end   = int(($END) * $pix_per_bp);
	    
	    my @high_lights;
	    
	    if( $self->{'show_labels'} ) {
		my $title                 = $self->feature_label( $feat,$db_name );
		my( $txt, $bit, $tw,$th ) = $self->get_text_width( 0, $title, '', 'ptsize' => $fontsize, 'font' => $fontname );
		my $text_end = $bump_start + $tw + 1;
		$bump_end    = $text_end if $text_end > $bump_end;
	    }
	    my $row        = $self->bump_row( $bump_start, $bump_end );
	    if( $row > $dep ) {
		$features_bumped++;
		next;
	    }
	    $y_pos = $y_offset - $row * int( $h+12 + $gap * $label_h ) * $strand;
	    	
	    my $feat_strand = $feat->strand;		
	    $features_drawn++;
		
	    $hi_colour        = "ffd280";
	    my $text_colour   = "black";
	    $feature_colour   = "8904B1";
	    my $border_colour = "gray";

	    # If strand == 1, then the feature will be above the path track, 
	    #  so should point down.  If negative the opposite
	    my $scaled_tri_width       = $length * 0.022;
	    my $scaled_tri_height      = 10;
	    
	    my $pt_textwidth = [$self->get_text_width( 0, "X", '', 'font' => $fontname, 'ptsize' => $fontsize* 0.9 )]->[2] / $pix_per_bp;	    
	    
	    my $center_pt  = $F[0][0];
	    my $quarter_pt = ($scaled_tri_width)/2;

	    if ($length <= 1000){
		$quarter_pt = $scaled_tri_width *(1.2);
		$h += 5;
	    }

	    if ($feat_strand == 1 ){   	
		$self->unshift($self->Poly({
		    'href'         => $self->href( \@F ),
		    'points'       => [ $center_pt, $y_pos+$h+$scaled_tri_height,
					$center_pt - ($quarter_pt), $y_pos +$h ,
					$center_pt + ($quarter_pt), $y_pos +$h],
		    'colour'       => $feature_colour,
		    'bordercolour' => $border_colour,
		}) );
		
	    }
	    # if the strand is negative, point the arrow up as the track by default will be below.
	    else {
		
		$self->unshift($self->Poly({
		    'href'         => $self->href( \@F ),
		    'points'       => [ $center_pt, $y_pos-$h-$scaled_tri_height,
					$center_pt - ($quarter_pt), $y_pos -$h ,
					$center_pt + ($quarter_pt), $y_pos -$h],
		    'colour'       => $feature_colour,
		    'bordercolour' => $border_colour,
		}) );
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
