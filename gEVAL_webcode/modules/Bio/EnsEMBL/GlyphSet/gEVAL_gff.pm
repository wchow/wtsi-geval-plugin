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

package Bio::EnsEMBL::GlyphSet::gEVAL_gff;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

#---------------------------#
#
#  Glyph for gff data
#
#    wc2@sanger.ac.uk
#---------------------------#

#-------------------------------------#
# features
#  Fetches all the digest feats from
#  misc_feature table.
#-------------------------------------#
sub features {
  my ($self) = @_;
  my $db        = $self->my_config('db');
  my $misc_sets = $self->my_config('set');
  my @T         = ($misc_sets);

  my @sorted =  
    map { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map { [$_->seq_region_start - 
      1e9 * (
      $_->get_scalar_attribute('state') + $_->get_scalar_attribute('BACend_flag')/4
      ), $_]
    }
    map { @{$self->{'container'}->get_all_MiscFeatures( $_, $db )||[]} } @T;
  return \@sorted;
}

#-------------------------------------#
# get_colours
#  Sets the colours for the digests
#  frags, default: purple.
#-------------------------------------#
sub get_colours {
  my( $self, $f ) = @_;

  my $colour = "#0B610B";
 
  return {
    'key'     => 'gff',
    'feature' => $colour,
    'label'   => 'white',
    'part'    => ''
      };

}

#--------------------------------------------------------------#
# New: e73 uses label_overlay to tag the old "overlaid" style.
sub label_overlay { return 1; }
#--------------------------------------------------------------#

#---------------------------------------------------------#
# feature_label
#  Return the image label and the position of the label
#  (overlaid means that it is placed in the centre of the
#  feature.
#---------------------------------------------------------#
sub feature_label {
  my ($self, $f ) = @_;

  my $label;
  $label = $f->get_scalar_attribute('gff_Name') if ($f->get_scalar_attribute('gff_Name'));
  $label = $f->get_scalar_attribute('gffsource') if (!$label);
  $label = "gff_feature" if (!$label);

  return ($label);

}

#---------------------------------------------------------#
# href
#  Link back to this page centred on the map fragment
#  data to be sent for zmenu creation.
#---------------------------------------------------------#
sub href {
  my ($self, $f ) = @_;
  my $db   = $self->my_config('db');
  my $name = $f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc));
  my $mfid = $f->dbID;
  my $r    = $f->seq_region_name.':'.$f->seq_region_start.'-'.$f->seq_region_end;

  my $zmenu = {
      'type'          => 'Location',
      'action'        => 'View',
      'r'             => $r,
      'misc_feature_n'=> $name,
      'mfid'          => $mfid,
      'db'            => $db,
  };
  return $self->_url($zmenu);
}


1;
