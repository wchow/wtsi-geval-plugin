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

package EnsEMBL::Web::Data::Bio::AlignFeature;

### NAME: EnsEMBL::Web::Data::Bio::AlignFeature
### Base class - wrapper around Bio::EnsEMBL::DnaAlignFeature 
### or ProteinAlignFeature API object(s) 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::Feature

### DESCRIPTION:
### This module provides additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
### Converts a set of API objects into simple parameters 
### for use by drawing code and HTML components
  my $self = shift;
  my $data = $self->data_objects;
  my $type = $self->type;
  my $results = [];

  my @coord_systems = @{$self->coord_systems}; 
  foreach my $f (@$data) {
    if (ref($f) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($f);
      push(@$results, $unmapped);
    }
    else {
      my( $region, $start, $end, $strand ) = ( $f->seq_region_name, $f->start, $f->end, $f->strand );

      # :: wc2 ::PGP add rep/norep logicname 
      my $logic_name = $f->analysis->logic_name;

      if( $f->coord_system_name ne $coord_systems[0] ) {
        foreach my $system ( @coord_systems ) {
          # warn "Projecting feature to $system";
          my $slice = $f->project( $system );
          # warn @$slice;
          if( @$slice == 1 ) {
            ($region,$start,$end,$strand) = ($slice->[0][2]->seq_region_name, $slice->[0][2]->start, $slice->[0][2]->end, $slice->[0][2]->strand );
            last;
          } 
        }
      }
      push @$results, {
        'region'   => $region,
        'start'    => $start,
        'end'      => $end,
        'strand'   => $strand,
        'length'   => $f->end-$f->start+1,
        'label'    => $f->display_id." (@{[$f->hstart]}-@{[$f->hend]})",
        'gene_id'  => ["@{[$f->hstart]}-@{[$f->hend]}"],
        'extra' => { 
                    'align'   => $f->alignment_length, 
                    'ori'     => $f->hstrand * $f->strand, 
                    'id'      => $f->percent_id, 
                    'score'   => $f->score, 
                    'coverage' => $f->hcoverage,
		    'logic_name' => $logic_name,
                    }
      };
    } 
  }   
  my $extra_columns = [
                    {'key' => 'align',  'title' => 'Alignment length', 'sort' => 'numeric'}, 
                    {'key' => 'ori',    'title' => 'Rel ori'}, 
                    {'key' => 'id',     'title' => '%id'}, 
                    {'key' => 'score',  'title' => 'Score', 'sort' => 'numeric'}, 
                    {'key' => 'coverage', 'title' => 'Coverage', 'sort' => 'numeric'},
                    {'key' => 'logic_name', 'title' => 'Analysis', 'sort' => 'numeric'},

  ];
  return [$results, $extra_columns];
}

1;
