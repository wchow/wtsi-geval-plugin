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

package Bio::EnsEMBL::GlyphSet::gEVAL_ends_link;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

#--------------------------------#
#--------------------------------#
# Glyph for clone ends that      #
# uses the external_data column  #
# to store pair information.     #
#                                #
#   -wc2@sanger                  # 
#--------------------------------#
#--------------------------------#


#-------------------------------------#
# Lib Insert Sizes
#  -should ideally be called
#   another module (eg LibrarySize.pm)
#-------------------------------------#
sub size_range {
  my ( $logic_name, $db_adaptor) = @_;

  ## Default size.
  my ($min_dist, $max_dist) = ();

  # Read analysis_description to see if lib has calc insert sizes.
  my $aa            = $db_adaptor->get_AnalysisAdaptor;
  my $analysis_feat = $aa->fetch_by_logic_name($logic_name);
  my $ins_size_ref  = eval{$analysis_feat->web_data};

  if ($ins_size_ref && (ref $ins_size_ref eq ref{}) ){
        my $avg_size = $ins_size_ref->{avg_ins};
        my $std_dev  = $ins_size_ref->{std_dev};
	my $min      = $ins_size_ref->{min};
	my $max      = $ins_size_ref->{max};

	## Main attribute stored in analysis_description
	if ($min && $max){
	    return ($min, $max);
	}
	
	## Not used as much, but located in analysis description as well.
        if ($avg_size && $std_dev){
            $min_dist  = $avg_size - (3*$std_dev);
            $max_dist  = $avg_size + (3*$std_dev);
	    return ( $min_dist, $max_dist );
        }
	goto DEFAULT if (!$min_dist && !$max_dist)
    }

 DEFAULT:
  if (!$min_dist && !$max_dist && ($logic_name =~ /bacend/i)){
      $min_dist = 90000;
      $max_dist = 300000;
  }
  elsif (!$min_dist && !$max_dist && ($logic_name =~ /fosend/i)){
      $min_dist = 35000;
      $max_dist = 45000;
  }
  else {
      $min_dist = 30000;
      $max_dist = 300000; 
  }
      
  return ( $min_dist, $max_dist );
  
}

#-------------------------------------#
# feature_group
#  This is to extract cmp name from
#  read.  ( eg. paired ends)
#-------------------------------------#
sub feature_group {
  my( $self, $f ) = @_;

  #example DKEYP-120G4.487526377
  (my $name = $f->hseqname) =~ s/\..*//;
  
  return $name;    ## For core features this is what the sequence name is...
}

#-------------------------------------#
# feature_label
#  As the name says.
#-------------------------------------#
sub feature_label {
  my( $self, $f, $db_name ) = @_;
  return $f->hseqname;
}

