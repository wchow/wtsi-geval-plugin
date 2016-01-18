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

package EnsEMBL::Web::Document::HTML::WhatsNew;

### This module outputs a selection of news headlines from either 
### a static HTML file or a database (ensembl_website or ensembl_production) 
### If a blog URL is configured, it will also try to pull in the RSS feed

use strict;
use Encode          qw(encode_utf8 decode_utf8);
use HTML::Entities  qw(encode_entities);
use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::DBSQL::ProductionAdaptor;
use EnsEMBL::Web::Cache;
use base qw(EnsEMBL::Web::Document::HTML);

our $MEMD = EnsEMBL::Web::Cache->new(
  enable_compress    => 1,
  compress_threshold => 10_000,
);

sub render {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $html;

  my $release_id = $hub->param('id') || $hub->param('release_id') || $hub->species_defs->ENSEMBL_VERSION;
  return unless $release_id;

  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my $release      = $adaptor->fetch_release($release_id);
  my $release_date = $release->{'date'};
  my $html = qq{<img src="/i/geval_blog.png" style="height:35px;width:160px"\>} . qq{<h2 class="box-header">Latest News from the Blog</h2>};

  ## Are we using static news content output from a script?
  my $file         = '/ssi/whatsnew.html';
  my $include = EnsEMBL::Web::Controller::SSI::template_INCLUDE(undef, $file);
  if ($include) {
    ## Only use static page with current release!
    if ($release_id == $hub->species_defs->ENSEMBL_VERSION && $include) {
      $html .= $include;
    }
  }
  else {
    ## Return dynamic content from the ensembl_website database
    my $news_url     = '/info/website/news.html?id='.$release_id;
    my @items = ();

    my $first_production = $hub->species_defs->get_config('MULTI', 'FIRST_PRODUCTION_RELEASE');

    if ($hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}
        && $first_production && $release_id > $first_production) {
      ## TODO - implement way of selecting interesting news stories
      #my $p_adaptor = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);
      #if ($p_adaptor) {
      #  @items = @{$p_adaptor->fetch_changelog({'release' => $release_id, order_by => 'priority', limit => 5})};
      #}   
    }
    elsif ($hub->species_defs->multidb->{'DATABASE_WEBSITE'}{'NAME'}) { 
      @items    = @{$adaptor->fetch_news({ release => $release_id, order_by => 'priority', limit => 5 })};
    } 

    if (scalar @items > 0) {
      $html .= "<ul>\n";

      ## format news headlines
      foreach my $item (@items) {
        my @species = @{$item->{'species'}};
        my (@sp_ids, $sp_id, $sp_name, $sp_count);
      
        if (!scalar(@species) || !$species[0]) {
          $sp_name = 'all species';
        } 
        elsif (scalar(@species) > 5) {
          $sp_name = 'multiple species';
        } 
        else {
          my @names;
        
          foreach my $sp (@species) {
            if ($sp->{'common_name'} =~ /\./) {
              push @names, '<i>'.$sp->{'common_name'}.'</i>';
            } 
            else {
              push @names, $sp->{'common_name'};
            } 
          }
        
          $sp_name = join ', ', @names;
        }
      
        ## generate HTML
        $html .= qq|<li><strong><a href="$news_url#news_$item->{'id'}" style="text-decoration:none">$item->{'title'}</a></strong> ($sp_name)</li>\n|;
      }
      $html .= "</ul>\n";
    }
    else {
      $html .= "<p>";
    }
  }

  if ($species_defs->ENSEMBL_BLOG_URL) {
    $html .= $self->_include_blog($hub);
  }

  return $html;
}


sub _include_blog {
  my ($self, $hub) = @_;

  my $rss_url = $hub->species_defs->ENSEMBL_BLOG_RSS;

  my $html = '';

  my $blog_url  = $hub->species_defs->ENSEMBL_BLOG_URL;
  my $items = [];

  if ($MEMD && $MEMD->get('::BLOG')) {
    $items = $MEMD->get('::BLOG');
  }

  unless ($items && @$items) {
    $items = $self->get_rss_feed($hub, $rss_url, 3);

    ## encode items before caching, in case Wordpress has inserted any weird characters
    if ($items && @$items) {
      foreach (@$items) {
        while (my($k, $v) = each (%$_)) {
          $_->{$k} = encode_utf8($v);
        }
      }
      $MEMD->set('::BLOG', $items, 3600, qw(STATIC BLOG)) if $MEMD;
    }
  }

   if (scalar(@$items)) {
    $html .= "<ul>";
    foreach my $item (@$items) {
      my $title = $item->{'title'};
      my $link  = encode_entities($item->{'link'});
      my $date = $item->{'date'} ? $item->{'date'}.': ' : '';

      $html .= qq(<li>$date<a href="$link" class="nodeco">$title</a></li>);
    }
    $html .= "</ul>";
  }
  else {
    $html .= qq(<p>Sorry, no feed is available from our blog at the moment</p>);
  }

  $html .= qq(<p><a href="$blog_url" class="nodeco">Go to the gEVAL Browser blog &rarr;</a></p>);

  return $html;

}



1;
