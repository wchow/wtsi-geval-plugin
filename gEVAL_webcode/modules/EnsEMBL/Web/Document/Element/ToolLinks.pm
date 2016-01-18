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

package EnsEMBL::Web::Document::Element::ToolLinks;
### Generates links to site tools - BLAST, help, login, etc (currently in masthead)

use strict;
use base qw(EnsEMBL::Web::Document::Element);

sub home    :lvalue { $_[0]{'home'};   }
sub blast   :lvalue { $_[0]{'blast'};   }
sub biomart :lvalue { $_[0]{'biomart'}; }
sub blog    :lvalue { $_[0]{'blog'};   }

sub init {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  
  $self->home    = $species_defs->ENSEMBL_BASE_URL;
  $self->blast   = $species_defs->ENSEMBL_BLAST_ENABLED;
  $self->biomart = $species_defs->ENSEMBL_MART_ENABLED;
  $self->blog    = $species_defs->ENSEMBL_BLOG_URL;
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $species = $hub->species;
     $species = !$species || $species eq 'Multi' || $species eq 'common' ? 'Multi' : $species;
  my @links; # = sprintf '<a class="constant" href="%s">Home</a>', $self->home;
  
  #
  # ::CHANGE:: wc2 updated some of the href to appropriate locations. (info/website/, also added acknowlegments)
  #
  
  push @links, qq{<a class="constant" href="/$species/blastview">BLAST/BLAT</a>} if $self->blast;
  push @links,   '<a class="constant" href="/info/website/tools.html">Tools</a>';
  push @links,   '<a class="constant" href="/info/website/help/">Help &amp; Documentation</a>';
  push @links,   '<a class="constant" href="'.$self->blog.'">Blog</a>'                  if $self->blog;
  push @links,   '<a class="constant" href="/info/about/index.html">About us</a>';
  push @links,   '<a class="constant modal_link" href="/Help/Mirrors">Mirrors</a>' if keys %{$hub->species_defs->ENSEMBL_MIRRORS || {}};

  my $last  = pop @links;
  my $tools = join '', map "<li>$_</li>", @links;
  
  return qq{
    <ul class="tools">$tools<li class="last">$last</li></ul>
    <div class="more">
      <a href="#">More <span class="arrow">&#9660;</span></a>
    </div>
  };
}

1;