#-------------------------------------#
# feature_title
#  Alt to the name, usually returned
#  when things don't go right.
#-------------------------------------#
sub feature_title {
  my( $self, $f, $db_name ) = @_;
  $db_name ||= 'External Feature (tm)';
  return "$db_name ".$f->hseqname;
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
#  Ends.pm.  Previously Genome.pm
#  Additional data may not be needed
#  but helps in compara view (species).
#-------------------------------------#
sub href {
  my( $self, $f, $group_id, $grpitems, $span, $totalcounts, $fpccheck ) = @_;

  my ($start, $end) = ($f->seq_region_start, $f->seq_region_end);  
  my $r = $self->{'container'}->seq_region_name.":".$self->{'container'}->start ."-". $self->{'container'}->end;

  # This applies to the reads taken from Trace Archive
  my $extra_data = $f->extra_data;
  my $attribs    = $f->get_all_Attributes();
  my %attrib_hash;
  foreach my $attrib ( @{$attribs} ) {
    $attrib_hash{ $attrib->code } = $attrib;
  }

  my ($prevfeat, $nextfeat);
  $prevfeat  =  $attrib_hash{ "prev_feature" }->value() if ($attrib_hash{ "prev_feature" });
  $nextfeat  =  $attrib_hash{ "next_feature" }->value() if ($attrib_hash{ "next_feature" });

  return $self->_url({
    'type'       => 'Location',  
    'action'     => 'Ends',
    'ftype'      => $self->my_config('object_type') || 'DnaAlignFeature',
    'logic_name' => @{ $self->my_config( 'logicnames' )||[] }[0], 
    #'r'          => $r,
    'id'         => ($group_id) ? $group_id : $f->display_id,
    'dbid'       => $f->dbID,       # This is likely discontinued, as no need to fetch feature in Ends.pm
    'db'         => $self->my_config('db'),
    'extra_data' => $extra_data,    # In read sense, this returns the mate pair information (external_data column)
    's1'         => $self->species, # Really used to define which specie in Compara view.
    'perc_id'    => $f->percent_id || undef,
    'hlength'    => $end - $start + 1,
    'grpitems'   => $grpitems,      # if a paired end, will return the names of entries
    'span'       => $span,          # Returns if a spanner/related or not and region
    'totalcounts'=> $totalcounts, 
    'fpccheck'   => $fpccheck, 
    'prevfeat'   => $prevfeat,
    'nextfeat'   => $nextfeat,

  });
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
  my $length = $self->{'container'}->length();

  ## And now about the drawing configura#	    @region_features = undef;

  my $pix_per_bp     = $self->scalex;
  my $DRAW_CIGAR     = ( $self->my_config('force_cigar') && $self->my_config('force_cigar') eq 'yes' )|| ($pix_per_bp > 0.2) ;

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
	    next if ( $strand_flag eq 'b' && 
		      $strand != ( ($hstrand||1)*$f->strand || -1 ) 
		      || $e < 1 || $s > $length );

	    push @{$id{$fgroup_name}}, [$s,$e,$f,int($s*$pix_per_bp),int($e*$pix_per_bp),$db_name];
	}
    }

    ## Now go through each feature in turn, drawing them ##
    my $y_pos;
    my $feature_colour = "green3";
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
	my $db_name    = $F[0][5];
	my( $txt, $bit, $w, $th );
	my $bump_start = int($START * $pix_per_bp) - 1;
	my $bump_end   = int(($END) * $pix_per_bp);
	
	my @high_lights;	
	
	if( $self->{'show_labels'} ) {
	    my $title = $self->feature_label( $F[0][2],$db_name );
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

	#print STDERR "Bumping time :: " . tv_interval( $s_time ) . "\n";

	if( $row > $dep ) {
	    $features_bumped++;
	    next;
	}
	$y_pos = $y_offset - $row * int( $h + $gap * $label_h ) * $strand ;
	
	$feature_colour = "green3";
	$block_colour   = "e8ffcc";
	
	## Count hits for processing later :: wc2
	my $base_adaptor = $F[0][2]->adaptor();
	
	my @feats      = @{$base_adaptor->fetch_all_by_hit_name($F[0][2]->hseqname)};
	my $feat_count = @feats;
	
	my $sgl_totalcounts;
	my $group_id;
	my $group_items;
	my $same_hit;
	   
	## Begin Setup for Paired reads in the window of interest @F>1 ##
	if ( @F > 1 ) {
	  	    
	    my ( $min_dist, $max_dist) = size_range( $logic_name, $base_adaptor->db );
	    
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
	    elsif (abs($F[-1][0] - $F[0][0] + 1) < $min_dist ||
		   abs($F[-1][0] - $F[0][0] + 1) > $max_dist) {		
		$feature_colour = "orange";
		$block_colour   = "ffd280";
	    }	       
	    
	    ## If they're the same hit, distance/oriention doesn't even matter.Purple colour.
	    if ( ($F[0][2]->display_id eq $F[-1][2]->display_id) && ($feature_colour ne $hi_colour) ){
		$feature_colour = "5F04B4";
		$block_colour   = "D8CEF6";
		$same_hit       = 1;
	    }

	    $group_id =  $F[0][2]->display_id();
	    $group_id    =~ s/\..*\Z//;
	    $group_id   .=  "  distance: " . (abs($F[-1][0] - $F[0][0] + 1));
	   
	    ## This was overiding the hseqname and causing paired ends to have distance in the name wc2 0712.	
	    ## $F[0][2]->hseqname( $display_id );
	    

	    ## grp_pairs was created to store the pair names(featcount) for feeding back to the zmenu.
	    ## &-delimited.
	    my @grp_pairs;
	    foreach my $item (sort { $a->[1] <=> $b->[1] } @F){
		my $grp_feature     = $item->[2];
		my $grp_feat_region = $grp_feature->seq_region_name.":".
		    $grp_feature->seq_region_start."-".
		    $grp_feature->seq_region_end;

		my $total_featcount = @{$base_adaptor->fetch_all_by_hit_name($grp_feature->hseqname)};

		my $entry = $grp_feature->hseqname."($total_featcount)[$grp_feat_region]";
		push @grp_pairs, $entry;
	    }
	    $group_items = join ("&", @grp_pairs);
	    	    
	}
	else {

	    my $hitseqname = $F[0][2]->hseqname;
	    my $total_featcount = @feats; #@{ $base_adaptor->fetch_all_by_hit_name($hitseqname) };
	    
	    if ( $logic_name && ($logic_name =~ /norep/) ){
		$sgl_totalcounts   =  @{$base_adaptor->fetch_all_by_hit_name($hitseqname, $logic_name)}." (norep) / ". $total_featcount ." (all)";
	    }
	    else {
		$sgl_totalcounts   = $total_featcount." (all)";
	    }
	}

	## span_attrib added to feed the spanner attribute to the zmenu.
	my $attribs = $F[0][2]->get_all_Attributes();
	
	my %attrib_hash;
	foreach my $attrib ( @{$attribs} ) {
	    $attrib_hash{ $attrib->code } = $attrib;
	}
	
	my $span_attrib;
	if (@F == 1 || $F[0][2]->strand eq $F[-1][2]->strand) {

	    if ($attrib_hash{ "spanner" } ){
		$outline = 1;
		$span_attrib = "span:".$attrib_hash{"spanner"}->value();
	    }
	    elsif ($attrib_hash{ "gap_spanner" }) {
		$outline = 1;
		$span_attrib = "gapspan:".$attrib_hash{"gap_spanner"}->value();		
	    }
	    	    
	}
	
	## End(s) will be blue if FPC is not consistent.
	##  This has been somewhat discontinued as fpc-marker information is out-dated.
	##  Keeping for legacy purpose.
	my $fpc_check;
	if ($attrib_hash{"fpc_check"}){
	    $feature_colour = "blue";
	    $block_colour   = "afc7ff";
	    $fpc_check      = $attrib_hash{"fpc_asc"}->value(); 
	}

	## Mainly as a check especially for compara to highlight or not.
	my $search_hit = $self->{'config'}->hub->param('h');
	my $hseqname   = $F[0][2]->hseqname();
	if ($search_hit && $search_hit =~ /$hseqname/){
	    $feature_colour = $hi_colour;
	}
	
	## Composite is the shell of the glyph, where the individual pieces can be built upon it like rect.
	my $Composite = $self->Composite({
	    'href'  => ($group_id) ?
		$self->href( $F[0][2], $group_id, $group_items, undef, undef, $fpc_check ) :  
		$self->href( $F[0][2], undef    , undef       , $span_attrib, $sgl_totalcounts, $fpc_check),
		'x'     => $F[0][0]> 1 ? $F[0][0]-1 : 0,
		'width' => 0,
		'y'     => 0,
		'title' => $self->feature_title($F[0][2],$db_name)
	    });
	my $X = -1e8;

	
	## Loop through each feature for this ID!
	foreach my $f ( @F ){ 
	    my( $s, $e, $feat ) = @$f;
	    my $feat_strand     = $feat->strand;
	    
	    ## if there are more than two hits, salmon colour unless its a paired and wrong orientation.
	    if ($feat_count > 2 ){
		$feature_colour = "salmon" if ( $feature_colour ne "red" && $feature_colour ne $hi_colour && !$same_hit);
	    }
	    $features_drawn++;
	    
	    my $START = $s < 1 ? 1 : $s;
	    my $END   = $e > $length ? $length : $e;
#	$X = $END;
	    
	    my (@pair1, @pair2, @pair3);
	    
	    ## Border of the box colours
	    my $border_colour = "black";	    
	    if ($attrib_hash{"gap_hanger"}){
		$border_colour = "red";
		
	    }
	    
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
	}
	
	$Composite->y( $Composite->y + $y_pos);
	$self->push( $Composite );
	
	if ( $outline || ($attrib_hash{"gap_hanger"})){
	    foreach my $high_light (@high_lights) {
		$self->push($high_light);
	    }
	    
#	print STDERR "==================  Doing the outline...\n";
	    $outline = 0;
	    
	}      
	
	
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
  $self->errorTrack( qq(No features from '".$self->my_config(name)."' in this region) )
      unless( $features_drawn || !($self->get_parameter( 'opt_empty_tracks')) );
  
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
