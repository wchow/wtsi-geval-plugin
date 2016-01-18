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

##---------------------------------##
## Location Generic Zmenu          ##
##  -last updated 11/13            ##
##    @wc2                         ##
##---------------------------------##

package EnsEMBL::Web::ZMenu::Location;
use strict;
use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;

  my $hub     = $self->hub;

  if ( ! $hub->param('mfid') ) {
    $self->content_non_misc_feature( );
    return;
  }

  my $name       = $hub->param('misc_feature_n');
  my $db_adaptor = $hub->database(lc $hub->param('db') || 'core');
  my $mf         = $db_adaptor->get_MiscFeatureAdaptor->fetch_by_dbID($hub->param('mfid')) if $hub->param('mfid');
  my $type       = $mf->get_all_MiscSets->[0]->code if ( $mf);
  my $caption    = "$type Menu";

  my $id         = $hub->param('mfid');
  my $db         = $hub->param('db')  || 'core';
  my $r          = $hub->param('r')   || undef;
  my $mfa        = $db_adaptor->get_MiscFeatureAdaptor();

  #--- General Location URL for all ---#
  my $url;
  $url = $hub->url({'type' => 'Location', 'action' => 'View', 'r' => $r}) if ( $r );

  my $sa          = $db_adaptor->get_SliceAdaptor();
  my $logic_name  = $hub->param('logic_name') if ( $hub->param('logic_name') );    

#----------------------------#  
#----- JIRA ENTRY ZMENU -----#
#----------------------------#
  if ( $type =~ /jira_entry/i ) {
    
    $caption = "JIRA entry";
    my $jira_summary       = $mf->get_scalar_attribute('jira_summary');
    my $jira_id            = $mf->get_scalar_attribute('jira_id');
    my $jira_status        = $mf->get_scalar_attribute('jira_status');
    my $jira_res           = $mf->get_scalar_attribute('jira_res');
    my $jira_res_text      = $mf->get_scalar_attribute('jira_res_text');
    my $jira_affVer        = $mf->get_scalar_attribute('jira_affect_ver');
    my $jira_fixVer        = $mf->get_scalar_attribute('jira_fix_ver');
    my $jira_assignedchr   = $mf->get_scalar_attribute('jira_assChr');
    my $jira_reportType    = $mf->get_scalar_attribute('jira_repType');
    my $jira_update        = $mf->get_scalar_attribute('jira_update');
    my $jira_maploc        = $mf->get_scalar_attribute('jira_maploc');
    
    
    my $dbid          = $mf->dbID();

    my $jiraSum_url   = $hub->url({'type' => 'Jira', 'action' => 'JiraSummary', 'id' => $dbid});
    my $ncbiJira_url  = "https://ncbijira.ncbi.nlm.nih.gov/browse/$jira_id";    

    $self->caption("$caption: $jira_id");   
    $self->add_entry({
      'type'      => 'Range',
      'label'     => $mf->seq_region_start.'-'.$mf->seq_region_end,
    });
    $self->add_entry({
      'type'      => 'Length',
      'label'     => $mf->seq_region_end - $mf->seq_region_start + 1,
    });
    $self->add_entry({
      'type'     => 'Summary',
      'label'    => $jira_summary,
    });
    $self->add_entry({
      'type'     => 'Status',
      'label'    => $jira_status,
    }) if ($jira_status);


    $self->add_entry({
      'type'  	 => "Resolution",
      'label'    => $jira_res,
    }) if ($jira_res);
    $self->add_entry({
      'type'  	 => "Resolution text",
      'label'    => $jira_res_text,
    }) if ($jira_res_text);
    $self->add_entry({
      'type'  	 => "Affect Version",
      'label'    => $jira_affVer,
    }) if ($jira_affVer);
    $self->add_entry({
      'type'  	 => "Fix Version",
      'label'    => $jira_fixVer,
    }) if ($jira_fixVer);
    $self->add_entry({
      'type'  	 => "Assigned Chr",
      'label'    => $jira_assignedchr,
    }) if ($jira_assignedchr);


    #Add links
    my @maplocations = split (",", $jira_maploc);
    (my $chr = $jira_assignedchr) =~ s/chr//;
    foreach my $map (@maplocations){
	my ($species, $start, $end) = ($map =~ /(\w+):(\d+)-(\d+)/); 
	my $uri = $hub->url({'species' => $species, 'type' => 'Location', 'action' => 'View', 'r' => "$chr:$start-$end"});       
	$self->add_entry({
	    'type'    => "Other Locations",
	    'label'   => $map,
	    'link'    => $uri,
			 }); 
    }

    $self->add_entry({
      'type'  	 => "Report Type",
      'label'    => $jira_reportType,
    }) if ($jira_reportType);
    $self->add_entry({
      'type'  	 => "Date",
      'label'    => $jira_update,
    }) if ($jira_update);

    $self->add_entry({
      'type'  	 => "JIRA Summary",
      'label'    => "JIRA Summary",
      'link'     => $jiraSum_url,
    });
    $self->add_entry({
      'type'     => "NCBI Report",	
      'label'    => "Login Req",
      'link'     => $ncbiJira_url,
    }); 
    $self->add_entry({
      'label'    => "Center on $caption",
      'link'     => $url,
    });
  }
