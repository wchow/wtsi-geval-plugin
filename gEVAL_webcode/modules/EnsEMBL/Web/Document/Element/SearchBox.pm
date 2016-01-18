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

package EnsEMBL::Web::Document::Element::SearchBox;
### Generates small search box (used in top left corner of pages)

use strict;
use base qw(EnsEMBL::Web::Document::Element);

sub search_options {
  ## Returns the options for the search dropdown based upon the current species
  my $self          = shift;
  my $species       = $self->species;
  my $species_name  = $species ? $self->species_defs->SPECIES_ORGANISM_NAME ." (". $self->species_defs->ASSEMBLY_DISPLAY_NAME .")" 
			       : $self->species_defs->SPECIES_COMMON_NAME;

  return [ $species ? (
    'pgp_search'      => { 'label' => "Search $species_name",   'icon' => "search/pgp_search.gif"   }) : 
    ('pgp_search'      => { 'label' => "Search gEVAL",          'icon' => "search/pgp_search.gif"   } ),
  ];
}

sub default_search_code {
  ## Returns the search code either set by the user previously by selecting one of the options in the drodpown, or defaults to the one specified in sitedefs
  return $_[0]->{'_default'} ||= $_[0]->hub->get_cookie_value('ENSEMBL_SEARCH') || $_[0]->species_defs->ENSEMBL_DEFAULT_SEARCHCODE || 'ensembl';
}

sub species {
  ## Ignores common and Multi as species names
  my $species = $_[0]->hub->species;
  return $species =~ /multi|common/i ? '' : $species;
}

sub content {
  my $self            = shift;
  my $img_url         = $self->img_url;
  my $species         = $self->species;
  my $search_url      = sprintf '%s%s/psychic', $self->home_url, $species || 'Multi';
  my $options         = $self->search_options;
  my %options_hash    = @$options;
  my $search_code     = lc $self->default_search_code;
     $search_code     = $options->[0] unless exists $options_hash{$search_code};
  my $search_options  = join '', map {
    if ($_ % 2 == 0) {
      my $code    = $options->[$_];
      my $details = $options->[$_ + 1];
      qq(<div class="$code"><img src="${img_url}$details->{'icon'}" alt="$details->{'label'}"/>$details->{'label'}<input type="hidden" value="$details->{'label'}&hellip;" /></div>\n);
    }
  } 0..scalar @$options - 1;

  return qq(
    <div id="searchPanel" class="js_panel">
      <input type="hidden" class="panel_type" value="SearchBox" />
      <form action="$search_url">
        <div class="search print_hide">
          <div class="sites button">
            <img class="search_image" src="${img_url}$options_hash{$search_code}{'icon'}" alt="" />
            <img src="${img_url}search/down.gif" style="width:7px" alt="" />
            <input type="hidden" name="site" value="$search_code" />
          </div>
          <div>
            <label class="hidden" for="se_q">Search terms</label>
            <input class="query inactive" id="se_q" type="text" name="q" value="$options_hash{$search_code}{'label'}&hellip;" />
          </div>
          <div class="button"><input type="image" src="${img_url}16/search.png" alt="Search&nbsp;&raquo;" /></div>
        </div>
        <div class="site_menu hidden">
          $search_options
        </div>
      </form>
    </div>
    <a href="/Multi/Search/New"><img src="/i/32/rev/search.png" title="Search this site" class="mobile-search mobile-only" /></a>
  );
}

1;
