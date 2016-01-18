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

package EnsEMBL::Web::Component::Location::Dotplot;

#---------------------------------------------#
# Not really used at all, old legacy code.
# Doesn't really give a true dotplot anyways.
# If still interested, go to Zmenu/Selfcomp.pm
# and uncomment the Dotplot section for a link
# in the zmenu.
#   wc2 2015
#---------------------------------------------#

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use Time::HiRes qw(time);
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable( 1 );
  $self->configurable(  1 );
  $self->has_image(1);

}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $threshold   = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $image_width = $self->image_width;

  if( $object->length > $threshold ) {
    return $self->_warning( 'Region too large','
  <p>
    The region selected is too large to display in this view - use the navigation above to zoom in...
  </p>' );
  }


  my $slice  = $object->slice;
  my $length = $slice->end - $slice->start + 1;
  my $T = time;
  my $wuc    = $object->get_imageconfig( 'dotplot' );
  $T = sprintf "%0.3f", time - $T;
  $wuc->tree->dump("Dotplot configuration [ time to generate $T sec ]", '([[caption]])')
    if $hub->species_defs->ENSEMBL_DEBUG_FLAGS & $hub->species_defs->ENSEMBL_DEBUG_TREE_DUMPS;

  $wuc->set_parameters({
    'container_width' => $length,
    'image_width'     => $image_width || 800, ## hack at the moment....
    'slice_number'    => '1|3'
  });

  
  my $info   = $wuc->_update_missing( $object );

  my $image = $self->new_image($slice, $wuc, $object->highlights);

  $image->{'panel_number'} = 'bottom';
  $image->imagemap = 'yes';

  $image->set_button( 'drag', 'title' => 'Click or drag to centre display', 'URL' => 'http://www.theonion.com' );
  my $html = $image->render;

  return $html;
}


1;