#----------------------------#  
#----- Enz Digest ZMENU -----#
#----------------------------#			
  elsif ( $logic_name eq 'digest' ) {

      my $fragment_length = $mf->get_scalar_attribute('frag_length');

      $self->caption(ucfirst($type) ." digest fragment");
      $self->add_entry({
	'type'     => 'Fragment Length',
	'label'    => $fragment_length,
      });
  }
#---------------------------#  
#---- OM GAP/Frag ZMENU ----#
#---------------------------#     
  elsif ( $logic_name =~ /om_(gap|frag)|bnano_ctg/i){
      my $ctg_name        = $hub->param('om_ctg_name') || $mf->get_scalar_attribute('om_ctg_name') || $mf->get_scalar_attribute('sample_id');
      my $fragment_list   = $mf->get_scalar_attribute('om_gap_frag') || $mf->get_scalar_attribute('insert_frags') || $hub->param('fraglist');
      my $fragment_total  = $mf->get_scalar_attribute('om_gap_frag_num') ||  $mf->get_scalar_attribute('frag_num');

      $fragment_list =~ s/,/, /g if ($mf->get_scalar_attribute('om_gap_frag'));

      $self->caption(ucfirst($type) ."  fragment");
      $self->add_entry({
          'type'     => "Map ctg",
          'label'    => $ctg_name,
      });
      $self->add_entry({
          'type'     => 'xmap confidence',
          'label'    => $mf->get_scalar_attribute('xmap_confidence'),
      }) if ($mf->get_scalar_attribute('xmap_confidence'));
      $self->add_entry({
          'type'     => 'OM Fragments',
          'label'    => $fragment_total,
      }) if ($fragment_total);
      $self->add_entry({
          'type'     => 'Size List in View',
          'label'    => $fragment_list,
      }) if ($fragment_list);
      $self->add_entry({
          'type'     => 'Total gap Length',
          'label'    => $mf->get_scalar_attribute('frag_length'),
      }) if ($logic_name =~ /gap/i);

  }
