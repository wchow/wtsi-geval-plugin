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

package Bio::EnsEMBL::GlyphSet::gEVAL_repeats;
use strict;
use base qw( Bio::EnsEMBL::GlyphSet_simple );

#-------------------------------#
#				# 
#   Glyph for repeat track in   #
#   PGP.			#
#				#
#    wc2@sanger.ac.uk   	#
#-------------------------------#


#--------------------------------#
# features
#   fetch all repeat features.
#--------------------------------#
sub features {
  my $self = shift;

  my $types      = $self->my_config( 'types'      );
  my $logicnames = $self->my_config( 'logic_names' );

  my @repeats = sort { $a->seq_region_start <=> $b->seq_region_end }
                 map { my $t = $_; map { @{ $self->{'container'}->get_all_RepeatFeatures( $t, $_ ) } } @$types }
                @$logicnames;

  $self->errorTrack(sprintf 'No %s features in this region', $self->my_config('name')) unless scalar @repeats >=1 || $self->{'config'}->get_option('opt_empty_tracks') == 0; 
  return \@repeats;
}

#------------------------------#
# colour_key
#  returns type for base class.
#   don't think its used.
#------------------------------#
sub colour_key {
  my( $self, $f ) = @_;
  return 'repeat';
}

#------------------------------#
# image_label
#  similar to above in that I
#  don't think its used.
#------------------------------#
sub image_label {
  my( $self, $f ) = @_;
  return '', 'invisible';
}


#---------------------------#
# title
#  Returns specific repeat
#  info.
#---------------------------#
sub title {
  my( $self, $f ) = @_;

  my($start,$end) = $self->slice2sr( $f->start(), $f->end() );
  my $len         = $end - $start + 1;
  return sprintf "%s; bp: %s; length: %s; type: %s; class: %s",
    $f->repeat_consensus()->name(),
    "$start-$end",
    $len,
    $f->repeat_consensus()->repeat_type(),  # wc2 ::: 0910
    $f->repeat_consensus()->repeat_class(); # wc2 ::: 0910
}


#---------------------------------#
# Colour schema for marker types
# wc2 :: 0910
#---------------------------------#
sub get_colours {
  my( $self, $f ) = @_;

  my %type_colours = (
		      "acrocentromeric repeat" => "coral",
		      "centromeric repeat"     => "cyan4",
		      "telomeric repeat"       => "chartreuse",
		      "other"                  => "gray",
		      "tandem repeat"          => "gray", #"gray24",
		      );

  my $type   =  $f->repeat_consensus()->repeat_type();
  my $colour = $type_colours{$type} || "gray";
		      
  return {
      'key'     => 'repeat',
      'feature' => $colour,
      'label'   => 'black',
      'part'    => ''
      };
}


1;
