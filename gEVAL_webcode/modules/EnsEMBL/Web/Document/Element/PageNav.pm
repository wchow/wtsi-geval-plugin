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

package EnsEMBL::Web::Document::Element::PageNav;
# Container HTML for left sided navigation menu on dynamic pages 

use strict;
use HTML::Entities qw(encode_entities);
use URI::Escape    qw(uri_escape);
use base qw(EnsEMBL::Web::Document::Element::Navigation);

sub modify_init {
  my ($self, $controller) = @_;
  my $hub        = $controller->hub;
  my $object     = $controller->object;
  my @components = @{$hub->components};
  my $session    = $hub->session;
  my $user       = $hub->user;
  my $has_data   = grep($session->get_data(type => $_), qw (upload url das)) || ($user && (grep $user->get_records($_), qw(uploads urls dases)));
  my $view_config;
     $view_config = $hub->get_viewconfig(@{shift @components}) while !$view_config && scalar @components;
  
  ## Set up buttons
  if ($view_config) {
    my $component = $view_config->component;

    $self->add_button({
      caption => 'Configure this page',
      class   => 'modal_link',
      rel     => "modal_config_$component",
      url     => $hub->url('Config', {
        type      => $view_config->type,
        action    => $component,
        function  => undef,
      })
    });
  } else {
    $self->add_button({
      caption => 'Configure this page',
      class   => 'disabled',
      url     => undef,
      title   => 'There are no options for this page'
    });
  }
  
  my %data;
  
  $self->add_button({
    caption => $has_data ? 'Manage your data' : 'Add your data',
    class   => 'modal_link',
    rel     => 'modal_user_data',
    url     => $hub->url({
      time    => time,
      type    => 'UserData',
      action  => $has_data ? 'ManageData' : 'SelectFile',
      __clear => 1
    })
  });

  ##--------------------------------------------------------# 	
  ## wc2 - added to give option to turn off export function
  my $export_off   = $hub->species_defs->EXPORT_OFF;
  ##--------------------------------------------------------#	

  if ($object && $object->can_export && !$export_off) {
    $self->add_button({
      caption => 'Export data',
      class   => 'modal_link',
      url     => $self->_export_url($hub)
    });
  } else {
    $self->add_button({
      caption => 'Export data',
      class   => 'disabled',
      url     => undef,
      title   => 'You cannot export data from this page'
    });
  }

  if ($hub->user) {
    my $title = $controller->page->title;

    $self->add_button({
      caption => 'Bookmark this page',
      class   => 'modal_link',
      url     => $hub->url({
        type        => 'Account',
        action      => 'Bookmark/Add',
        __clear     => 1,
        name        => uri_escape($title->get_short),
        description => uri_escape($title->get),
        url         => uri_escape($hub->species_defs->ENSEMBL_BASE_URL . $hub->url)
      })
    });
  } else {
    $self->add_button({
      caption => 'Bookmark this page',
      class   => 'disabled',
      url     => undef,
      title   => 'You must be logged in to bookmark pages'
    });
  }

  $self->add_button({
    caption => 'Share this page',
    url     => $hub->url('Share', {
      __clear => 1,
      create  => 1,
      time    => time
    })
  });
}


1;
