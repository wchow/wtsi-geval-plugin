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

package EnsEMBL::Web::Component::Search::Results;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use EnsEMBL::Web::Document::HTML::HomeSearch;

# --------------------------------------------------------------------
# An updated version of Summary.pm enabling: 
# - specification of the order the result categories are displayed in
# - more user friendly descriptions of the search categories. 
# - display of the search term above the results
#  NJ, Eagle Genomics
# Replaces UniSearch::Summary - ap5, Ensembl webteam
# --------------------------------------------------------------------

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my $search = $self->object->Obj;
  my $html;

  if ($hub->species ne 'Multi' && $hub->param('q')) {
    $html = "<p>Your search for <strong>" . $hub->param('q')  . "</strong> returned <strong>"
              .$search->{total_hits}."</strong> hits.</p>";
    $html .= "<p>Please note that because this site uses a direct MySQL search,  we limit the search to 10 results per category and search term, in order to avoid overloading the database server.";

    # Eagle change to order the results differently
    # we can either order the results by our own @order_results array, the species.ini files ( @idxs ), or just by sorting by keys as below. 	
    # ## Filter by configured indices

    # # These are the methods for the current species that we want to try and run
    # # The array is ordered in the way that they are listed in the .ini file
    # my @idxs = @{$hub->species_defs->ENSEMBL_SEARCH_IDXS};
	
    # the first value is the search method/species ini term. The second value is the display label.


    #
    # ::CHANGE:: wc2, search groups are changed to those relevant to the pgpviewer
    #

    my @order_results = ( [ 'Marker', 'Genetic Marker'], ['GenomicAlignment', 'Sequence Aligned to Genome, eg. BAC Ends or cDNA' ], ['Punchlist', 'Punchlist Entries'], [ 'Sequence', 'Genomic Region, eg. Clone or Contig' ], ['Jira', 'JIRA Ticket Issues'] ); 

    foreach my $search_ref ( @order_results ) {
      my $search_index = $search_ref->[0];
      my $display_term = $search_ref->[1]; 
        if ( $search->{'results'}{$search_index} ) { 
	        my( $results ) = @{ $search->{'results'}{$search_index} };
          my $count = scalar(@$results);
	        $html .= "<h3>$display_term</h3><p>$count entries matched your search strings.</p><ol>";
	        foreach my $result ( @$results ) {
	          $html .= sprintf(qq(<li><strong>%s:</strong> <a href="%s">%s</a>),
			        $result->{'subtype'}, $result->{'URL'}, $result->{'ID'}
			      );
	          if( $result->{'URL_extra'} ) {
	            foreach my $E ( @{[$result->{'URL_extra'}]} ) {
	              $html .= sprintf(qq( [<a href="%s" title="%s">%s</a>]),
			            $E->[2], $E->[1], $E->[0]
			          );
	            }
	          }
	          if( $result->{'desc'} ) {
	            $html .= sprintf(qq(<br />%s), $result->{'desc'});
	          }
	          $html .= '</li>';
	        }
	        $html .= '</ol>';
        }
    }
  }
  else {
    if ($hub->species eq 'Multi') {
     $html .= '<p class="space-below">Simple text search cannot be executed on all species at once. Please select a species from the dropdown list below and try again.</p>';
    }
    elsif (!$hub->param('q')) {
     $html .= '<p class="space-below">No query terms were entered. Please try again.</p>';
    }
    my $search = EnsEMBL::Web::Document::HTML::HomeSearch->new($self->hub);
    $html .= $search->render
  }

  return $html;
}

1;
