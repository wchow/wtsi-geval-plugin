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

#------------------------------------#
# gEVAL_marker
#  -marker glyphs with gEVAL colours
#
#   wc2@sanger.ac.uk
#------------------------------------#

package Bio::EnsEMBL::GlyphSet::gEVAL_marker;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  
  return unless $self->strand == -1;
  return $self->render_text if $self->{'text_export'};
  
  $self->_init_bump;
  
  my $slice  = $self->{'container'};
  my $length = $slice->length;
  
  if ($length > 5e7) {
    $self->errorTrack('Markers only displayed for less than 50Mb.');
    return;
  }
  
  my $pix_per_bp     = $self->scalex;
  my %font_params    = $self->get_font_details('outertext', 1);
  my $text_height    = [$self->get_text_width(0, 'X', '', %font_params)]->[3];
  my $labels         = $self->my_config('labels') ne 'off' && $length < 1e7;
  my $row_height     = 8;
  my $previous_start = $length + 1e10;
  my $previous_end   = -1e10;
  my $previous_id    = '';

  # wc2 03.2014 added to split the markers up. GAPMap/SATMap etc...
  my $logic_name  = $self->my_config('logic_name') || undef;

  my $features    = $self->features($logic_name);
  
  foreach my $f (@$features) {
    my $id = $f->{'drawing_id'};

    ## Remove duplicates
    next if $id == $previous_id && $f->start == $previous_start && $f->end == $previous_end;

    #-----PGP Specific Information/Colours-----#
    my $ms   = $f->marker->display_MarkerSynonym;
    my $fid  = $ms ? $ms->name : '';
      ($fid) = grep { $_ ne '-' } map { $_->name } @{$f->marker->get_all_MarkerSynonyms||[]} if $fid eq '-' || $fid eq '';

    my @map_loc = @{$f->marker->get_all_MapLocations};
    my ($chr, $pos, @map_list);
    foreach my $marker (@map_loc){
	my $c = $marker->chromosome_name;
	if (($c ne $chr) && ($chr ne "")){
	    $chr=""; 
	    $pos="";
	    last;
	}
	$chr     = $c;
	$pos     = $marker->position();
	my $info = $marker->map_name."-chr:".$marker->chromosome_name;
	push (@map_list, $info);
    }
    my $map_info = join (",", @map_list);

    my $feature_colour = $self->marker_loc_based_colour($f, $chr, $f->seq_region_name);    

    my $start          = $f->start - 1;
    my $end            = $f->end;
    
    next if $start > $length || $end < 0;
    
    $start = 0       if $start < 0;
    $end   = $length if $end > $length;

    ## Draw feature
    unless ($slice->strand < 0 ? $previous_start - $start < 0.5 / $pix_per_bp : $end - $previous_end < 0.5 / $pix_per_bp) {
      $self->push($self->Rect({
        x         => $start,
        y         => 0,
        height    => $row_height, 
        width     => $end - $start,
        colour    => $feature_colour, 
        absolutey => 1,
        href      => $self->href($f)
      }));
      
      $previous_end   = $end;
      $previous_start = $end;
    }
    
    $previous_id = $id;
    
    next unless $labels;
    
    my $text_width = [$self->get_text_width(0, $id, '', %font_params)]->[2];

    my $displayname = $fid;
    # wc2 052012 Option for Detailed labels for markers. The option created is in contigviewbottom (detailed_labels).
    if ( ($self->{'display'} =~ /label/)  ){

	# wc2 Satmap markers are way too long.
	$displayname = "SATMAP" if ($fid =~ /DHABG/);

	$displayname .= "($chr)" if ($chr);
	$displayname .= "[$pos]" if ($pos);
    }
    else {	
	$displayname .= "(chr:$chr)" if ($chr);
    }
   
    my $glyph = $self->Text({
      x         => $start,
      y         => $row_height,
      height    => $text_height,
      width     => $text_width / $pix_per_bp,
      halign    => 'left',
      colour    => $feature_colour,
      absolutey => 1,
      text      => $displayname,
      href      => $self->href($f),
      %font_params
    });

    my $bump_start = int($glyph->x * $pix_per_bp);
       $bump_start = 0 if $bump_start < 0;
    my $bump_end   = $bump_start + $text_width;
    my $row        = $self->bump_row($bump_start, $bump_end, 1);
    
    next if $row < 0; # don't display if falls off RHS
    
    $glyph->y($glyph->y + (1.2 * $row * $text_height));
    $self->push($glyph);
  }
  
  ## No features show "empty track line" if option set
  $self->errorTrack('No markers in this region') if !scalar @$features && $self->{'config'}->get_option('opt_empty_tracks') == 1;
}


