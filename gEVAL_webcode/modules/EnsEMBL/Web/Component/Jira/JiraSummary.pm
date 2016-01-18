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

package EnsEMBL::pgp::Web::Component::Jira::JiraSummary; 
use strict;
use warnings;
no warnings "uninitialized";
use Time::HiRes qw(time);
use EnsEMBL::Web::Object;
use base qw(EnsEMBL::Web::Component);

#----------------------------------#
# This module is for creating a 
# Jira Menu that summarizes the
# evidence/data in the region of
# ticket.
#
#  	wc2@sanger.ac.uk
#----------------------------------#



sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}



#------------------------------------#
# content
#  The main code will producing the
#  page that you see on the website
#  currently consists of sections:
#  • General  • Region Details
#  • Gene/Cdna   • Blacktags
#  • Punchlists   • Clone Ends
#  • Compara   • Markers
#
#  All follows the framework of :
#   Fetch Data->Manipulate->
#   Create Row/Col->Write HTML Table
#------------------------------------#
sub content{

  my $self        = shift;
  my $hub         = $self->hub;
  my $url         = $hub->url();
 
  my $comparacheck = $hub->param('compara')  || undef; 
  my $endclone     = $hub->param('endclone') || undef;
  my $jiraid = $hub->param('jiraid') || undef;
  my $dbid   = $hub->param('id') || undef;

  #---- Just in case catch those who try to acccess not from direct link ----#
  if  (!$dbid){
	return "<H1>JiraID required to access this page</H1>";
  } 	

  #-----Setup Adaptors-----#
  my $mfa   = $self->hub->database('core')->get_MiscFeatureAdaptor();
  my $sa    = $self->hub->database('core')->get_SliceAdaptor();
  my $aa    = $self->hub->database('core')->get_AnalysisAdaptor();
  my $dafa  = $self->hub->database('core')->get_DnaAlignFeatureAdaptor();
  my $csa   = $self->hub->database('core')->get_CoordSystemAdaptor();

  use Bio::EnsEMBL::DBSQL::PunchTypeAdaptor;
  Bio::EnsEMBL::DBSQL::PunchTypeAdaptor->init( $self->hub->species_defs->valid_species() );
  use Bio::EnsEMBL::DBSQL::PunchAdaptor;
  Bio::EnsEMBL::DBSQL::PunchAdaptor->init( $self->hub->species_defs->valid_species() );
  
  my $pta =  $self->hub->database('core')->get_PunchTypeAdaptor();
  my $pa  =  $self->hub->database('core')->get_PunchAdaptor();

  my $species    = $hub->species_defs->SPECIES_PRODUCTION_NAME;
  my $hr_divider = "<br><br><hr>";	



  #------ General Information Table -------#
  my $jiraFeat   = $mfa->fetch_by_dbID($dbid);	
  
  if (!$jiraFeat){
	return "<H1>Jira Ticket can't be found, please report issue\n";
  }

  $jiraid          = $jiraFeat->get_first_scalar_attribute('jira_id') if (!$jiraid);
  my $jira_summary = $jiraFeat->get_first_scalar_attribute('jira_summary');
  my $jira_status  = $jiraFeat->get_first_scalar_attribute('jira_status');
  my $region       = $jiraFeat->seq_region_name().":". $jiraFeat->start()."-".$jiraFeat->end();
  my $region_url   = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region });
  my $region_entry = qq(<a href=$region_url>$region</a>);

  my $html = "<H1><u>Ticket ID:</u> $jiraid</H1>";

  my @columns = ( 
	           { key => 'type',            sort => 'string',   title => 'Type'       },
                   { key => 'data',            sort => 'string',   title => 'Data'       },
                );
  my @rows  = ( { 'type'=>'Jira Summary', 'data'=>$jira_summary },
		{ 'type'=>'Jira Status', 'data'=>$jira_status },
 	        { 'type'=>'Chr', 'data'=>$jiraFeat->seq_region_name() },
	        { 'type'=>'Region', 'data'=>$region_entry },
		{ 'type'=>'GRC Issue Report', 'data'=>"<a href='http://www.ncbi.nlm.nih.gov/projects/genome/assembly/grc/issue_detail.cgi?ID=".$jiraid."'>External Link</a>"},
		{ 'type'=>'NCBI JIRA', 'data'=>"<a href='https://ncbijira.ncbi.nlm.nih.gov/browse/".$jiraid."'>External Link</a> <i>[requires login]</i>" },
	      );
  my $table = $self->new_table(\@columns, \@rows, {
         data_table        => 0,
         margin            => '0.5em 0px',
	 width             => '65%',
         exportable        => 0
  });

  ## Note: the table is not written yet into html until below (Region table part) to check to see if there are gap fillers ##





  #-------Region Related Data Table--------#

  ## -- This Slice will be used in other tables as well below.
  my $current_slice = $jiraFeat->feature_Slice();

  ## -- What clones are involed in this ticket region. ie the components -- ##
  my @components = map {$_->to_Slice->seq_region_name} @{$current_slice->project('seqlevel')};

  my @cmp_columns   = ( {'key'=>'name',    'title'=>'Component Name'},
		     	{'key'=>'acc',     'title'=>'Accession'},
			{'key'=>'ver',     'title'=>'Version'},
			{'key'=>'htgs',    'title'=>'HTGS Phase'},
			{'key'=>'intname', 'title'=>'International Name'},
			{'key'=>'status',  'title'=>'Status'},
			{'key'=>'scaf',    'title'=>'FPC/Scaffold'},
			);

  my @cmp_rows;
  foreach my $cmp (@components){
        my $cmpurl = $hub->url({'type'=>'Location', 'action'=>'View','region'=>$cmp});

        my $attrib_ref = &name2att($cmp, $sa, $csa);

        my $acc     = $$attrib_ref{'acc'}     || "unavailable";
        my $ver     = $$attrib_ref{'ver'}     || "unavailable";
        my $htgs    = $$attrib_ref{'htgs'}    || "unavailable";
        my $intname = $$attrib_ref{'intname'} || "unavailable";
        my $status  = $$attrib_ref{'status'}  || "unavailable";
        my $scaf    = $$attrib_ref{'scaf'}    || "unavailable";

 	my $acc_url = "<a href ='http://www.ebi.ac.uk/ena/data/view/$acc'>$acc</a>";
	push @cmp_rows, {   'name'        =>  "<a href=$cmpurl>$cmp</a>",
		      	    'acc'         =>  $acc_url,
		            'ver'         =>  $ver,
		            'htgs'        =>  $htgs,
		            'intname'     =>  $intname,
		            'status'      =>  $status,
		            'scaf'        =>  $scaf
		};	  
  }  

  my $cmp_table = $self->new_table(\@cmp_columns, \@cmp_rows, {
         data_table        => 0,
         margin            => '0.5em 0px',
         width             => '90%',
         exportable        => 0
  });
 

 
  ## -- What Scaffolds are involved -- ##
  my $proj_cs;
  if ($csa->fetch_by_name('fpc_contig')){
       $proj_cs    =  "fpc_contig";
  }
  elsif ($csa->fetch_by_name('scaffold')){
       $proj_cs    =  "scaffold";
  }
  elsif ($csa->fetch_by_name('supercontig')){
       $proj_cs    =  "supercontig";
  }

  my $fpc_proj = $current_slice->project($proj_cs);   
  my @fpcs;
  if ($fpc_proj){
     @fpcs   = map {$_->to_Slice->seq_region_name} @$fpc_proj;
  }
    

  ## -- Fetch other tickets in region. -- ##
  my $range = 10000;
  my $newslice = $sa->fetch_by_region('toplevel', $current_slice->seq_region_name,
						  ($current_slice->start - $range < 1) ? 0 : ($current_slice->start - $range),
						  ($current_slice->end + $range > $current_slice->seq_region_length()) ? $current_slice->seq_region_length() : ($current_slice->end + $range)
        			     );

  my @otherticIds = map {$_->get_scalar_attribute('jira_id')."&nbsp&nbsp&nbsp&nbsp".
			 $_->get_scalar_attribute('jira_status')."&nbsp&nbsp&nbsp&nbsp".
			 #( length($_->get_scalar_attribute('jira_summary')) > 40 ) ? substr($_->get_scalar_attribute('jira_summary'), 0, 40)."..." : substr($_->get_scalar_attribute('jira_summary'), 0, 40) 
			substr($_->get_scalar_attribute('jira_summary'), 0, 80) if ($_->get_scalar_attribute('jira_id') !~/$jiraid/)
			} @{$newslice->get_all_MiscFeatures('jira_entry')};

  @otherticIds = sort {$b cmp $a} @otherticIds;	

  ## --- Add Overlap data in Region--- ##
  
  my @olfeats = @{$current_slice->get_all_DnaAlignFeatures('clone_overlap')};

  my $falsegaps = 0;
  my $ol_table  = undef;  	
  if (@olfeats > 0){
	my @ol_columns = (   { 'key'=>'hname',     'sort'=>'string',    'title'=>'Overlap(s)'},
			     { 'key'=>'length',    'sort'=>'numeric',   'title'=>'Length'},
			     { 'key'=>'perc',      'sort'=>'numeric',   'title'=>'PercentID (EPIC)'},
			     { 'key'=>'b2s',       'sort'=>'string',    'title'=>'Blast2seq'},
			 );
	my @ol_rows;

	foreach my $olf (@olfeats){
		my $olname    = $olf->hseqname();
		if ($olname =~ /false/i){
			$falsegaps++;
			next;
		}
		my ($query, $target) = ($olname =~ /(.*)\s+with\s+(.*)/);

		#--zfish uses intname in the seq_region--#
		if ($species =~ /zfish/){
			my $query_ref  = &name2att($query, $sa, $csa);
			$query  = $$query_ref{'acc'};
			my $target_ref = &name2att($target, $sa, $csa);
			$target = $$target_ref{'acc'};	
		}

     		my $b2s_url = "<a href='http://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastSearch&PROG_DEF=blastn&BLAST_PROG_DEF=megaBlast&SHOW_DEFAULTS=on&BLAST_SPEC=blast2seq&LINK_LOC=align2seq&QUERY=$query&SUBJECTS=$target'>bl2seq</a>";
	        
		push @ol_rows, { 'hname'    => $olname, 
				 'length'   => $olf->length(),
				 'perc'     => $olf->percent_id(),
			    	 'b2s'      => $b2s_url,		
			       };

	}
  	$ol_table = $self->new_table(\@ol_columns, \@ol_rows, {
        	data_table        => 0,
         	margin            => '0.5em 0px',
         	width             => '90%',
         	exportable        => 0
  	});	
  }


  my @region_rows = ( #{ 'type'=>'Components Involved', 'data'=>join("<br>", @cmps_url) },
                      { 'type'=>"Other Tickets in Region (+/-". $range."bp)", 'data'=>join("<br>", @otherticIds) },
                      { 'type'=>"Scaffolds in Region", 'data'=>join("<br>", @fpcs) },
                      #{ 'type'=>"False Gaps", 'data'=>$falsegaps },  ## I've turned this off, as it doesn't really contribute much.
                    );

  my $region_table = $self->new_table(\@columns, \@region_rows, {
         data_table        => 0,
         margin            => '0.5em 0px',
         width             => '90%',
         exportable        => 0
  });


  ## ---- Write initial HTML ---- ##

  ## --- Add an Alert regarding this ticket if there is a clone picked for the gap already --- ## 
  if ($jira_summary =~ /gap/i){
	my @cloneMFs = @{$current_slice->get_all_MiscFeatures('clone')};
	my @clonesin_pipe;
	foreach my $clonefeat (@cloneMFs){

		if ($clonefeat->get_scalar_attribute('clone_status') =~ /not yet sequenced/){
			push @clonesin_pipe, $clonefeat->get_scalar_attribute('internal_clone');
		}
 	}	
	if (@clonesin_pipe > 0){
		$html .= "<hr><H2>Current Status: @clonesin_pipe, has been picked to close the gap</H2><hr>";
	}

  }

  $html .= "<H3>General:</H3>";
  $html .= $table->render();
  $html .= $hr_divider if ($hr_divider);

  $html .= "<H3>Region Details:</H3>";
  $html .= "<strong>Components in Region:</strong><br>";
  $html .= $cmp_table->render();
  $html .= $region_table->render();
  $html .= $ol_table->render() if ($ol_table);
  $html .= $hr_divider if ($hr_divider);
   
 




  ## ---- Genes/cdna Data Table ---- ##

  ## --- See which analysis actually contains stuff. --- ##
  my @generesults;
  foreach my $analysis ('cdna', 'ccds', 'refseq') {

	my @feats = @{$current_slice->get_all_DnaAlignFeatures($analysis)};
	next if (@feats < 1);
       
 	my %genes;
        foreach my $feature (@feats){
		my $hseqname = $feature->hseqname();
		$genes{$hseqname}++;
	}	
		
	foreach my $gene (sort {$genes{$b} <=> $genes{$a}} keys %genes){
		my ($genename, $acc);
		($genename, $acc) = ($gene =~ /(.*)\((\w+)\){0,1}/);
		$genename = $gene if (!$genename);
		$acc      = $gene if (!$acc);

		push @generesults, [$genename, $acc, $genes{$gene}, $analysis]; 
	}
  }

  my @gene_columns =(  { key => 'name',              sort => 'string',   title => 'Name'       },
                       { key => 'accession',         sort => 'string',   title => 'Accession'  },
                       { key => 'count',             sort => 'number',   title => 'hsp count'  },
                       { key => 'analysis',          sort => 'string',   title => 'Analysis'   },
                    ); 

  my @gene_rows;
  foreach my $entry (sort{$$b[2] <=> $$a[2] || $$a[1] cmp $$b[1]} @generesults){

	my $name_url = "<a href='http://www.ncbi.nlm.nih.gov/gene/?term=". $$entry[0]. "'>". $$entry[0]. "</a>";
	my $acc_url  = "<a href='http://www.ncbi.nlm.nih.gov/nuccore/"   . $$entry[1]. "'>". $$entry[1]. "</a>";

	if ($$entry[3] =~ /ccds/i){
		$name_url = "$$entry[0]";
		$acc_url  = "<a href='http://www.ncbi.nlm.nih.gov/projects/CCDS/CcdsBrowse.cgi?REQUEST=CCDS&DATA=". $$entry[1]. "'>". $$entry[1]. "</a>";
	}

	push @gene_rows,  { 'name'     => $name_url, 
			    'accession'=> $acc_url, 
			    'count'    => $$entry[2], 
			    'analysis' => $$entry[3] };
  }

  my $gene_table = $self->new_table(\@gene_columns, \@gene_rows, {
         data_table        => 0,
         margin            => '0.5em 0px',
         width             => '90%',
         sorting           => [ 'count desc' ] ,
         exportable        => 0
  });

  $html .= "<H3>Gene/cDNA in Region Details:</H3>";
  $html .= $gene_table->render();
  $html .= $hr_divider if ($hr_divider);






  ## ------ Blacktag Data Table ------ ##

  my @blacktags = map {join (",", $_->get_scalar_attribute('bt_clone'), $_->get_scalar_attribute('bt_desc'), $_->seq_region_start, $_->seq_region_end)
                        } @{$current_slice->get_all_MiscFeatures('blacktags')};

  my @bt_columns = (
                   { key => 'btclone',    sort => 'string',   title => 'Clone'       },
		   { key => 'start',      sort => 'number',   title => 'Start'       },
		   { key => 'end',        sort => 'number',   title => 'End'         },	
                   { key => 'btdesc',     sort => 'string',   title => 'Description' },
                  );

  my @bt_rows;
  foreach my $bt (@blacktags){
        my @results = split (",", $bt);
	my $bt_url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$current_slice->seq_region_name.":$results[2]-$results[3]" }); 

        push @bt_rows, { 'btclone' => "<a href=$bt_url>$results[0]</a>", 'start' => $results[2], 'end' => $results[3], 'btdesc' => $results[1] };
  }

  my $bt_table = $self->new_table(\@bt_columns, \@bt_rows, {
         data_table        => 0,
         margin            => '0.5em 0px',
         width             => '90%',
         exportable        => 0
  });

  $html .= "<H3>Blacktags in Region:</H3>";
  $html .= $bt_table->render();
  $html .= $hr_divider if ($hr_divider);






  ##----Punchlists----##

  $html .= "<H3>Punchlists in Region:</H3>";

  # punchlists of revelance uses the region in the punch->name().
  my @punchlists = ('complete_overla', 'selfcomp_overla', 'marker_order', 'marker_chr', 'marker_orient', 'end_pairs');

  foreach my $punch_type (@punchlists){

        my @punches = @{ &fetch_punch_data($region, $punch_type, $pa) };
        next if (@punches < 1);

        my @punch_columns;
        my @punch_rows;
        if ($punch_type =~ /selfcomp_overla/){
                @punch_columns = ( { key => 'qclone',   sort => 'string',   title => 'QuerClone'     },
                                   { key => 'hclone',   sort => 'string',   title => 'HitClone'      },
                                   { key => 'hchr',     sort => 'string',   title => 'HitChr'        },
                                   { key => 'hlength',  sort => 'numeric',  title => 'HitLength'     },
                                   { key => 'cov',      sort => 'numeric',  title => 'Coverage'      },
                                   { key => 'gaploc',   sort => 'string',   title => 'GapLocation'   },
                        );

                foreach my $pcontent (@punches){
                        my ($query_clone, $hit_clone, $hit_chr, $hit_length, $cov, $gap_loc, $qstrand, $jtic) = @$pcontent;
                        push @punch_rows, ( { "qclone"    => $query_clone,
                                              "hclone"    => $hit_clone,
                                              "hchr"      => $hit_chr,
                                              "hlength"   => $hit_length,
                                              "cov"       => $cov,
                                              "gaploc"    => $gap_loc,
                                });
                }
        }
        else {
                @punch_columns = ( { key => 'region',   sort => 'string',  title => 'Region'  },
                                   { key => 'comment',  sort => 'string',  title => 'Comment' },
                        );
                foreach my $pcontent (@punches){
                        my ($r, $comment) = @$pcontent;
                        my $rurl = $hub->url({'type'=>'Location','action' =>"View",'r'=>$r });

                        push @punch_rows, ( { "region"   => "<a href='$rurl'>$r</a>",
                                              "comment"  => $comment,
                                            });
                }
        }

        my $punch_table = $self->new_table(\@punch_columns, \@punch_rows, {
                data_table        => 0,
                margin            => '0.5em 0px',
                width             => '80%',
                #sorting           => [ 'start desc' ] ,
                exportable        => 0
        });

        my $ptfeat = $pta->fetch_by_punch_type($punch_type);
        my $punchtype_name = $ptfeat->name();
        $html .= "<strong>$punchtype_name:</strong>";
        $html .= $punch_table->render();

  }
  $html .= $hr_divider if ($hr_divider);




  ## --- Ends Data Table --- ##

  $html .= "<H3>Clones (via ends) in Region Vicinity:</H3>";
  my @analyses = @{$aa->fetch_all()};

  foreach my $a (sort  {$a->logic_name cmp $b->logic_name} @analyses){
	my $logicname = $a->logic_name;
	next if ($logicname !~ /bacend|fosend/);
	next if ($logicname !~ /norep/);

 	my ($simp_lname) = ($logicname =~ /(\w+)_norep/);
	if ($endclone eq $logicname){
		$html .= qq(<button style="background-color:lightgreen" onClick="javascript:window.location.href='JiraSummary?id=$dbid&endclone=$logicname'">>$simp_lname</button>);
	}
	else {
                $html .= qq(<button onClick="javascript:window.location.href='JiraSummary?id=$dbid&endclone=$logicname'">$simp_lname</button>);
	}
	
  }
  $html .= "<br>";
  
  my @cloneend_col =( { key => 'name',           sort => 'string',     title => 'Clonename'       },
                      { key => 'region',         sort => 'string',     title => 'Region'          },
		      { key => 'distance',       sort => 'numeric',    title => 'Distance'        },
		      { key => 'dir',            sort => 'string',     title => 'End Direction'   },		
		      { key => 'clonedb',  	 sort => 'string',     title => 'CloneDB'         },	
                    );

  my @cloneend_rows;
  if ($endclone){

	## Fetch the clones.
	my $results =  &fetch_clones_via_ends($endclone, $current_slice, $dafa);

	foreach my $clonename ( sort { ( ($$results{$a}{'r'}) =~ /\w+:(\d+)-.*/ ) <=> ( ($$results{$b}{'r'}) =~ /\w+:(\d+)-.*/ ) }  keys %$results){
		my $r      = $$results{$clonename}{'r'};
		my $linkid = $$results{$clonename}{'linkid'};
		my @dir    = @{$$results{$clonename}{'dir'}};		

		my $r_url   = $hub->url({'type'=>'Location','action' =>"View",'r'=>$r, 'h'=>$linkid, 'contigviewbottom'=>"$endclone=normal"}); 
		my $cdb_url = "<a href='http://www.ncbi.nlm.nih.gov/clone/?term=$clonename'>record</a>";
		push @cloneend_rows, {"name"     => $clonename, 
				      "region"   => "<a href='$r_url'>$r</a>", 
				      "distance" => $$results{$clonename}{'distance'}." bp",
				      "dir"      => join (" ", @dir),	
			  	      "clonedb"  => $cdb_url
				     };
	}
  }

  my $cloneend_table = $self->new_table(\@cloneend_col, \@cloneend_rows, {
         data_table        => 1,
         margin            => '0.5em 0px',
         width             => '100%',
         sorting           => [ 'region asc' ] ,
         exportable        => 1
  });

  $html .= (@cloneend_rows > 0) ? $cloneend_table->render() : "<br><strong>No Results for $endclone</strong>";
  $html .= $hr_divider if ($hr_divider);
  




  ## ----- Compara Table ----- ##

  ## Note: Its currently quite slow so I will turn it on/off with a button option.
  $html .= "<H3>Compara Regions:</H3>";
  if (!$comparacheck){
	$html .= "<strong>Initial Loading of Compara Data takes time (gets cached afterwards), if you wish to see it anyways press the button below.</strong><br>";
	$html .= qq(<button onClick="javascript:window.location.href='JiraSummary?id=$dbid&compara=1'">Load Compara Data</button>);
	$html .= $hr_divider if ($hr_divider);
  } 
  if ($comparacheck){
  my $comparaDB_adaptor = $self->hub->database('compara');

  my @wgs_columns =( { key => 'rank',            sort => 'numeric',    title => 'Rank'               },
		     { key => 'qdb',             sort => 'string',     title => 'QueryDB'            },
                     { key => 'cregion',         sort => 'string',     title => 'Comparable Region'  },
                     { key => 'count',           sort => 'numeric',    title => 'Aligned Block Count'},
                     { key => 'acc',             sort => 'string',     title => 'Components'         },
    	            );
  ## --- Fetch the other WGS dbs that are attached to this db --- ##
  my $mlssa    = $comparaDB_adaptor->get_MethodLinkSpeciesSetAdaptor();
  my $gdba     = $comparaDB_adaptor->get_GenomeDBAdaptor();
  my $gdbobj   = $gdba->fetch_by_registry_name($species);

  my @wgs_spc;
  ## Very Important Note: For future references, I was using online perldoc pages to look at methods, and they are totally
  ## 	different to the ones in the code(e66).  So check beforehand or else you'll spend a few trying to debug ghosts.			  
  my @mlssobj    = @{$mlssa->fetch_all_by_GenomeDB($gdbobj)};
  foreach my $m (@mlssobj){
  	my @gdbs = @{$m->species_set()};
        foreach my $g (@gdbs){
		next if ($g->name() eq $species);
		push @wgs_spc, $g->name();
	}
  }	
  
  @wgs_spc = sort {$a cmp $b} @wgs_spc;	
  
  my @wgs_rows;
  foreach my $wgs (@wgs_spc) {
	my @comparaFeats = @{$current_slice->get_all_compara_DnaAlignFeatures($wgs,'','BLASTZ_NET', $comparaDB_adaptor)};

	my %compara_results;
	my $order = 0; 
	foreach my $h (@comparaFeats){
		#make sub if works..
		my $subregion_slice = $h->hslice->sub_Slice($h->hstart, $h->hend, $h->hstrand);

		next if (!$subregion_slice);
		my @projs      = map {$_->to_Slice} @{$subregion_slice->project('seqlevel')};		
		my @accs       = map { @{$_->get_all_Attributes('accession')}[0] } @projs;
		 
		foreach my $pacc (@accs){
			next if (!$pacc);
		      	$compara_results{$h->hseqname}{acc}{$pacc->value}  = $order;
			$order++;
		}

		$compara_results{$h->hseqname}{count}++;
	}	

	my $count = 1;
	foreach my $cr (sort{$compara_results{$b}{count} <=> $compara_results{$a}{count}} keys %compara_results){
		next if ($compara_results{$cr}{count} < 2);	
		
		my @accessions = map { $_ } ( sort{ $compara_results{$cr}{acc}{$a} <=> $compara_results{$cr}{acc}{$b} } keys %{$compara_results{$cr}{acc}} );	
		@accessions    = ("no accession data") if (@accessions <1);

		# Setup the URL links.
		my $cr_url  = "<a href='".$hub->url({"type"=>"Location", "action"=>"View", "region"=>$cr, "species"=>$wgs, __clear=>1})."'>$cr</a>";
			
		push @wgs_rows, {   'rank'    => $count, 
				    'qdb'     => $wgs, 
				    'cregion' => $cr_url, 
				    'count'   => $compara_results{$cr}{count}, 
				    'acc'     => join (", ",@accessions) };
	
		last if ($count ==2);
		$count++;	
	}
  }

  ## A bit of sanity to close the additional not really needed database connection.
  $comparaDB_adaptor->DESTROY();

  my $wgs_table = $self->new_table(\@wgs_columns, \@wgs_rows, {
         data_table        => 0,
         margin            => '0.5em 0px',
         width             => '100%',
         exportable        => 0
  });

  $html .= $wgs_table->render();
  $html .= $hr_divider if ($hr_divider);
  
}






  ## ---- Marker Data Table ---- ##

  my @markfeats = @{$current_slice->get_all_MarkerFeatures()};
  
  my @compiled_mfeats;
  my %maps;
  foreach my $m (sort {$a->seq_region_start <=> $b->seq_region_start} @markfeats){
	my $marker        = $m->marker();
	my @marker_loc    = @{$marker->get_all_MapLocations()};
	
	my %locations;
	foreach my $mloc (@marker_loc){
		$maps{$mloc->map_name}++;
		my $chr = $mloc->chromosome_name() || "unk";
		my $pos = $mloc->position() || "none";
		$locations{$mloc->map_name} = "($chr)mp:$pos";
	}
	push @compiled_mfeats, { "name" => $m->display_id(), "start" => $m->seq_region_start, "end" => $m->seq_region_end, "locations" => \%locations};
  }

  my @marker_columns =({ key => 'name',   sort => 'string',   title => 'Name'  },
		       { key => 'start',  sort => 'numeric',  title => 'Start' },
		       { key => 'end',    sort => 'numeric',  title => 'End'   },	
			);

  foreach my $mapname (sort {$a cmp $b} keys %maps){
	push @marker_columns, { key => $mapname, sort => 'string', title => $mapname };
  }	
  
  my @marker_rows;
  foreach my $feat (@compiled_mfeats){

	my $mname = $$feat{'name'};
	my $murl  = $hub->url({'type'=>'Marker','action' =>"Details", 'm'=>$mname});
        my $entry = { 'name' => "<a href='$murl'>$mname</a>", 'start' => $$feat{'start'}, 'end' => $$feat{'end'}};       

	my $locref = $$feat{'locations'};
	foreach my $mapname (keys %$locref){
		$$entry{$mapname} = $$locref{$mapname}
	}
  	push @marker_rows, $entry; 
  }

  my $marker_table = $self->new_table(\@marker_columns, \@marker_rows, {
         data_table        => 1,
         margin            => '0.5em 0px',
         width             => '100%',
         sorting           => [ 'start desc' ] ,
         exportable        => 1
  });

  $html .= "<H3>Markers in Region:</H3>";
  $html .= $marker_table->render();
  $html .= $hr_divider if ($hr_divider);




