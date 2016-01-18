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

package EnsEMBL::Web::Configuration::Punchlist;

use strict;
use base qw( EnsEMBL::Web::Configuration );
use CGI;
use EnsEMBL::Web::TmpFile::Text;


sub global_context { return $_[0]->_global_context; }
#sub global_context { return undef; }

#sub ajax_content   { return $_[0]->_ajax_content;   }
sub ajax_content   { return undef;   }

sub local_context  { return $_[0]->_local_context;  }
#sub local_context  { return undef;  }

sub local_tools    { return $_[0]->_local_tools;  }
#sub local_tools    { return $_[0]->_local_tools;  }

#sub context_panel  { return $_[0]->_context_panel;  }
sub context_panel  { return undef;  }

sub content_panel  { return $_[0]->_content_panel;  }
#sub content_panel  { return undef; }

#sub configurator   { return $_[0]->_configurator;   }
sub configurator   { return undef;   }



sub set_default_action {
  my $self = shift;
  #$self->{_data}{default} = 'Overview';
  $self->{'_data'}->{'default'} = $self->object ? $self->object->default_action : 'Overview';



}

sub populate_tree {
  my $self = shift;

  # Including a hack so ensembl recognises the punchtype adaptor...
  use Bio::EnsEMBL::DBSQL::PunchTypeAdaptor;
  use Bio::EnsEMBL::DBSQL::PunchAdaptor;
  Bio::EnsEMBL::DBSQL::PunchAdaptor->init( $self->object->species_defs->valid_species() );
  Bio::EnsEMBL::DBSQL::PunchTypeAdaptor->init( $self->object->species_defs->valid_species() );

  $self->create_node( 'Overview', "Overview",
		      [qw(top EnsEMBL::pgp::Web::Component::Punchlist::Overview)],
		      { 'availability' => 1},
		      );

  
  my $pa  =  $self->object->database('core')->get_PunchAdaptor();
  my $pta =  $self->object->database('core')->get_PunchTypeAdaptor();
  
  my @punch_types = @{$pta->fetch_all()};

  @punch_types = sort { $a->code() cmp $b->code() } @punch_types;

  foreach my $punch_type ( @punch_types ) {

    my $feature_type_adaptor = "get_".$punch_type->feature_type()."Adaptor";
    my $adaptor = $self->object->database('core')->$feature_type_adaptor();
    my @punches = @{$pa->fetch_by_punch_type( $punch_type->code )};
    
    next if ( ! @punches);
      
    $self->create_node( $punch_type->code, $punch_type->name,
			[qw(top EnsEMBL::Web::Component::Punchlist::Overview)],
			{ 'availability' => 1,
			  'url'   => '/'.$self->species.'/Punchlist/Overview?punchtype='.$punch_type->code,

			  },
			);
    
  }

  return;

}


1;


