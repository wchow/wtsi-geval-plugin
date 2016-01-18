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

package EnsEMBL::Web::Document::HTML::FavouriteSpecies;
use strict;
use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self      = shift;
  my $fragment  = shift eq 'fragment';
  my $full_list = $self->render_species_list($fragment);
  
  my $html = $fragment ? $full_list : sprintf('
      <div class="reorder_species" style="display: none;">
         %s
      </div>
      <div class="full_species">
        %s 
      </div>
  ', $self->render_ajax_reorder_list, $full_list);


  return $html;
}

sub render_species_list {
  my ($self, $fragment) = @_;
  my $hub           = $self->hub;
  my $logins        = $hub->users_available;
  my $user          = $hub->user;
  my $species_info  = $hub->get_species_info;
  
  my (%check_faves, @ok_faves);
  
  foreach (@{$hub->get_favourite_species}) {
    push @ok_faves, $species_info->{$_} unless $check_faves{$_}++;
  }
  
  my $fav_html = $self->render_with_images(@ok_faves);
  
  return $fav_html if $fragment;
  
  # output list
  my $star = '<img src="/i/16/star.png" style="vertical-align:middle;margin-right:4px" />';
  my $html = sprintf qq{<div class="static_favourite_species"><h3>%s genomes</h3><div class="species_list_container species-list">$fav_html</div>%s</div>}, 
    $logins && $user && scalar(@ok_faves) ? 'Favourite' : 'Commonly viewed',
    $logins
      ? sprintf('<p class="customise-species-list">%s</p>', $user
        ? qq(<span class="link toggle_link">${star}Change favourites</span>)
        : qq(<a href="/Account/Login" class="modal_link modal_title_Login/Register">${star}Log in to customize this list</a>)
      )
    : ''
  ;

  return $html;
}

sub render_ajax_reorder_list {
  my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $favourites    = $hub->get_favourite_species;
  my %species_info  = %{$hub->get_species_info};
  my @fav_list      = map qq\<li id="favourite-$_->{'key'}">$_->{'common'} (<em>$_->{'scientific'}</em>)</li>\, map $species_info{$_}, @$favourites;
  
  delete $species_info{$_} for @$favourites;
  
  my @sorted       = sort { $a->{'common'} cmp $b->{'common'} } values %species_info;
  my @species_list = map qq\<li id="species-$_->{'key'}">$_->{'common'} (<em>$_->{'scientific'}</em>)</li>\, @sorted;
  
  return sprintf('
    <p>For easy access to commonly used genomes, drag from the bottom list to the top one &middot; <span class="link toggle_link">Save</span></p>
    <p><strong>Favourites</strong></p>
    <ul class="favourites list">
      %s
    </ul>
    <p><strong>Other available species</strong></p>
    <ul class="species list">
      %s
    </ul>
    <p><span class="link toggle_link">Save selection</span> &middot; <a href="/Account/Favourites/Reset">Restore default list</a></p>
  ', join("\n", @fav_list), join("\n", @species_list));
}

sub render_with_images {
  my ($self, @species_list) = @_;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $static_server = $species_defs->ENSEMBL_STATIC_SERVER;
  my $html;

  foreach (@species_list) {

    # wc2 Don't want to use common names;
    my $orgname               = $species_defs->get_config($_->{'common'}, 'SPECIES_ORGANISM_NAME') || $_->{'common'};	
    my $assembly_display_name = $species_defs->get_config($_->{'common'}, 'ASSEMBLY_DISPLAY_NAME') || $_->{'assembly'}; 

    next if !($_->{'scientific'});
    $html .= qq(
      <div class="species-box">
        <a href="$_->{'key'}/Info/Index">
          <span class="sp-img"><img src="$static_server/i/species/thumb_$_->{'scientific'}.png" alt="$_->{'name'}" title="Browse $_->{'name'}" height="48" width="48" /></span>
          <span>$orgname</span>
        </a>
        <span>$assembly_display_name</span>
      </div>
    );
  }

  return $html;
}

1;