#-------------#
# return html #
#-------------#

  return $html;

}



## ---- Fetch estimated clone mappings via end read mappings ---- ##
##  Using the gap spanner/spanner dna_align_feature_attrib.
sub fetch_clones_via_ends {
  my ($logicname, $slice, $dafa) = @_;

  my @endfeats = @{$dafa->fetch_all_by_Slice($slice, $logicname)};

  my %feats2rtn;	
  foreach my $feat (sort {$a->seq_region_start <=> $b->seq_region_end} @endfeats){

	my ($clonename) = ($feat->hseqname() =~ /(.*?)\..*/);
	
	my ($span) = @{$feat->get_all_Attributes('spanner')};
	$feats2rtn{ $clonename }{'r'} = $span->value() if ($span);

	if (!$span){
        	my ($gspan) = @{$feat->get_all_Attributes('gap_spanner')};
        	$feats2rtn{ $clonename }{'r'} = $gspan->value() if ($gspan);
		$span = $gspan;
	}
	if ($span){
		my ($chr, $start, $end) = ($span->value =~ /^(\w+):(\d+)-(\d+)$/);
		$feats2rtn{ $clonename }{'distance'} = $end - $start + 1;
		$feats2rtn{ $clonename }{'linkid'}   = $feat->hseqname();
		push @{ $feats2rtn{ $clonename }{'dir'} }, ($feat->strand() == 1) ? "<img src='/i/right_arrow.png' alt='>'>" : "<img src='/i/left_arrow.png' alt='<'>";   
	}
  }
  return \%feats2rtn;
}



