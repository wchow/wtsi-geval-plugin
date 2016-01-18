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

package EnsEMBL::Web::ZMenu::MiscFeature;
use strict;
use base qw(EnsEMBL::Web::ZMenu);

#----------------------------------------#
# Generic zmenu for Miscfeatures.
#   Doesn't matter what it is, it will
#   fetch the misc_attribs and load it
#   per code-value in the menu
#
#   depending on glyph code, can take 
#   mfid and use feature to fetch data or
#   fetch via param calls.
#
# wc2@sanger
#----------------------------------------#


sub content {
  my $self       = shift;
  my $hub        = $self->hub;
											       
  #--- Generic Params ---#
  my $id          = $hub->param('mfid');
  my $db          = $hub->param('db')            || 'core';
  my $r           = $hub->param('r')             || undef;
  my $set_code    = $hub->param('set_code')      || undef;
  my $logic_name  = $hub->param('logic_name')    || undef;    

  my $db_adaptor = $hub->database(lc $db);
  my $mfa        = $db_adaptor->get_MiscFeatureAdaptor();
  my $sa         = $db_adaptor->get_SliceAdaptor();
  my $mf         = ($hub->param('mfid')) ? $mfa->fetch_by_dbID($hub->param('mfid')) : undef;
  
  my $caption;
  my $url;
  $url = $hub->url({'type' => 'Location', 'action' => 'View', 'r' => $r}) if ( $r );

  #--- Fetch all the misc_attrib types ---#
  if ($mf) {

      my $misc_name = @{$mf->get_all_MiscSets($set_code)}[0]->name;

      $self->caption($misc_name || $set_code);
      my @attribs  =@ {$mf->get_all_Attributes()};
   
      foreach my $attrib (@attribs){
	  my $code     = $attrib->code();
	  my $value    = $attrib->value() || "Aiya no value here!";      

	  $self->add_entry({     'type'  => $code,
				 'label' => $value
			   });
      }
  }
  # Legacy stuff if no misc_set is sent here.
  else { 
      $self->caption($set_code);
	    
      $self->add_entry({ 'type' => 'length',
			 'label' => $mf->length.' bps',
		       });
      
    #add entries for each of the following attributes
    my @names = ( 
		  ['name',           'Name'                   ],
		  ['well_name',      'Well name'              ],
		  ['sanger_project', 'Sanger project'         ],
		  ['clone_name',     'Library name'           ],
		  ['synonym',        'Synonym'                ],
		  ['embl_acc',       'EMBL accession', 'EMBL' ],
		  ['bacend',         'BAC end acc',    'EMBL' ],
		  ['bac',            'AGP clones'             ],
		  ['alt_well_name',  'Well name'              ],
		  ['bacend_well_nam','BAC end well'           ],
		  ['state',          'State'                  ],
		  ['htg',            'HTGS_phase'             ],
		  ['remark',         'Remark'                 ],
		  ['organisation',   'Organisation'           ],
		  ['seq_len',        'Seq length'             ],
		  ['fp_size',        'FP length'              ],
		  ['supercontig',    'Super contig'           ],
		  ['fish',           'FISH'                   ],
		  ['jira_id',        'JIRA ID'                ],
		  ['jira_status',    'JIRA Status'            ],
		  ['jira_summary',   'JIRA Summary'           ],
		  ['description',    'Description'            ],
       		  ['AF',             'AF'                     ],
		  ['ME info',        'ME Info'                ],
		  ['SV type',        'SV Type'                ],
		  ['TSD',            'Target Site Dup'        ],
		  ['frag_length',    'Frag Length'            ],
		  );
    
    foreach my $name (@names) {
      my $value = $mf->get_scalar_attribute($name->[0]);
      my $entry;

      if ($name->[0] eq 'synonym') {
	$value = "http://www.sanger.ac.uk/cgi-bin/humace/clone_status?clone_name=$value" if $mf->get_scalar_attribute('organisation') eq 'SC';
      }
      if ($value) {
	  $entry = { 'type'     => $name->[1],
		     'label'    => $value,
	  };
	  if ($name->[2]) {
	      $entry->{'link'} = $hub->get_ExtURL($name->[2],$value);
	  }
	  $self->add_entry($entry);
      }
    }
      
      $self->add_entry({  'label'  => "Center on $caption $id",
			  'link'   => $url,
		       });
      
  }

}


1;
