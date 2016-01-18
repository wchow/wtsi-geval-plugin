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


package Bio::EnsEMBL::GlyphSet::gEVAL_blacktag;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub features {
  my ($self) = @_;
  my $db = $self->my_config('db');
  my $misc_sets = $self->my_config('set');
  my @T = ($misc_sets);

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


sub get_colours {
  my( $self, $f ) = @_;

  return {
    'key'     => 'clone',
    'feature' => 'black',
    'label'   => 'black',
    'part'    => ''
      };
  
}


## Link back to this page centred on the map fragment
sub href {
  my ($self, $f ) = @_;
  my $db = $self->my_config('db');
  my $mfid = $f->dbID;

  my $clone_name = $f->get_scalar_attribute('bt_clone') if ($f->get_scalar_attribute('bt_clone'));
  my $desciption = $f->get_scalar_attribute('bt_desc')  if ($f->get_scalar_attribute('bt_desc'));

  my $zmenu = {
      'type'          => 'Location',
      'action'        => 'View',
      'mfid'          => $mfid,
      'db'            => $db,
  };
  return $self->_url($zmenu);
}


1;
