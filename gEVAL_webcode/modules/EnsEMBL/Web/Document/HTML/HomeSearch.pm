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

package EnsEMBL::Web::Document::HTML::HomeSearch;

### Generates the search form used on the main home page and species
### home pages, with sample search terms taken from ini files

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

use EnsEMBL::Web::Form;

sub render {
  my $self = shift;
  
  return if $ENV{'HTTP_USER_AGENT'} =~ /Sanger Search Bot/;

  my $hub                 = $self->hub;
  my $species_defs        = $hub->species_defs;
  my $page_species        = $hub->species || 'Multi';
  my $species_name        = $page_species eq 'Multi' ? '' : $species_defs->SPECIES_ORGANISM_NAME." (".$species_defs->ASSEMBLY_DISPLAY_NAME.")";
  my $search_url          = $species_defs->ENSEMBL_WEB_ROOT . "$page_species/psychic";
  my $default_search_code = $species_defs->ENSEMBL_DEFAULT_SEARCHCODE;
  my $is_home_page        = $page_species eq 'Multi';
  my $input_size          = $is_home_page ? 30 : 50;
  my $favourites          = $hub->get_favourite_species;
  my $q                   = $hub->param('q');

  # form
  my $form = EnsEMBL::Web::Form->new({'action' => $search_url, 'method' => 'get', 'skip_validation' => 1, 'class' => [ $is_home_page ? 'homepage-search-form' : (), 'search-form', 'clear' ]});
  $form->add_hidden({'name' => 'site', 'value' => $default_search_code});

  # examples
  my $examples;
  my $sample_data;

  if ($is_home_page) {
    $sample_data = $species_defs->get_config('MULTI', 'GENERIC_DATA') || {};
  } else {
    $sample_data = { %{$species_defs->SAMPLE_DATA || {}} };
    $sample_data->{'GENE_TEXT'} = "$sample_data->{'GENE_TEXT'}" if $sample_data->{'GENE_TEXT'};
  }

  if (keys %$sample_data) {
    $examples = join ' or ', map { $sample_data->{$_}
      ? qq(<a class="nowrap" href="$search_url?q=$sample_data->{$_}">$sample_data->{$_}</a>)
      : ()
    } qw(GENE_TEXT LOCATION_TEXT SEARCH_TEXT JIRA_TEXT CLONE_TEXT);
    $examples = qq(<p class="search-example">e.g. $examples</p>) if $examples;
  }

  # form field
  my $f_params = {'notes' => $examples};
  $f_params->{'label'} = 'Search' if $is_home_page;
  my $field = $form->add_field($f_params);

  # species dropdown
  if ($page_species eq 'Multi') {
    # wc2 edit to display full details and not common name.
    my %species      = map { $species_defs->get_config($_, 'SPECIES_ORGANISM_NAME')."_".$species_defs->get_config($_, 'ASSEMBLY_DISPLAY_NAME') => $_ } @{$species_defs->ENSEMBL_DATASETS};
    my %common_names = reverse %species;

    $field->add_element({
      'type'    => 'dropdown',
      'name'    => 'species',
      'id'      => 'species',
      'class'   => 'input',
      'values'  => [
        {'value' => '', 'caption' => 'Choose an assembly'}, # Edited wc2.
        {'value' => '', 'caption' => '---', 'disabled' => 1},
        map({ $common_names{$_} ? {'value' => $_, 'caption' => $common_names{$_}, 'group' => 'Favourite species'} : ()} @$favourites),
        {'value' => '', 'caption' => '---', 'disabled' => 1},
        map({'value' => $species{$_}, 'caption' => $_}, sort { uc $a cmp uc $b } keys %species)
      ]
    }, 1)->first_child->after('label', {'inner_HTML' => 'for', 'for' => 'q'});
  }

  # search input box & submit button
  my $q_params = {'type' => 'string', 'value' => $q, 'id' => 'q', 'size' => $input_size, 'name' => 'q', 'class' => 'query input inactive'};
  $q_params->{'value'} = "Search $species_name..." unless $is_home_page;
  $field->add_element($q_params, 1);
  $field->add_element({'type' => 'submit', 'value' => 'Go'}, 1);

  my $elements_wrapper = $field->elements->[0];
  $elements_wrapper->append_child('span', {'class' => 'inp-group', 'children' => [ splice @{$elements_wrapper->child_nodes}, 0, 2 ]})->after({'node_name' => 'wbr'}) for (0..1);

  return sprintf '<div id="SpeciesSearch" class="js_panel"><input type="hidden" class="panel_type" value="SearchBox" />%s</div>', $form->render;
}

1;
