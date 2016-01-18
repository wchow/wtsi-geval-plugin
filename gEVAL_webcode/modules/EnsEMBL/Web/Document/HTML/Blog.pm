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

package EnsEMBL::Web::Document::HTML::Blog;
### This module outputs a selection of blog headlines for the home page, 

use strict;
use warnings;
use LWP::UserAgent;
use XML::Atom::Feed;
use XML::RSS;
use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Cache;
use base qw(EnsEMBL::Web::Document::HTML);

our $MEMD = EnsEMBL::Web::Cache->new(
  enable_compress    => 1,
  compress_threshold => 10_000,
);

sub render {
  my $self  = shift;
  my $hub = new EnsEMBL::Web::Hub;

  my $blog_url = $hub->species_defs->ENSEMBL_BLOG_URL;
  my $blog_rss = $hub->species_defs->ENSEMBL_BLOG_RSS;
  ## Does this feed work best with XML::Atom or XML:RSS? 
  
  #
  # ::CHANGE:: wc2 I've removed the atom option, as it is by default rss but use the XML::Atom::Feed.
  #

  my $html = '<h3>Latest blog posts</h3>';
    
  if ($hub->cookies->{'ENSEMBL_AJAX'}) {
    $html .= qq(<div class="js_panel ajax" id="blog"><input type="hidden" class="ajax_load" value="/blog.html" /><inpu
t type="hidden" class="panel_type" value="Content" /></div>);
  } 
  else {
    my $img_url = $hub->species_defs->img_url;

    my $blog = $MEMD && $MEMD->get('::BLOG') || '';
  
    unless ($blog) {
      my $ua = new LWP::UserAgent;
      my $proxy = $hub->species_defs->ENSEMBL_WWW_PROXY;
      $ua->proxy( 'http', $proxy ) if $proxy;
  
      my $response = $ua->get($blog_rss);

      my @items;
      my $count = 0;
        my $feed = XML::Atom::Feed->new(\$response->decoded_content);
        my @entries = $feed->entries;
        foreach my $entry (@entries) {
          my ($link) = grep { $_->rel eq 'alternate' } $entry->link;

	  #
	  # ::CHANGE:: wc2 changed date and removed the old rss section.
	  #

          #my $date  = $self->pretty_date(substr($entry->published, 0, 10), 'daymon');
	  my $date   = substr($entry->updated, 0, 10);
          my $item = {
            'title' => $entry->title,
            'link'  => $link->href,
            'date'  => $date,
            };
          push @items, $item;
          $count++;
          last if $count == 5;
        }

      if (@items) {
        $blog .= "<ul>";
        foreach my $item (@items) {
          my $title = $item->{'title'};
          my $link  = $item->{'link'};
          my $date = $item->{'date'} ? $item->{'date'}.': ' : '';
  
          $blog .= qq(<li>$date<a href="$link">$title</a></li>); 
        }
        $blog .= "</ul>";
      } 
      else {
        $blog .= qq(<p>Sorry, no feed is available from our blog at the moment</p>);
      }
  
      #
      # ::CHANGE:: wc2 edited to point to blog
      #

      $blog .= qq(<a href="$blog_url">Go to gEVAL blog &rarr;</a>);

      $MEMD->set('::BLOG', $blog, 3600, qw(STATIC BLOG))
      if $MEMD;
    }

    $html .= $blog;
  }
  return $html;
}

1;