#------------------------------------#  
#------- Pipeline Clone ZMENU -------#
#------------------------------------#     
  elsif ($type =~ /^(tpf_clone|active_non_tpf_clone|cancelled_non_tpf_clone|cancelled_non_tpf_clone_s)$/) {

    my $last_update_date     = $mf->get_scalar_attribute('last_proj_date');
    my $first_update_date    = $mf->get_scalar_attribute('first_proj_date');
    my $project_status       = $mf->get_scalar_attribute('project_status');
    my $sanger_name          = $mf->get_scalar_attribute('sanger_name');
    my $int_name             = $mf->get_scalar_attribute('int_name');
    my $repetitions          = $mf->get_scalar_attribute('repetitions');
    my $accession            = $mf->get_scalar_attribute('accession');
    my $version              = $mf->get_scalar_attribute('version');
    my @end_reads            = @{ $mf->get_all_attribute_values('end_read') };
    my @jira_ids             = @{ $mf->get_all_attribute_values('jira_id') };

    $self->caption($sanger_name);
    $self->add_entry({
      'type'     => 'Length',
      'label'    => $mf->seq_region_end - $mf->seq_region_start + 1,
    });
    $self->add_entry({
      'type'     => 'External name',
      'label'    => $int_name,
    }) if ( $int_name );
    $self->add_entry({
      'type'     => 'Status',
      'label'    => $project_status, 
    }) if ( $project_status );
    #--------------------------------#
    # print if clone sent for seq WC
    $self->add_entry({
      'type'     => 'Project Tracker',
      'label'    => "Link [internal]",
      'link'     => "http://intweb.sanger.ac.uk/cgi-bin/users/jgrg/project_status_summary?project=$sanger_name",
    }) if ( $project_status );
    #--------------------------------#   
    $self->add_entry({
      'type'     => 'First update',
      'label'    => $first_update_date, 
    }) if ( $first_update_date );
    $self->add_entry({
      'type'     => 'last update',
      'label'    => $last_update_date, 
    }) if ( $last_update_date );

    if(defined($repetitions) and $repetitions > 1) {
	foreach my $end_read (@end_reads) {
		my $read_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>'DnaAlignFeature','id'=>$end_read,'db'=>$db});
   		$self->add_entry({ 
    		  'label'    => "View all locations for $end_read",
    		  'link'     => $read_url,
		});
	}
    }
    foreach my $jira_id (@jira_ids) {
	my $jira_url = "https://ncbijira.ncbi.nlm.nih.gov/browse/$jira_id";
    	$self->add_entry({ 
    	  'label'    => "JIRA ticket $jira_id",
    	  'link'     => $jira_url,
    	});
    }
    if(defined($accession) and $accession =~ /\S/) {
	my $accession_sv  = "$accession.$version";
	my $accession_url = "http://www.ebi.ac.uk/ena/data/view/$accession_sv";
    	$self->add_entry({ 
    	  'label'    => "Accession $accession_sv",
    	  'link'     => $accession_url,
    	});
    }
    $self->add_entry({
      'label'        => "Center on $caption",
      'link'         => $url,
    });
  }

#------------------------------------#  
#------- Pipeline Clone ZMENU -------#
# wc2 added jan2013 for blacktags    #
#  error entries.                    #
#------------------------------------#
  elsif ($type eq "blacktags"){
      my $clone_name  = $mf->get_scalar_attribute('bt_clone') if ($mf->get_scalar_attribute('bt_clone'));
      my $description = $mf->get_scalar_attribute('bt_desc')  if ($mf->get_scalar_attribute('bt_desc'));
      my $clone_url   = $hub->url({'type' => 'Location', 'action' => 'View', 'region' => $clone_name, '__clear' => 1});

      $self->caption("BlackTag: $clone_name");
      $self->add_entry({
	  'type'     => "Desc:",
	  'label'    => $description,
      });
      $self->add_entry({
          'label'     => "Center on Clone",
          'link'      => $clone_url,
      });

  }
