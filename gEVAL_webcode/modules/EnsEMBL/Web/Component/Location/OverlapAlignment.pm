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

#---------------------------------------------#
# Not really used at all, old legacy code.
# If still interested, go to Zmenu/Overlap.pm
# and uncomment the Alignment section for a link
# in the zmenu.
#   wc2 2015
#---------------------------------------------#



package EnsEMBL::Web::Component::Location::OverlapAlignment;

use strict;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Location);
use Time::HiRes qw(time);
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable( 1 );
  $self->configurable( 1 );
}

sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $dbID        = $object->param('dbid');
  

  my $db_adaptor = $object->database('core');
  my $sa         = $db_adaptor->get_SliceAdaptor();
  my $dafa       = $db_adaptor->get_DnaAlignFeatureAdaptor();


  my $feature  = $dafa->fetch_by_dbID( $dbID );
  my $hseqname = $feature->hseqname;
  my $overlap_variation = sprintf("%3.2f%%",$feature->percent_id());
  
  my $html = "<h3>Overlap alignment of $hseqname</h3>";
  $html .= "Percent identity: $overlap_variation <br>";


  my %attrib_hash = map { $_->code, $_ } @{$feature->get_all_Attributes()};

  if ( ! $attrib_hash{ overlap_data } ) {
    $html .= "<BR<B>No aligment data for this overlap.</B>";
    return $html;
  }

  my ($input1, $input2) = split('#', $attrib_hash{ overlap_data }->value());

  my $cigar_string = $feature->cigar_string;
  my $slice1 = $sa->fetch_by_name( $input1 );
  my $slice2 = $sa->fetch_by_name( $input2 );
  my $seq1   = $slice1->seq;
  my $seq2   = $slice2->seq;

  
  if (! $cigar_string || $cigar_string eq "M") {
    $html .= "<BR<B>No aligment stored for this overlap.</B>";
    
    $html .= "<pre>";
    $html .= ">" . $slice1->seq_region_name . "\n";
    $html .= format_seq( $seq1) . "\n";
    $html .= ">" . $slice2->seq_region_name . "\n";
    $html .= format_seq( $seq2) . "\n";
    
    return $html;
  }
	

  ($seq1, $seq2) = patch_sequences( $seq1, $seq2, $cigar_string);

  my ($align, $perc_ident) = align($seq1, $seq2);

  $html .= "<PRE>".  print_alignment($seq1, $align, $seq2, 0, 0) . "</PRE>";
  

  return $html;
}




# 
# 
# 
# Kim Brugger (18 Apr 2009)
sub print_alignment{
  my ( $seq1, $align, $seq2, $seq1_offset, $seq2_offset) = @_;

  my ($seq1_pos, $seq2_pos) = (0,0);
  my $COL = 80;
  my $count = length $seq1;

  my $res = "";

  my $j = 0;
  while ($j < $count) {
    
    $res .= sprintf("%-7d\t%s\n", $seq1_pos+1+$seq1_offset,substr($seq1,  $j, $COL));
    $res .= sprintf("       \t%s\n", substr($align,  $j, $COL));
    $res .= sprintf("%-7d\t%s\n", $seq2_pos+1+$seq2_offset,substr($seq2,  $j, $COL)) . "\n";

    # compensate the seq positions to the number of gaps found in the 
    # sequence...
    $seq1_pos += $COL - (substr($seq1,  $j, $COL) =~ tr/-/-/);
    $seq2_pos += $COL - (substr($seq2,  $j, $COL) =~ tr/-/-/);

    $j += $COL;
  }
  
  return $res;
}




# 
# 
# 
# Kim Brugger (20 Jul 2009)
sub patch_sequences {
  my ( $seq1, $seq2, $cigar ) = @_;
  
  my @seq1  = split("", $seq1 );
  my @seq2  = split("", $seq2 );


  my (@cigar) = $cigar =~ /(\d{0,10}\w)/g;

  my $offset = 0;
  foreach my $patch ( @cigar ) {
    my ($length, $type) =  $patch =~ /(\d{0,10})(\w)/;
    $length = 1 if (!$length);
    die "Does not know how to handle an feature of the type '$type'\n"
	if ( $type ne "M" && $type ne 'D' && $type ne 'I');

    if ( $type eq "D") {
      my @dashes = split("", "-"x$length);
      splice(@seq1, $offset, 0, @dashes);
    }

    $offset += $length;
  }

  $offset = 0;
  foreach my $patch ( @cigar ) {
    my ($length, $type) =  $patch =~ /^(\d{0,10})(\w)/;
    $length = 1 if (!$length);

    die "Does not know how to handle an feature of the type '$type' ('$patch')\n"
	if ( $type ne "M" && $type ne 'D' && $type ne 'I');
    
    if ( $type eq "I") {
      my @dashes = split("", "-"x$length);
      splice(@seq2, $offset, 0, @dashes);
    }
    
    $offset += $length;
  }
  
  return (join("", @seq1), join("",@seq2));
}



# 
# Simple aligner of, hopefully, aligned sequence.
# 
# Kim Brugger (18 Apr 2009)
sub align {
  my ( $seq1, $seq2 ) = @_;
  
  my @seq1  = split("", $seq1 );
  my @seq2  = split("", $seq2 );
  my @alignment;

  my ($similar, $different) = (0,0);

  for(my $i=0;$i< @seq1 && $i< @seq2; $i++){

    if ( $seq1[ $i ] eq $seq2[ $i ] && $seq1[ $i ] ne "-") {
      push @alignment, "|";
      $similar++;
    }
    else {
      push @alignment, " ";
      $different++;
    }
    
  }
  
  my $align = join("", @alignment);
  my $perc_ident = sprintf("%2.2f", $similar*100/($different+$similar));
  return ( $align , $perc_ident );
}

sub format_seq {
  my ($seq, $width) =  @_;
  chomp ($seq);
  my $j = 0;
  my $count = length $seq;                                                       
  my $res = "";
  $width ||= 60;
  while ($j < $count) {
    $res .= substr($seq, $j, $width). "\n";
    $j += $width;
  }
  
  return $res;
}


1;
