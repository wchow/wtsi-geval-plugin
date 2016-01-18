package Bio::EnsEMBL::GlyphSet::gEVAL_om_gap;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub _das_link {
## Returns the 'group' that a given feature belongs to. Features in the same
## group are linked together via an open rectangle. Can be subclassed.
  my $self = shift;
  return de_camel( $self->my_config('object_type') || 'dna_align_feature' );
}

sub feature_group {
  my( $self, $f ) = @_;
  
  my $ctg_name = $f->get_scalar_attribute('om_ctg_name');
#  warn Dumper $f;
  return $ctg_name;    ## For core features this is what the sequence name is...
}

sub feature_label {
  my( $self, $f, $db_name ) = @_;
  return $f->get_scalar_attribute('frag_length');
}


sub feature_title {
  my( $self, $f, $db_name ) = @_;
  $db_name ||= 'External Feature';
  return "$db_name ".$f->get_scalar_attribute('om_ctg_name');
}

sub features {
  my ($self) = @_;
  my $db = $self->my_config('db');
  my $misc_sets = $self->my_config('set');
  my @T = ($misc_sets);

  my @sorted = map { @{$self->{'container'}->get_all_MiscFeatures( $_, $db )||[]} } @T;

  my %results = ( $self->my_config('name') => [@sorted] );
  return %results;
}




sub href {
### Links to ZMenu/Location.pm
  my ($self, $f_ref ) = @_;

  my @F = @$f_ref;

  my $db = $self->my_config('db');
  my (@frags);

  my $r     = $F[0][2]->seq_region_name.':'.$F[0][2]->seq_region_start.'-'.$F[-1][2]->seq_region_end;
  my $mfid  = $F[0][2]->dbID;

  my $name = $F[0][2]->get_scalar_attribute('om_ctg_name') || "Aiya no name ah!"; 
  for (my $i=0; $i < @F; $i++){
      push ( @frags, $F[$i][2]-> get_scalar_attribute('frag_length') );
  }
  my $fraglist   = join (", ", @frags);
  my $frag_num   = @frags;
  my $zmenu = {
      'type'          => 'Location',
      'action'        => 'View',
      'logic_name'    => 'om_frag',

      'r'             => $r,
      'om_ctg_name'   => $name,
      'fraglist'      => $fraglist,
      'fragnum'       => $frag_num,
      'mfid'          => $mfid,
      'db'            => $db,
  };
  return $self->_url($zmenu);

}

#==============================================================================
# Next we have the _init function which chooses how to render the
# features...
#==============================================================================


sub colour_key {
  my( $self, $feature_key ) = @_;
  return $self->my_config( 'sub_type' );
}

