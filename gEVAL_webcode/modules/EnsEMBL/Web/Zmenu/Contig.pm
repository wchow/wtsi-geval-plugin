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

#----------------------------------------#
# Contig Zmenu
# Last updated 9/13 with orientation 
#  entry.
#----------------------------------------#
package EnsEMBL::Web::ZMenu::Contig;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self            = shift;
  my $hub             = $self->hub;
  my $threshold       = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $slice_name      = $hub->param('region');
  my $db_adaptor      = $hub->database('core');
  my $slice           = $db_adaptor->get_SliceAdaptor->fetch_by_region('seqlevel', $slice_name);
  my $slice_type      = $slice->coord_system_name;
  my $top_level_slice = $slice->project('toplevel')->[0]->to_Slice;
  my $action          = $slice->length > $threshold ? 'Overview' : 'View';
  my $objstrand       = $hub->param('objstrand');

  ## wc2: added to create option to turn off export/link to ENA
  my $export_off   = $hub->species_defs->EXPORT_OFF;
  my $no_ENA_rec   = $hub->species_defs->ENA_RECORD_OFF;

  $self->caption($slice_name);
  
  $self->add_entry({
    label => "Center on $slice_type $slice_name",
    link  => $hub->url({ 
      type   => 'Location', 
      action => $action, 
      region => $slice_name,
      __clear   => 1, 
    })
  });
  
  $self->add_entry({
    label      => "Export $slice_type sequence/features",
    link_class => 'modal_link',
    link       => $hub->url({ 
       			    type     => 'Export',
           		    action   => 'Configure',
           		    function => 'Location',
          		    r        => sprintf '%s:%s-%s', map $top_level_slice->$_, qw(seq_region_name start end)
    })
  }) if (!$export_off);
  
  my $embl = 0; # just a tag to prevent duplication of links.
  foreach my $cs (@{$db_adaptor->get_CoordSystemAdaptor->fetch_all || []}) {
    next if $cs->name eq $slice_type;  # don't show the slice coord system twice
    next if $cs->name eq 'chromosome'; # don't allow breaking of site by exporting all chromosome features
    
    my $path;
    eval { $path = $slice->project($cs->name); };
    
    next unless $path && scalar @$path == 1;

    my $new_slice        = $path->[0]->to_Slice->seq_region_Slice;
    my $new_slice_type   = $new_slice->coord_system_name;
    my $new_slice_name   = $new_slice->seq_region_name;
    my $new_slice_length = $new_slice->seq_region_length;

    $action = $new_slice_length > $threshold ? 'Overview' : 'View';
    
    $self->add_entry({
      label => "Center on $new_slice_type $new_slice_name",
      link  => $hub->url({
        type   => 'Location', 
        action => $action, 
        region => $new_slice_name,
	__clear   => 1,
      })
    });

    # would be nice if exportview could work with the region parameter, either in the referer or in the real URL
    # since it doesn't we have to explicitly calculate the locations of all regions on top level
    $top_level_slice = $new_slice->project('toplevel')->[0]->to_Slice;

    $self->add_entry({
      label      => "Export $new_slice_type sequence/features",
      link_class => 'modal_link',
      link       => $hub->url({
        		type     => 'Export',
        		action   => 'Configure',
        		function => 'Location',
        		r        => sprintf '%s:%s-%s', map $top_level_slice->$_, qw(seq_region_name start end)
      })
    }) if (!$export_off);

   
    if ($cs->name eq 'clone') {
      (my $short_name = $new_slice_name) =~ s/\.\d+$//;
      

      # WC2 added to include accessions for zfish.
      my ($accession) = @{$new_slice->get_all_Attributes('accession')};
      my ($version)   = @{$new_slice->get_all_Attributes('version')};
      my ($intname)   = @{$new_slice->get_all_Attributes('int_name')};	
      if ($accession) {
          $new_slice_name = ($accession->value) ? $accession->value : $slice_name;
          $new_slice_name .= "." . $version->value if ($accession && $version);
      }
      (my $short_name = $new_slice_name) =~ s/\.\d+$//;


      #-----
      $self->add_entry({
        type  => 'ENA',
        label => $new_slice_name,
        link  => $hub->get_ExtURL('EMBL', $new_slice_name),
        extra => { external => 1 }
      }) if (!$no_ENA_rec);
      
      $self->add_entry({
        type  => 'ENA (latest version)',
        label => $short_name,
        link  => $hub->get_ExtURL('EMBL', $short_name),
        extra => { external => 1 }
      }) if (!$no_ENA_rec);

      $embl = 1;	
    }
  }

  my ($slice_accession) = @{$slice->get_all_Attributes('accession')};
  $self->add_entry({
    type  => 'Accession',
    label => $slice_accession->value,
    link  => $hub->get_ExtURL('EMBL', $slice_accession->value),
    extra => { external => 1}
  }) if ($slice_accession && !$embl && !$no_ENA_rec );

  my ($sanger_name) = @{$slice->get_all_Attributes('sanger_name')};
  $self->add_entry({
    type  => 'Sanger Name',
    label => $sanger_name->value,
  }) if ($sanger_name );

  my ($intl_name) = @{$slice->get_all_Attributes('int_name')};
  $self->add_entry({
    type  => 'External Name',
    label => $intl_name->value,
  }) if ($intl_name );

  my ($status_desc) = @{$slice->get_all_Attributes('status_desc')};
  $self->add_entry({
    type  => 'Status',
    label => $status_desc->value,
  }) if ($status_desc );

  my ($htgs_phase) = @{$slice->get_all_Attributes('htgs_phase')};
  $self->add_entry({
    type  => 'HTGS Phase',
    label => $htgs_phase->value,
  }) if ($htgs_phase );

  $self->add_entry({
    type  => 'Orientation',
    label => ($objstrand eq 1) ? ">" : "<",
  }) if ($objstrand);



}

1;
