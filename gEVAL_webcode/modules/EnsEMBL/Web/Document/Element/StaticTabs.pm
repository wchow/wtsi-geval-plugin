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

package EnsEMBL::Web::Document::Element::StaticTabs;
# Generates the global context navigation menu, used in static pages

use strict;
use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::Constants;
use base qw(EnsEMBL::Web::Document::Element::Tabs);

sub _tabs {
  return {
    tab_order => [qw(website data about)],
    tab_info  => {
      about     => {
                    title => 'About us',
                    },
      data      => {
                    title => 'Data access',
                    },
      website   => {
                    title => 'Using this website',
                    },
    },
  };
}

sub init {
  my $self          = shift;
  my $controller    = shift;
  my $hub           = $controller->hub;
  my $species_defs  = $hub->species_defs;  
   
  my $here = $ENV{'REQUEST_URI'};

  my $tabs = $self->_tabs;

  foreach my $section (@{$tabs->{'tab_order'}}) {
    my $info = $tabs->{'tab_info'}{$section};
    next unless $info;
    my $url   = "/info/$section/";
    my $class = ($here =~ /^$url/) ? ' active' : '';
    $self->add_entry({
      'type'    => $section,
      'caption' => $info->{'title'},
      'url'     => $url,
      'class'   => $class,
    });
  }
}

1;
