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

package EnsEMBL::Web::ZMenu::Clone;
use strict;
use base qw(EnsEMBL::Web::ZMenu);

#--------------------------------#
#--------------------------------#
# Zmenu for Clones Glyph         #
#  Currently linked with the     #
#  pgp_clone.pm glyph            #
#  !! Update. Have added jt8's   #
#  Pipeline Clone Track to point #
#  to this                       #
#                                #
#   -wc2@sanger                  # 
#--------------------------------#
#--------------------------------#


#--------------------------------#
# Main Call for Content in Zmenu #
#--------------------------------#
sub content {
  my $self = shift;
  my $hub  = $self->hub;

  if ( ! $hub->param('mfid') ) {
    # Jump to the non_misc_feature callback.
    #   There shouldn't be any for the clone track, but will leave
    #   from legacy Location.pm just in case.	
    $self->content_non_misc_feature( );
    return;
  }

  my $name       = $hub->param('misc_feature_n');
  my $db_adaptor = $hub->database(lc $hub->param('db') || 'core');

  my $mfa        = $db_adaptor->get_MiscFeatureAdaptor;
  my $mf         = $mfa->fetch_by_dbID($hub->param('mfid')) if $hub->param('mfid');
  my $type       = $mf->get_all_MiscSets->[0]->code if ( $mf);
  my $caption    = 'Clone';

  my $id         = $hub->param('mfid');
  my $db         = $hub->param('db')  || 'core';
  my $species    = $hub->param('species');
  my $r          = $hub->param('r')   || undef;
  my $hitname    =  $hub->param('hitname');

  my $url         = ($r) ? $hub->url({'type' => 'Location', 'action' => 'View', 'r' => $r, 'db' => $db, 'species' => $species, __clear => 1}) : undef ;
  my $sa          = $db_adaptor->get_SliceAdaptor();
  my $logic_name  = $hub->param('logic_name') if ( $hub->param('logic_name') );    


  ## Primarly for this module zmenus were designed for the Clone Track, however it has been adapted for 
  ##  jt8's pipeline tracks as well.	  
  if ($type eq 'clone' || $type eq 'clones') {

    my $internal_name = $mf->get_scalar_attribute('internal_clone');
    my $external_name = $mf->get_scalar_attribute('external_clone');
    my $status        = $mf->get_scalar_attribute('clone_status');
    my $coverage      = $mf->get_scalar_attribute('dh_coverage');

    #edited by WC to include unfin ctg info.
    my $displayname = $name || $internal_name;
    my $ctg_list    = $hub->param('unfin_ctgs');
    my $length      = $hub->param('length');
    my $ctg_num     = $hub->param('ctg_num');

    ########
    # Deprecated: ILLUMINA; WC 111309
    my $poolclone_list = $hub->param('pool_clones');
    ########

    my $long_status;
    $long_status = "Finished"   if ( $status && $status eq "F");
    $long_status = "Unfinished" if ( $status && $status eq "U");
    $long_status = "Assembled"  if ( $status && $status eq "A");
    $long_status = $status      if ( $status && ! $long_status );

    $caption = ucfirst($type);
    $internal_name =~ s/_Contig.*//;
    $self->caption("$caption: $hitname");


    ## --- Begin Add Entries to Zmenu ---##
    
    ## Clone/Obj Range.		
    $self->add_entry({
      'type'     => 'range',
      'label'    => $r || $mf->seq_region_start.'-'.$mf->seq_region_end,
      'priority' => 100,
    });

    ## Clone/Obj Length.	
    $self->add_entry({
      'type'     => 'length', 
      'label'    => $length." bp, $species"   || $mf->seq_region_end - $mf->seq_region_start + 1,
      'priority' => 90,
    });

    ## Clone/Obj External Name.
    $self->add_entry({
      'type'     => 'external name',
      'label'    => $external_name,
      'priority' => 80,
    }) if ( $external_name );

    ## Clone/Obj Pipeline Status
    $self->add_entry({
      'type'     => 'status',
      'label'    => $long_status, 
      'priority' => 70,
    }) if ( $status );

    ## Internal Sanger Project Status Tracking Linki
    ## Sanger Web/pipelines have discontinued this service.	
#    $self->add_entry({
#	'type'     => 'project tracker',
#	'label'    => "link (internal)",
#	'link'     => "http://intweb.sanger.ac.uk/cgi-bin/users/jgrg/project_status_summary?project=$displayname",
#	'priority' => 69,
#    }) if ( $status );

    ## HTGS Phase.  Currently available for Zfish.  When human and mouse is added,
    ##   this would be best served via a hub->param call for the data from the glyph call
    ##   then to call it from the slice here.  Compara doesn't like to use the real slice
    ##   from the species in question, but uses query specie. 
    my $clone_slice = $sa->fetch_by_region('clone', $name);
    if ($clone_slice){
	my ($htgs_phase) = @{$clone_slice->get_all_Attributes('htgs_phase')};
	$self->add_entry({
	    'type'     => 'htgs phase',
	    'label'    =>  $htgs_phase->value,
	    'priority' => 68,
	}) if ($htgs_phase);
    }

    ## Double Haploid Coverage.  Zebrafish only.
    $self->add_entry({
      'type'     => 'DH coverage',
      'label'    => $coverage,
      'priority' => 60,
    }) if ( $coverage );

    ## Deprecated: ILLUMINA WC 111309
    $self->add_entry({
	'type'     => 'pool clones in view',
	'label'    => $poolclone_list,
	'priority' => 59,
    }) if ( $poolclone_list );

    #Deprecated: ILLUMINA WC 111309
    my @poolclones=undef;
    @poolclones = split(",", $poolclone_list) if ($poolclone_list);
    if (($poolclone_list) && (@poolclones <2)){
        $self->caption("$caption: $poolclones[0]");
    }

    ## Unfinished clone's contig information entries.  
    $self->add_entry({
	'type'     => 'ctgs in view',
	'label'    => $ctg_list,
	'priority' => 50,
    }) if ( $ctg_list );
    $self->add_entry({
	'type'     => 'total # of ctgs',
	'label'    => $ctg_num,
	'priority' => 49,
    }) if ( $ctg_list );
    
    ## Used to centre on unfin clone on misc feature.
    if ($ctg_list && $clone_slice){
	my $unfin_region;
	my @chr_proj    = @{$clone_slice->project('chromosome')};
	my $chr         = $chr_proj[0]->to_Slice->seq_region_name;
	my $attrib_code = "internal_clone";

	my ($unfin_start, $unfin_end) = &get_unfin_clone_coord($mfa, $attrib_code, $clone_slice);

	$unfin_region   = "$chr:$unfin_start-$unfin_end";
	$url            = $hub->url({'type' => 'Location', 'action' => 'View', 'r' => $unfin_region, 'species' => $species, __clear => 1});
    }
    $self->add_entry({
      'label'    => "Center on $caption",
      'link'     => $url,
      'priority' => 10,
    });


  }

  ## jt8 added for clonepipeline status.
  elsif ($type =~ /^(tpf_clone|active_non_tpf_clone|cancelled_non_tpf_clone|cancelled_non_tpf_clone_s)$/) {

    my $last_update_date = $mf->get_scalar_attribute('last_proj_date');
    my $first_update_date = $mf->get_scalar_attribute('first_proj_date');
    my $project_status = $mf->get_scalar_attribute('project_status');
    my $sanger_name = $mf->get_scalar_attribute('sanger_name');
    my $int_name        = $mf->get_scalar_attribute('int_name');
	my $repetitions = $mf->get_scalar_attribute('repetitions');
	my $accession = $mf->get_scalar_attribute('accession');
	my $version = $mf->get_scalar_attribute('version');
	my @end_reads = @{ $mf->get_all_attribute_values('end_read') };
	my @jira_ids = @{ $mf->get_all_attribute_values('jira_id') };

    $self->caption($sanger_name);

    $self->add_entry({
      'type' => 'length',
      'label' => $mf->seq_region_end - $mf->seq_region_start + 1,
      'priority' => 90,
    });

    $self->add_entry({
      'type' => 'external name',
      'label' => $int_name,
      'priority' => 80,
    }) if ( $int_name );

    $self->add_entry({
      'type' => 'status',
      'label' => $project_status, 
      'priority' => 75,
    }) if ( $project_status );

    #################
    #print if clone sent for seq WC
    $self->add_entry({
	'type' => 'project tracker',
	'label' => "link",
	'link' => "http://intweb.sanger.ac.uk/cgi-bin/users/jgrg/project_status_summary?project=$sanger_name",
	'priority' => 69,
    }) if ( $project_status );
    #################
    
    $self->add_entry({
      'type' => 'first update',
      'label' => $first_update_date, 
      'priority' => 74,
    }) if ( $first_update_date );
	
    $self->add_entry({
      'type' => 'last update',
      'label' => $last_update_date, 
      'priority' => 73,
    }) if ( $last_update_date );

	if(defined($repetitions) and $repetitions > 1) {
		foreach my $end_read (@end_reads) {
			my $read_url = $hub->url({'type'=>'Location','action'=>'Genome','ftype'=>'DnaAlignFeature','id'=>$end_read,'db'=>$db});
    		$self->add_entry({ 
    		  'label' => "View all locations for $end_read",
    		  'link'   => $read_url,
    		  'priority' => 15,
    		});
		}
	}
	
	foreach my $jira_id (@jira_ids) {
		my $jira_url = "https://ncbijira.ncbi.nlm.nih.gov/browse/$jira_id";
    	$self->add_entry({ 
    	  'label' => "JIRA ticket $jira_id",
    	  'link'   => $jira_url,
    	  'priority' => 14,
    	});
	}

	if(defined($accession) and $accession =~ /\S/) {
		my $accession_sv = "$accession.$version";
		my $accession_url = "http://www.ebi.ac.uk/ena/data/view/$accession_sv";
    	$self->add_entry({ 
    	  'label' => "Accession $accession_sv",
    	  'link'   => $accession_url,
    	  'priority' => 13,
    	});
	}

    $self->add_entry({
      'label'    => "Center on $caption",
      'link'     => $url,
      'priority' => 10,
    });

  }

  ## DEFAULT Zmenu.
  else {
	
    $self->caption("$type:$hitname");
    $self->add_entry({
      'type'     => 'length',
      'label'    => $mf->length.' bps',
      'priority' => 180,
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
		  ['jira_entry',     'JIRA'                   ],
		  ['description',    'Description'            ],
		  );
    
    my $priority = 170;
    foreach my $name (@names) {
      next if (!($name->[0]));
      my $value = $mf->get_scalar_attribute($name->[0]);
      my $entry;
      
      #hacks for these type of entries
      if ($name->[0] eq 'BACend_flag') {
	$value = ('Interpolated', 'Start located', 'End located', 'Both ends located') [$value]; 
      }
      if ($name->[0] eq 'synonym') {
	$value = "http://www.sanger.ac.uk/cgi-bin/humace/clone_status?clone_name=$value" if $mf->get_scalar_attribute('organisation') eq 'SC';
      }
      if ($value) {
	$entry = {
	  'type'     => $name->[1],
	  'label'    => $value,
	  'priority' => $priority,};
	if ($name->[2]) {
	  $entry->{'link'} = $hub->get_ExtURL($name->[2],$value);
	}
	$self->add_entry($entry);
	$priority--;
      }
    }
    
    $self->add_entry({
      'label' => "Center on $caption $type $hitname",
      'link'   => $url,
      'priority' => $priority,
    });
  }
}




#---------------------------------#
#  -get_unfin_clone_coord:        #
# This helps in determining the   #
# location of unfinished clones   # 
# as a misc Feature.              #    
#   added by WC                   #
#---------------------------------#
sub get_unfin_clone_coord {
 
    my ($mfa, $attrib_type, $hit_slice) = @_; # hit_slice is in clone level, in order to get all the contigs.
    
    my ($misc_feat_start, $misc_feat_end);
    my @ctg_proj = @{$hit_slice->project('contig')};
    
    ## order just in case
    @ctg_proj = (sort {  $a->from_start <=> $b->from_start } @ctg_proj);
    my ($firstctg, $lastctg) = ($ctg_proj[0], $ctg_proj[-1]);
#    warn "first: ", $firstctg->to_Slice->seq_region_name, "\n";
#    warn "second:", $lastctg->to_Slice->seq_region_name, "\n";
    my $first_name    = $firstctg->to_Slice->seq_region_name;
    my $last_name     = $lastctg->to_Slice->seq_region_name;
    my @first_feat    = @{$mfa->fetch_all_by_attribute_type_value($attrib_type, $first_name)};
    my @last_feat     = @{$mfa->fetch_all_by_attribute_type_value($attrib_type, $last_name)};
    
    if ($first_feat[0]->start < $last_feat[0]->start){
	warn "WARNING: Result should be in strand plus for clones at $first_name and $last_name.\n" if ($first_feat[0]->strand ne 1);
	$misc_feat_start   = $first_feat[0]->start;
	$misc_feat_end     = $last_feat[0]->end;
    }
    else {
	$misc_feat_start = $last_feat[0]->start;
	$misc_feat_end   = $first_feat[0]->start;
    }

    return ($misc_feat_start, $misc_feat_end);
}


#########################################
# Note:
#  The following are leftover calls that
#  would only be called if the object is
#  not a misc_feature.  I have kept them
#  around though, I doubt it will be
#  called, but just in case. @wc2 
#########################################

sub content_contig {
  my $self = shift;

  my $hub             = $self->hub;
  my $threshold       = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $slice_name      = $hub->param('region_n');
  my $db_adaptor      = $hub->database('core');
  my $slice           = $db_adaptor->get_SliceAdaptor->fetch_by_region('seqlevel', $slice_name);
  my $slice_type      = $slice->coord_system_name;
  my $top_level_slice = $slice->project('toplevel')->[0]->to_Slice;
  my $action          = $slice->length > $threshold ? 'Overview' : 'View';
  
  $self->caption($slice_name);
  
  $self->add_entry({
    label => "Center on $slice_type $slice_name",
    link  => $hub->url({ 
      type   => 'Location', 
      action => $action, 
      region => $slice_name 
    })
  });
  
  $self->add_entry({
    label      => "Export $slice_type sequence/features",
    link_class => 'modal_link',
    link       => $hub->url({ 
      type   => 'Export',
      action => "Location/$action",
      r      => sprintf '%s:%s-%s', map $top_level_slice->$_, qw(seq_region_name start end)
    })
  });
  
  foreach my $cs (@{$db_adaptor->get_CoordSystemAdaptor->fetch_all || []}) {
    next if $cs->name eq $slice_type;  # don't show the slice coord system twice
    next if $cs->name eq 'chromosome'; # don't allow breaking of site by exporting all chromosome features
    
    my $path;
    eval { $path = $slice->project($cs->name); };
    
    next unless $path && scalar @$path == 1;

    my $new_slice        = $path->[0]->to_Slice->seq_region_Slice;
    my $new_slice_type   = $new_slice->coord_system_name;
    my $new_slice_name   = $new_slice->seq_region_name;
    my $new_slice_length = $new_slice->seq_region_length;

    $action = $new_slice_length > $threshold ? 'Overview' : 'View';
    
    $self->add_entry({
      label => "Center on $new_slice_type $new_slice_name",
      link  => $hub->url({
        type   => 'Location', 
        action => $action, 
        region => $new_slice_name
      })
    });
    # would be nice if exportview could work with the region parameter, either in the referer or in the real URL
    # since it doesn't we have to explicitly calculate the locations of all regions on top level
    $top_level_slice = $new_slice->project('toplevel')->[0]->to_Slice;

    $self->add_entry({
      label      => "Export $new_slice_type sequence/features",
      link_class => 'modal_link',
      link       => $hub->url({
        type   => 'Export',
        action => "Location/$action",
        r      => sprintf '%s:%s-%s', map $top_level_slice->$_, qw(seq_region_name start end)
      })
    });

    if ($cs->name eq 'clone') {

      my $accession = $new_slice->get_all_Attributes('accession');
      my $version    = $new_slice->get_all_Attributes('version');
      #$new_slice_name = $$accession[0]->value if ( $accession && $$accession[0]);
      if ($accession && $$accession[0]) {
	  $new_slice_name = ($$accession[0]->value) ? $$accession[0]->value : $slice_name;
	  $new_slice_name .= "." . $$version[0]->value if ($$accession[0] && $version && $$version[0]);
      }

      (my $short_name = $new_slice_name) =~ s/\.\d+$//;

      
      $self->add_entry({
        type  => 'EMBL',
        label => $new_slice_name,
        link  => $hub->get_ExtURL('EMBL', $new_slice_name),
        extra => { external => 1 }
      });
      
      $self->add_entry({
        type  => 'EMBL (latest version)',
        label => $short_name,
        link  => $hub->get_ExtURL('EMBL', $short_name),
        extra => { external => 1 }
      });
    }
  }
}


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

  $self->caption($caption || $r);
  
  $self->add_entry({
    label => $link_title || $r,
    link  => $url
  });

  
  my $alternate_name = ${$hub->database('core')->get_SliceAdaptor->fetch_by_region('toplevel', $chr, $start, $stop)->get_all_synonyms}[0];

  # wc2 Assembly exceptions, for patches have synonyms on fpc_contig.  
  $alternate_name    = ${$hub->database('core')->get_SliceAdaptor->fetch_by_region('fpc_contig', $chr)->get_all_synonyms}[0] if (!$alternate_name);

  
  $self->add_entry({
      type  => "Accession",
      label => $alternate_name->name,
      link  => "http://www.ncbi.nlm.nih.gov/nuccore/". $alternate_name->name,
  }) if ($alternate_name);

  my $assembly_excep_feat   = ${$hub->database('core')->get_SliceAdaptor->fetch_by_region('toplevel', $chr, $start, $stop)->get_all_AssemblyExceptionFeatures()}[0];

  # wc2 Assembly exceptions types.  
  $assembly_excep_feat      = ${$hub->database('core')->get_SliceAdaptor->fetch_by_region('fpc_contig', $chr)->get_all_AssemblyExceptionFeatures()}[0] if (!$assembly_excep_feat);

  $self->add_entry({
      type  => "Type",
      label => $assembly_excep_feat->type,
  }) if ($assembly_excep_feat);

}

1;
