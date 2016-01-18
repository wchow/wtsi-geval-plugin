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

package EnsEMBL::Web::CompressionSupport;

###------------------------------------------------###
# If Bzip2 is required, uncomment the lines below.
###------------------------------------------------###

use strict;
use Compress::Zlib;
#use Compress::Bzip2;
#use IO::Uncompress::Bunzip2;

sub uncomp {
  my $content_ref = shift;
  if( ord($$content_ref) == 31 && ord(substr($$content_ref,1)) == 157 ) { ## COMPRESS...
    my $t = Compress::Zlib::uncompress($$content_ref);
    $$content_ref = $t;
  } elsif( ord($$content_ref) == 31 && ord(substr($$content_ref,1)) == 139 ) { ## GZIP...
    my $t = Compress::Zlib::memGunzip($$content_ref);
    $$content_ref = $t;
  } elsif( $$content_ref =~ /^BZh([1-9])1AY&SY/ ) {                            ## GZIP2
#    my $t = Compress::Bzip2::decompress($content_ref); ## Try to uncompress a 1.02 stream!
#    unless($t) {
#      my $T = $$content_ref;
##      my $status = IO::Uncompress::Bunzip2::bunzip2 \$T,\$t;            ## If this fails try a 1.03 stream!
#    }
#    $$content_ref = $t;
  }
  return;
}

1;