sub features {
  # wc2: added logic_name option to fetch only features of a particular logic_name.  
  my ($self, $logic_name) = @_;
  my $slice = $self->{'container'};
  my @features;

  # wc2: if the logicname doesn't have marker, then just return all by default via undef.
  if ($logic_name !~ /marker/){
      $logic_name = undef;
  }

  if ($self->{'text_export'}) {
    @features = @{$slice->get_all_MarkerFeatures};
  } else {
    my $priority   = $self->my_config('priority');
    my $marker_id  = $self->my_config('marker_id');
    my $map_weight = 2;
    @features   = (@{$slice->get_all_MarkerFeatures($logic_name, $priority, $map_weight)});
    push @features, @{$slice->get_MarkerFeatures_by_Name($marker_id)} if ($marker_id and !grep {$_->display_id eq $marker_id} @features); ## Force drawing of specific marker regardless of weight (but only if not already being drawn!)
  }
  
  foreach my $f (@features) {
    my $ms  = $f->marker->display_MarkerSynonym;
    my $id  = $ms ? $ms->name : '';
      ($id) = grep $_ ne '-', map $_->name, @{$f->marker->get_all_MarkerSynonyms || []} if $id eq '-' || $id eq '';
    
    $f->{'drawing_id'} = $id;
  }
  
  return [ sort { $a->seq_region_start <=> $b->seq_region_start } @features ];
}

sub render_text {
  my $self = shift;

  return unless $self->strand == -1;

  my $export;
  
  foreach my $f (sort { $a->seq_region_start <=> $b->seq_region_start } @{$self->{'container'}->get_all_MarkerFeatures}) {
    my $ms  = $f->marker->display_MarkerSynonym;
    my $fid = $ms ? $ms->name : '';
    
    ($fid) = grep { $_ ne '-' } map { $_->name } @{$f->marker->get_all_MarkerSynonyms||[]} if $fid eq '-' || $fid eq '';    
    
    $export .= $self->_render_text($f, 'Marker', { 'headers' => [ 'id' ], 'values' => [ $fid ] });
  }
  
  return $export;
}


#
# wc2 :: 0910
# mapweight_based_colour :: colour code for number of times markers mapped. 

sub mapweight_based_colour {
    my( $self, $feature ) = @_;
    
    my $weight = $feature->map_weight;
    if    ($weight > 4){return "red";}
    elsif ($weight eq 1) {return "green";}
    else  {return "orange";}

}


#
# wc2 :: 0910
# marker_loc_based_colour :: colour code to reflect marker mapping location and marker location.

sub marker_loc_based_colour {

    my ( $self, $feature, $chr, $seq_region_name ) = @_;

    if ($chr eq $seq_region_name){
	return $self->my_colour( $feature->marker->type );
    }
    elsif (!$chr){
	return "gray";
    }
    else {
	return "blue";
    }

}


sub colour_key {

    my ($self, $feature) = @_;

    my @map_loc = @{$feature->marker->get_all_MapLocations};
    my $chr="";
    my $pos="";
    foreach my $marker (@map_loc){
	my $c = $marker->chromosome_name;
	if (($c ne $chr) && ($chr ne "")){
	    $chr=""; 
	    last;
	}
	$chr =$c;
    }

    my $colour = $self->marker_loc_based_colour($feature, $chr, $feature->seq_region_name); 

    return ($colour);
}


sub feature_label {
  my ($self, $f) = @_;
  my $ms   = $f->marker->display_MarkerSynonym;
  my $fid  = $ms ? $ms->name : '';
  
  return $fid;
}


sub href {
  my ($self, $f, $map_info) = @_;
  
  return $self->_url({
      'species' => $self->species,
      'type'    => 'Marker',
      'm'       => $f->{'drawing_id'},
      'maps'    => $map_info || '',
  });

}

1;