## ---- Internalnames as seq_region_names convert to accession----##
##   Returns all the attributes connected to the component
sub name2att {

  my ($intname, $sa, $csa) = @_;
  return if (!$intname);
  my $slice = $sa->fetch_by_region('clone', $intname) || $sa->fetch_by_region('seqlevel', $intname);
  return $intname if (!$slice);  

  my ($acc)      = @{$slice->get_all_Attributes('accession')};
  my ($ver)      = @{$slice->get_all_Attributes('version')};
  my ($htgs)     = @{$slice->get_all_Attributes('htgs_phase')};
  my ($int_name) = @{$slice->get_all_Attributes('int_name')};
  my ($status)   = @{$slice->get_all_Attributes('status_desc')};

  ## Note: because of assembly mappings being mainliy clone:contig:toplevel, and/or fpc:contig:toplevel,
  ##   the fpc:clone sometimes not there, so safer to project to toplevel then back down to scaffold/fpc.	 
  my $toplevel_slice  = @{$slice->project('toplevel')}[0]->to_Slice;

  my $proj_cs;
  if ($csa->fetch_by_name('fpc_contig')){
       $proj_cs    =  "fpc_contig";
  }
  elsif ($csa->fetch_by_name('scaffold')){
       $proj_cs    =  "scaffold";
  }
  elsif ($csa->fetch_by_name('supercontig')){
       $proj_cs    =  "supercontig";
  }
 
  my $fpc_proj = $toplevel_slice->project($proj_cs);
  my @fpcs;
  if ($fpc_proj){
     @fpcs   = map {$_->to_Slice->seq_region_name} @$fpc_proj;
  }
 
  my %results = ( 'acc'     => ($acc)      ? $acc->value      : $intname,
		  'ver'     => ($ver)      ? $ver->value      : undef,
		  'htgs'    => ($htgs)     ? $htgs->value     : undef,
		  'intname' => ($int_name) ? $int_name->value : undef,
		  'status'  => ($status)   ? $status->value   : undef,
		  'scaf'    => join (", ", @fpcs),
		); 	

  return \%results;
}
 	
	

