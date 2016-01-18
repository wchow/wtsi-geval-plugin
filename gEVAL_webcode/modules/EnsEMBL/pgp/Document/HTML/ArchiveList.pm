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

package EnsEMBL::pgp::Document::HTML::ArchiveList;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

{

sub render {
  my ($class, $request) = @_;

  my $SD = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $species = $SD->ENSEMBL_PRIMARY_SPECIES;
  my %archive_info = %{$SD->ENSEMBL_ARCHIVES};
  my $html = qq(<h3 class="boxed">List of currently available archives</h3>
<ul class="spaced">);
  my $count = 0;

  foreach my $release (reverse sort keys %archive_info) {
    next if $release > $SD->ENSEMBL_VERSION; ## In case this is a dev site on a yet-to-be-released version
    my $subdomain = $archive_info{$release};
    (my $date = $subdomain) =~ s/20/ 20/; 
    $html .= qq(<li><strong><a href="http://$subdomain.archive.ensembl.org">Ensembl $release: $date</a>);
    $html .= ' - currently www.ensembl.org' if $release == $SD->ENSEMBL_VERSION;
    $html .= '</strong></li>';
    $count++;
  }

  $html .= "</ul>\n";

  $html .= qq(<p><a href="/info/website/archives/assembly.html">Table of archives showing assemblies present in each one</a>.</p>);

  return $html;
}

}

1;
