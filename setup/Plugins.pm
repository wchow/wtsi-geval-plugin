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


## If you wish to use the EnsEMBL web-code from the command line, you will
## need to hardcode the server root here 

## $SiteDefs::ENSEMBL_SERVERROOT = '/path to root of ensembl tree';

$SiteDefs::ENSEMBL_PLUGINS = [

   'EnsEMBL::gEVAL_ensembl'       => $SiteDefs::ENSEMBL_SERVERROOT.'/gEVAL_plugin/gEVAL_ensembl/',
   'EnsEMBL::gEVAL_webcode'       => $SiteDefs::ENSEMBL_SERVERROOT.'/gEVAL_plugin/gEVAL_webcode/',
   'EnsEMBL::Genoverse'  => $SiteDefs::ENSEMBL_SERVERROOT.'/public-plugins/genoverse',
  
];

1;