## ---- Fetch Punchlists ---- ##
##  As advertised, fetches    ## 
##  punch data per punch type ##
##  Slightly diff output for  ##
##  selfcomp_overlap.         ##
## -------------------------- ##
sub fetch_punch_data {

  my ($region, $punch_type, $punch_adaptor)  = @_;
  	
  my ($qchr, $qstart, $qend) = ($region =~ /(\w+):(\d+)-(\d+)/);

  my @results;
  my @punches = @{$punch_adaptor->fetch_by_punch_type( $punch_type )}; 		
	
  foreach my $punch (@punches){
	my $punch_region = $punch->name();
	my ($tchr, $tstart, $tend) = ($punch_region =~ /(\w+):(\d+)-(\d+)/);
	next if ($qchr != $tchr);
	next if ( ($tstart < $qstart) || ($tend > $qend ) );

	my $comment = $punch->comment();
   
        if ($punch_type =~ /selfcomp_overla/){
		my ($query_clone, $hit_clone, $hit_chr, $hit_length, $cov, $gap_loc, $qstrand, $jira) = split (",", $comment);
		push @results, [$query_clone, $hit_clone, $hit_chr, $hit_length, $cov, $gap_loc, $qstrand, $jira]; 
  	}
	else {
		push @results, [$punch_region, $comment];
	}
  }
  return \@results;
}






1;