#-------------------------------------#  
#------- Everything else ZMENU -------#
#-------------------------------------#  
  else {
    $self->add_entry({
      'type'     => 'Length',
      'label'    => $hub->param('length') || $mf->length,
    });

    $self->caption( (ucfirst($caption)) );

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
		  ['jira_entry',     'JIRA'                   ],
		  ['description',    'Description'            ],

		  ['gffsource',      'Source'                 ],
		  ['gfftype',        'Type'                   ],
		  ['gffscore',       'Score'                  ],
		  ['gffphase',       'Phase'                  ],

	          ['gff_Name',       'gff_attrib Name'        ],
		  ['gff_ID',         'gff_attrib Id'          ],
		  ['gff_Alias',      'gff_attrib Alias'       ],
		  ['gff_Parent',     'gff_attrib Parent'      ],
		  ['gff_Target',     'gff_attrib Target'      ],
		  ['gff_Gap',        'gff_attrib Gap'         ],
		  ['gff_Derives_from',    'gff_attrib Derives From'         ],
		  ['gff_Note',       'gff_attrib Note'        ],
		  ['gff_Dbxref',     'gff_attrib DB Xref'     ],
		  ['gff_Ontology_term',   'gff_attrib Ontology Term'        ],
		  ['gff_SpanCount',   'gff_attrib SpanCount'   ],
		  ['group_items',     'Grouped Items'  ],
                  ['gff_partner',     'gff_partner',   "internal"    ],

		  ['bed_name', 'bed_attrib Name'        ],
                  ['bed_strand', 'bed_attrib strand'    ],

		  );
    my $group;	
    foreach my $name (@names) {
      next if (!($name->[0]));
      my $value = $hub->param($name->[0]) || $mf->get_scalar_attribute($name->[0]);
      my $entry;
      
      if ($value) {
	$entry = {'type' => $name->[1], 'label' => $value,};
	if ($name->[2]){
	  if ($name->[2] eq "internal") {
	    $entry->{'link'} = $hub->url({'type' => 'Location', 'action' => 'View', 'r' => $value, '__clear' => 1});
	    $self->add_entry($entry) if (!$group);
	  }
    	  else{
	    $entry->{'link'} = $hub->get_ExtURL($name->[2],$value);
            $self->add_entry($entry);
	  }
	}
	else {
	  $self->add_entry($entry);
	}

	if ($name->[0] eq "group_items"){
	  my @groupitems = split(",", $value);
	  $group =  1 if (@groupitems >1);
	}
      }
    }
    $self->add_entry({
      'label' => "Center on $caption $type $id",
      'link'   => $url,
    });
  }
}


#-------------------------------------------#
# This helps in determining the location of #
# unfinished clones as a misc Feature       #
# @wc2                                      #
#-------------------------------------------#
sub get_unfin_clone_coord {

    my ($mfa, $attrib_type, $hit_slice) = @_; # hit_slice is in clone level, in order to get all the contigs. 
    my ($misc_feat_start, $misc_feat_end);
    
    my @ctg_proj = @{$hit_slice->project('seq_level')};
    
    # -- order just in case
    @ctg_proj = (sort { $a->from_start <=> $b->from_start } @ctg_proj);
    my ($firstctg, $lastctg) = ($ctg_proj[0], $ctg_proj[-1]);

    my $first_name   = $firstctg->to_Slice->seq_region_name;
    my $last_name    = $lastctg->to_Slice->seq_region_name;
    my @first_feat   = @{$mfa->fetch_all_by_attribute_type_value($attrib_type, $first_name)};
    my @last_feat    = @{$mfa->fetch_all_by_attribute_type_value($attrib_type, $last_name)};
    
    if ($first_feat[0]->start < $last_feat[0]->start){
	die "ERROR: /Zmenu/Location.pm, sub-get_unfin_clone_coord \n" if ($first_feat[0]->strand ne 1);
	$misc_feat_start = $first_feat[0]->start;
	$misc_feat_end   = $last_feat[0]->end;
    }
    else {
	$misc_feat_start = $last_feat[0]->start;
	$misc_feat_end   = $first_feat[0]->start;
    }
    return ($misc_feat_start, $misc_feat_end);
}