sub render_normal {
    my $self = shift;
    
  return $self->render_text if $self->{'text_export'};
    
    my $tfh    = $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'});
    my $h      = @_ ? shift : ($self->my_config('height') || 8);
    my $dep    = @_ ? shift : ($self->my_config('dep'   ) || 6);
    my $gap    = $h<2 ? 1 : 2;   
## Information about the container...
    my $strand = $self->strand;
    my $strand_flag    = $self->my_config('strand');
    
    my $length = $self->{'container'}->length();
## And now about the drawing configuration
    my $pix_per_bp     = $self->scalex;
    my $DRAW_CIGAR     = ( $self->my_config('force_cigar') eq 'yes' )|| ($pix_per_bp > 0.2) ;
## Highlights...
    my %highlights = map { $_,1 } $self->highlights;
    my $hi_colour = 'highlight1';
    
#  print STDERR "RENDER NORMAL (height: $h, strand: $strand, length: $length, ppb: $pix_per_bp) \n";
    
    
    if( $self->{'extras'} && $self->{'extras'}{'height'} ) {
	$h = $self->{'extras'}{'height'};
    }
    
## Get array of features and push them into the id hash...
    my %features = $self->features;
    
    #get details of external_db - currently only retrieved from core since they should be all the same
    my $db = 'DATABASE_CORE';
    my $extdbs = $self->species_defs->databases->{$db}{'tables'}{'external_db'}{'entries'};
    
    my $y_offset = 0;
    
    my $features_drawn = 0;
    my $features_bumped = 0;
    my $label_h = 0;
    my( $fontname, $fontsize ) ;
    ( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );

    
    foreach my $feature_key ( keys %features ) {
	
	$self->_init_bump( undef, $dep );
	my %id             = ();
	$self->{'track_key'} = $feature_key;
	
	

	my $count =1;
	foreach my $f ( @{$features{$feature_key}} ) {
	    
	    my $hstrand  = $f->can('hstrand')  ? $f->hstrand : 1;
	    #my $fgroup_name = $self->feature_group( $f );
	    
	    my $s =$f->start;
	    my $e =$f->end;
	    
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

	foreach my $i ( sort {
	    @{$id{$b}} cmp @{$id{$a}}    || 
		$id{$a}[0][3] <=> $id{$b}[0][3]  ||
		$id{$b}[-1][4] <=> $id{$a}[-1][4]
	    } keys %id) {
	    my @F          = @{$id{$i}}; 
	    
	    
	
	    # Get all attributes for the misc_feature;
	    my $feat                 = $F[0][2];
	    my $unaligned_total      = $feat->get_scalar_attribute('om_gap_frag_num');
	    my $unaligned_result     = $feat->get_scalar_attribute('om_gap_frag');
	    my $frag_ctg             = $feat->get_scalar_attribute('om_ctg_name');
	    my @frags                = split (",", $unaligned_result);
	    warn "diff numbers of frags\n" if ($unaligned_total != @frags);
	    
	    my $sum_frags = 0;
	    foreach my $item (@frags) {$sum_frags = $sum_frags + $item;}
	    
	    
	    my $START      = $F[0][0] < 1 ? 1 : ($F[0][0] - ($sum_frags/2));
	    my $END        = $F[-1][1] > $length ? $length : ($F[-1][1] + ($sum_frags/2));
	    
	    # Some double checks.  This prevents glyph overextending its boundaries.

	    if ($START < 1){
		$START = 1;
		$END   = $sum_frags;
	    }
	    if ($END > $length){
		$START = $length - $sum_frags;
		$END   = $length;
	    }

	    if ($sum_frags > $length){
		$START = 1;
		$END   = $length;
	    }
	    
	    
	    my $db_name    = $F[0][5];
	    my( $txt, $bit, $w, $th );
	    my $bump_start = int($START * $pix_per_bp) - 1;
	    my $bump_end   = int(($END) * $pix_per_bp);
	    
	    my @high_lights;
	    
	    
	    if( $self->{'show_labels'} ) {
		my $title = $self->feature_label( $F[0][2],$db_name );
		my( $txt, $bit, $tw,$th ) = $self->get_text_width( 0, $title, '', 'ptsize' => $fontsize, 'font' => $fontname );
		my $text_end = $bump_start + $tw + 1;
		$bump_end = $text_end if $text_end > $bump_end;
	    }
	    my $row        = $self->bump_row( $bump_start, $bump_end );
	    if( $row > $dep ) {
		$features_bumped++;
		next;
	    }
	    $y_pos = $y_offset - $row * int( $h+12 + $gap * $label_h ) * $strand;
	    
	
	    my $comp_x = $F[0][0]> 1 ? $F[0][0]-1 : 0;
	    
	    my $Composite = $self->Composite({
		'href'  => $self->href( \@F ),
		'x'     => $F[0][0]> 1 ? $F[0][0]-1 : 0,
		'width' => 0,
		'y'     => 10,
		'title' => $self->feature_title($F[0][2],$db_name)
		});
	    my $X = -1e8;
	    
	    $hi_colour      = "ffd280";
	
	    my $feat_strand = $feat->strand;
	
	
	    $features_drawn++;
	
	
	    my $text_colour = "white";
	    $feature_colour = "CC3333";
	    if ($feat_strand == 1 ){   
		
		my $width                  = $END-$START+1;
		my $feat_start             = $START-1;
		my $scaled_tri_width       = $length * 0.01;
		
		if ( ($sum_frags < 5000) && ($length >= 100000) ){
		    $width           = $scaled_tri_width/2;
		    $feat_start      = $F[0][0]-($width/2);
		}
		

		$Composite->push($self->Rect({
		    'x'          => $feat_start,
		    'y'          => 0,
		    'width'      => $width,
		    'height'     => $h,
		    'colour'     => $feature_colour,
		    'bordercolour' =>"black",
		    'absolutey'  => 1,
		   
		}));
		
		my $pt_textwidth = [$self->get_text_width( 0, "X", '', 'font' => $fontname, 'ptsize' => $fontsize* 0.9 )]->[2] / $pix_per_bp;
		
		
		my $center_pt  = $F[0][0];
		my $quarter_pt = $sum_frags >5000 ? ($END-$START)/18 : ($scaled_tri_width)/2;
		
		$self->unshift($self->Poly({
		    'points' => [ $center_pt, $y_pos+$h+8,
				  $center_pt - ($quarter_pt), $y_pos +$h ,
				  $center_pt + ($quarter_pt), $y_pos +$h],
		    'colour'   => "CC3333",
		    'bordercolour' =>"black",
		}) );
		
		my $i=0;
		my $x_pos       = $START;
		my $prev_x_pos  = $START;

		for ($i; $i<$unaligned_total; $i++){
		    my $frag_size = $frags[$i];
		    $x_pos = $x_pos + ($frag_size*($END-$START))/$sum_frags;
		    
		    $Composite->push($self->Line({
			'x'          => $x_pos,
			'y'          => 0,
			'width'      => 0,
			'height'     => $h,
			'colour'     => "black",
			'absolutey'  => 1,
		    })) if ($unaligned_total > 1);
		    
		
		    # Attempt to add frag size text to each bit.
		    my $tmp_textwidth = [$self->get_text_width( 0, $self->feature_label($feat), '', 'font' => $fontname, 'ptsize' => $fontsize* 0.9 )]->[2] / $pix_per_bp;
		    if (1){
			if ($tmp_textwidth < ($x_pos - $prev_x_pos +1)){
			    
			    $Composite->push($self->Text({
				'font'      => $fontname,
				'colour'    => $text_colour,
				'ptsize'    => $fontsize * 0.9,
				'text'      => $frag_size,
				'halign'    => 'center',
				'valign'    => 'center',
				'textwidth' => $tmp_textwidth*$pix_per_bp,
				'x'         => $prev_x_pos - 1, 
				'y'         => 0,
				'width'     => $x_pos-$prev_x_pos+1,
				'height'    => $h,
				'absolutey' => 1
				}));
			
			    #warn Dumper ($Composite);
			
			}
		    }
		
		    $prev_x_pos = $x_pos;
		}
		

	    }
	
	    $Composite->y( $Composite->y + $y_pos );
	    $self->push( $Composite );
	    
	    
	    if( $self->{'show_labels'} ) {
		$self->push( $self->Text({
		    'font'      => $fontname,
		    'colour'    => $feature_colour,
		    'height'    => $fontsize,
		    'ptsize'    => $fontsize,
		    'text'      => $self->feature_label($F[0][2],$db_name),
		    'title'     => $self->feature_title($F[0][2],$db_name),
		    'halign'    => 'left',
		    'valign'    => 'center',
		    'x'         => $Composite->{'x'},
		    'y'         => $Composite->{'y'} + $h + 2,
		    'width'     => $Composite->{'x'} + ($bump_end-$bump_start) / $pix_per_bp,
		    'height'    => $label_h,
		    'absolutey' => 1
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
