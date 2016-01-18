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


package Bio::EnsEMBL::GlyphSet::chr_band;

use strict;
use warnings;
no warnings 'uninitialized';
use base qw(Bio::EnsEMBL::GlyphSet);

sub label_overlay   { return 1; }
sub default_colours { return $_[0]{'default_colours'} ||= [ 'gpos25', 'gpos75' ]; }

sub colour_key {
  my ($self, $f) = @_;
  my $key = $self->{'colour_key'}{$f} || $f->stain;
  
  if (!$key) {
    $self->{'colour_key'}{$f} = $key = shift @{$self->default_colours};
    push @{$self->default_colours}, $key;
  }
  
  return $key;
}

sub _init {
  my $self = shift;

  return $self->render_text if $self->{'text_export'};
  
  ########## only draw contigs once - on one strand
  
  my ($fontname, $fontsize) = $self->get_font_details('innertext');
  my $bands      = $self->features;
  my $h          = [ $self->get_text_width(0, 'X', '', font => $fontname, ptsize => $fontsize) ]->[3];
  my $pix_per_bp = $self->scalex;
  my @t_colour   = qw(gpos25 gpos75);
  my $length     = $self->{'container'}->length;
  
  foreach my $band (@$bands) {
    my $label      = $self->feature_label($band);
    my $colour_key = $self->colour_key($band);
    my $start      = $band->start;
    my $end        = $band->end;
       $start      = 1       if $start < 1;
       $end        = $length if $end   > $length;

    $self->push($self->Rect({
      x            => $start - 1 ,
      y            => 0,
      width        => $end - $start + 1 ,
      height       => $h + 4,
      colour       => $self->my_colour($colour_key) || 'white',
      absolutey    => 1,
      title        => $label ? "Band: $label" : '',
      href         => $self->href($band, $label),  # added label to the call wc2
      bordercolour => 'black'
    }));
    
    if ($label) {
      my @res = $self->get_text_width(($end - $start + 1) * $pix_per_bp, $label, '', font => $fontname, ptsize => $fontsize);
      
      # only add the lable if the box is big enough to hold it
      if ($res[0]) {
        $self->push($self->Text({
          x         => ($end + $start - 1 - $res[2]/$pix_per_bp) / 2,
          y         => 1,
          width     => $res[2] / $pix_per_bp,
          textwidth => $res[2],
          font      => $fontname,
          height    => $h,
          ptsize    => $fontsize,
          colour    => 'black',  # straight up black wc2
          text      => $res[0],
          absolutey => 1,
        }));
      }
    }
  }
  
  $self->no_features unless scalar @$bands;
}

sub render_text {
  my $self = shift;
  my $export;
  
  foreach (@{$self->features}) {
    $export .= $self->_render_text($_, 'Chromosome band', { 
      headers => [ 'name' ], 
      values  => [ $_->name ] 
    });
  }
  
  return $export;
}

sub features {
  my $self = shift;
  foreach my $i (sort {$a->dbID <=> $b->dbID} @{$self->{'container'}->get_all_KaryotypeBands}){ 

  }	
  return [ sort { $a->start <=> $b->start } @{$self->{'container'}->get_all_KaryotypeBands || []} ];
}

sub href {
  my ($self, $band, $label) = @_;
  my $slice = $band->project('toplevel')->[0]->to_Slice;
  return $self->_url({ r     => sprintf('%s:%s-%s', map $slice->$_, qw(seq_region_name start end)),
		       label =>	$label || '',
   	             });
}

sub feature_label {
  my ($self, $f) = @_;
  return $f->name; # edited by wc2 to show all band names.

 # return $self->my_colour($self->colour_key($f), 'label') eq 'invisible' ? '' : $f->name;
}

1;