# ---Ensembl Legacy code--- #
sub content_non_misc_feature {
  my $self = shift;

  
  my $hub           = $self->hub;
  my $species       = $hub->species;
  my $action        = $hub->action || 'View';
  my $r             = $hub->param('r');
  my $alt_assembly  = $hub->param('assembly'); # code for alternative assembly
  my $alt_clone     = $hub->param('jump_loc'); # code for alternative clones
  my $threshold     = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $this_assembly = $hub->species_defs->ASSEMBLY_NAME;
  my ($chr, $loc)   = split ':', $r;
  my ($start,$stop) = split '-', $loc;
  my $label         = $hub->param('label'); # added by wc2 for label info (ie chr bands) 


  # wc2: Added this so that assembly_exceptions don't go into to the content_contig call.
  return $self->content_contig() if ( $hub->param('region_n') && !$alt_assembly && !$alt_clone);
  #return $self->content_contig() if ( ! $alt_assembly && ! $alt_clone);

  # go to Overview if region too large for View
  $action = 'Overview' if ($stop - $start + 1 > $threshold) && $action eq 'View';
  
  my $url = $hub->url({
    type   => 'Location',
    action => $action
  });
  
  my ($caption, $link_title);
  
  if ($alt_assembly) { 
    my $l = $hub->param('new_r');
    
    $caption = $alt_assembly . ':' . $l;
    
    if ($this_assembly =~ /VEGA/) {
      $url = sprintf '%s%s/%s/%s?r=%s', $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'ENSEMBL'}, $species, 'Location', $action, $l;
      $link_title = 'Jump to Ensembl';
    } elsif ($alt_assembly =~ /VEGA/) {
      $url = sprintf '%s%s/%s/%s?r=%s', $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'VEGA'}, $species, 'Location', $action, $l;
      $link_title = 'Jump to VEGA';
    } else {
      # TODO: put URL to the latest archive site showing the other assembly (from mapping_session table)
    }
    
    $self->add_entry({ 
      label => "Assembly: $alt_assembly"
    });
  } elsif ($alt_clone) { 
    my $status = $hub->param('status');
    
    ($caption) = split ':', $alt_clone;
    
    if ($this_assembly eq 'VEGA') {
      $link_title = 'Jump to Ensembl';
      $url = sprintf '%s%s/%s/%s?r=%s', $hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'ENSEMBL'}, $species, 'Location', $action, $alt_clone;
    } else {
      $link_title = 'Jump to Vega';
      $url = sprintf '%s%s/%s/%s?r=%s', $hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'VEGA'}, $species, 'Location', $action, $alt_clone;
    }
    
    $status =~ s/_clone/ version/g;
    
    $self->add_entry({
      label => "Status: $status"
    });
  }

  
  $self->caption($caption || $label || $r);
  
  $self->add_entry({
    label => $link_title || $r,
    link  => $url
  });

 
  my $alternate_name = ${$hub->database('core')->get_SliceAdaptor->fetch_by_region('toplevel', $chr, $start, $stop)->get_all_synonyms}[0];

  # wc2 Assembly exceptions, for patches have synonyms on fpc_contig.  

  if ($hub->database('core')->get_SliceAdaptor->fetch_by_region('fpc_contig', $chr)){
      $alternate_name    = ${$hub->database('core')->get_SliceAdaptor->fetch_by_region('fpc_contig', $chr)->get_all_synonyms}[0] if (!$alternate_name);
  }
  
  $self->add_entry({
      type  => "Accession",
      label => $alternate_name->name,
      link  => "http://www.ncbi.nlm.nih.gov/nuccore/". $alternate_name->name,
  }) if ($alternate_name);

  my $assembly_excep_feat   = ${$hub->database('core')->get_SliceAdaptor->fetch_by_region('toplevel', $chr, $start, $stop)->get_all_AssemblyExceptionFeatures()}[0];

  # wc2 Assembly exceptions types.  
  if ($hub->database('core')->get_SliceAdaptor->fetch_by_region('fpc_contig', $chr)){
      $assembly_excep_feat      = ${$hub->database('core')->get_SliceAdaptor->fetch_by_region('fpc_contig', $chr)->get_all_AssemblyExceptionFeatures()}[0] if (!$assembly_excep_feat);
  }

  $self->add_entry({
      type  => "Type",
      label => $assembly_excep_feat->type,
  }) if ($assembly_excep_feat);

}

1;
