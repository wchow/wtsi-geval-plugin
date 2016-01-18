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

package EnsEMBL::Web::Factory::Marker;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self     = shift;    
  my $database = $self->database('core');
  
  return $self->problem('fatal', 'Database Error', 'Could not connect to the core database.') unless $database;
 
  my $marker = $self->param('m') || $self->param('marker');
     $marker =~ s/\s//g;

  #-- added for non-marker id links, primarily MarkerMapLocation) wc2. --#
  my $map    = $self->param('map');
  my $maploc = $self->param('maploc');

  #-- return if no marker id AND no map/maploc id.--#     
  return $self->problem('fatal', 'Valid Marker ID required', 'Please enter a valid marker ID in the URL.') if (!$marker && !$map && !$maploc);
  return $self->problem('fatal', 'Valid Map and MapLoc ID required', 'Please check that Both Map/MapLoc ID in the URL.') if (!$marker && (!$map || !$maploc));

  #-- if both map/maploc ID, return empty marker object, for MarkerMaplocation, non-marker id links --# 	
  return if (!$marker);
 	  
  my @markers = grep $_, @{$database->get_MarkerAdaptor->fetch_all_by_synonym($marker) || []};
  
  return $self->problem('fatal', "Could not find Marker $marker", "Either $marker does not exist in the current Ensembl database, or there was a problem retrieving it.") unless @markers;
  
  $self->DataObjects($self->new_object('Marker', \@markers, $self->__data));
  
  $self->param('m', $marker);
  $self->delete_param('marker');
}

1;
  
