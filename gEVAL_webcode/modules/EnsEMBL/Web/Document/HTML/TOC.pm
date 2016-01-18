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

package EnsEMBL::Web::Document::HTML::TOC;
### Generates table of contents for documentation (/info/)

use strict;
use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self              = shift;
  my $tree              = $ENSEMBL_WEB_REGISTRY->species_defs->STATIC_INFO;
  (my $location         = $ENV{'SCRIPT_NAME'}) =~ s/index\.html$//;
  my @toplevel_sections = map { ref $tree->{$_} eq 'HASH' ? $_ : () } keys %$tree;
  my %html              = ( left => '', middle => '', right => '' );
  my $column            = 'left';  

  my @section_order = sort {
    $tree->{$a}{'_order'} <=> $tree->{$b}{'_order'} ||
    $tree->{$a}{'_title'} cmp $tree->{$b}{'_title'} ||
    $tree->{$a}           cmp $tree->{$b}
  } @toplevel_sections;
  
  foreach my $dir (grep { !/^_/ && keys %{$tree->{$_}} } @section_order) {
    my $section      = $tree->{$dir};

    #
    # ::CHANGE:: wc2 changed the layouts of the columns sections.
    #

    if ($dir eq 'about') {
      $column = 'left';
    }
    elsif ($dir eq 'website') {
      $column = 'middle';
    }
    
    my $title        = $section->{'_title'} || ucfirst $dir;
    my @second_level = @{$self->create_links($section, ' style="font-weight:bold"')};

    #
    # ::ADD:: wc2 there are sections in ensembl that may confuse and/or irrelavent to PGP users and will be omitted.
    #
    next if ($title =~ /technical documentation/i);
    # ::
    
    $html{$column} .= qq{<div class="plain-box" style="margin:0 0 2%;padding:2%"><h2 class="first">$title</h2>\n};
    
    if (scalar @second_level) {
      $html{$column} .= '<ul>';
  
      foreach my $entry (@second_level) {
        my $link = $entry->{'link'};

	#
	# ::ADD:: wc2 there are sections in ensembl that may confuse and/or irrelavent to PGP users and will be omitted.
	#
	next if ($link =~ /API Data|Custom Tracks/i);
	# ::

        ## One more level!
        my $subsection  = $entry->{'key'};
        my @third_level = @{$self->create_links($subsection)};
        
        if (scalar @third_level && $link !~ /eHive/ && $link !~ /webcode/) {
          $link .= '<ul>';
          $link .= "<li>$_->{'link'}</li>\n" for @third_level;
          $link .= '</ul>';
        }

        $html{$column} .= "<li>$link</li>\n";
      }      
      
      $html{$column} .= '</ul>';
    }
    
    $html{$column} .= '</div>';
  }
  
  $html{$_} = qq{<div class="threecol-$_ widepage">$html{$_}</div>} for grep $html{$_}, keys %html;
  
  return qq{<div style="width:100%">
              $html{'left'}
              $html{'middle'}
              $html{'right'}
            </div>};
}

sub create_links {
  my ($self, $level, $style) = @_;
  my $links = [];
    
  ## Do we have subpages/dirs, or just metadata?
  my @sublevel = map { ref $level->{$_} eq 'HASH' ? $_ : () } keys %$level;
    
  if (scalar @sublevel) {
    my @sub_order = sort { 
      $level->{$a}{'_order'} <=> $level->{$b}{'_order'} ||
      $level->{$a}{'_title'} cmp $level->{$b}{'_title'} ||
      $level->{$a}           cmp $level->{$b}
    } @sublevel;
    
    foreach my $sub (grep { !/^_/ && keys %{$level->{$_}} } @sub_order) {
      my $pages = $level->{$sub};
      my $path  = $pages->{'_path'} || "$level->{'_path'}$sub";
      my $title = $pages->{'_title'} || ucfirst $sub;
  
      #
      # ::CHANGE:: wc2 added note to tutorials regarding ensembl tutorials.
      #
      my $href = qq(<a href="$path" title="$title"$style>$title</a>);
      $href    = $href. " (Not all apply to the PGP Viewer)" if ($title =~ /Tutorials/i);

      push @$links, { key => $pages, link => $href };
    }
  }

  return $links;
}

1;
