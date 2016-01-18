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

package EnsEMBL::pgp::Web::Component::Punchlist::Overview;

use strict;
use warnings;
no  warnings "uninitialized";
use Time::HiRes qw(time);
use EnsEMBL::Web::Object;
use base qw(EnsEMBL::Web::Component);



sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption{
	return "";
}


sub content{

  my $self        = shift;
  my $hub         = $self->hub;
  my $url         = $hub->url();
  my ($action)    = $url =~ /.*\/(.*)\?.*\z/;
  
  $action = $hub->param('punchtype')||"Overview";
  
  # Hack so ensembl recognises the punchtype adaptor...
  use Bio::EnsEMBL::DBSQL::PunchTypeAdaptor;
  Bio::EnsEMBL::DBSQL::PunchTypeAdaptor->init( $self->hub->species_defs->valid_species() );
  use Bio::EnsEMBL::DBSQL::PunchAdaptor;
  Bio::EnsEMBL::DBSQL::PunchAdaptor->init( $self->hub->species_defs->valid_species() );
  
  my $pta =  $self->hub->database('core')->get_PunchTypeAdaptor();
  my $pa  =  $self->hub->database('core')->get_PunchAdaptor();

  

 # 
 # OPTION: Overview ::: DEFAULT PAGE listing all items
  
  if ( $action eq 'Overview') {
      
    my $html;
    my @columns = ( 
                  { key => 'name',       sort => 'string',   title => 'Punch Type'          },
                  { key => 'desc',       sort => 'string',   title => 'Description'         },
                  { key => 'count',      sort => 'numeric',  title => 'no of entries'       },
                  );

    my @punch_types = @{$pta->fetch_all()};  
    @punch_types    = sort { $a->code() cmp $b->code() } @punch_types;
    
    my @rows;
    foreach my $punch_type ( @punch_types ) {
      
      my $feature_type_adaptor = "get_".$punch_type->feature_type()."Adaptor";
      my $adaptor              = $self->hub->database('core')->$feature_type_adaptor();

      my $punch_count     = @{$pa->fetch_by_punch_type( $punch_type->code )};
      my $punch_desc      = $punch_type->description || "description not available";
      my $punch_name      = $punch_type->name || $punch_type->code;   
      next if ( $punch_count == 0 );

      my $pt_url    = $hub->url({ type => 'Punchlist', action => 'Overview', punchtype => $punch_type->code, __clear=>1 });
      my $pt_href   = qq{<a href="$pt_url" class="nodeco" >$punch_name</a><br>};
      
      push @rows,  { name=>$pt_href, desc=>"<em>$punch_desc</em>", count=>$punch_count  };
    } 

    my $table = $self->new_table(\@columns, \@rows, {
        data_table        => 1,
        exportable        => 1
        });

    $html .= $table->render;  
    return $html;
  }




 # 
 # Setup Adaptors.
  my $punch_type           = $pta->fetch_by_punch_type($action);
  my $feature_type         = $punch_type->feature_type();
  my $feature_type_adaptor = "get_".$feature_type."Adaptor";
  my $adaptor              = $self->hub->database('core')->$feature_type_adaptor();
  
  my $ata  = $self->hub->database('core')->get_AttributeAdaptor;
  my $sa   = ($feature_type_adaptor !~ /slice/i) ? $self->hub->database('core')->get_SliceAdaptor : $adaptor;

  my $html = "<H1> Punchlist for: " . $punch_type->name() . "</H1>";
  

  
  
 # 
 # OPTION: JIRA ::: List outstanding JIRA tickets.

 if ( $action eq 'jira') {
     
     my @punches = @{$pa->fetch_by_punch_type( $action )};
     
     my %jira_hash = ();
     
     foreach my $punch ( @punches ) {
	 
	 my $dbID    = $punch->name();
	 my $feature = $adaptor->fetch_by_dbID( $dbID );
	 
	 next if ( ! $feature );
	 
	 my $seq_name     = $feature->seq_region_name;
	 my $seq_start    = $feature->start;
	 my $seq_end      = $feature->end;
	 my $jira_summary = $feature->get_scalar_attribute('jira_summary');
	 my $jira_id      = $feature->get_scalar_attribute('jira_id');
	 my $jira_status  = $feature->get_scalar_attribute('jira_status'); 
	 my $db_id        = $feature->dbID();
	 my $region       = "$seq_name:$seq_start-$seq_end";
	 my $reg_url      = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});
	 my $jira_url     = $hub->url({'type'=>'Jira','action' =>"JiraSummary",'id'=>$db_id});
	 my $grc_url      = "http://www.ncbi.nlm.nih.gov/projects/genome/assembly/grc/issue_detail.cgi?id=$jira_id";
	 my $jentry       = "<a href=$jira_url class='nodeco'>$jira_id</a>";
	 my $rentry       = "<a href=$reg_url class='nodeco'>$region</a>";
	 
	 next if ($jira_status eq "Resolved");
	 my $jcolour =  &jira_colours($jira_status);
	 my $status  = "<em style='color:$jcolour'>$jira_status</em>";

	 push @{$jira_hash{ $seq_name }}, {start=>$seq_start, end=>$seq_end, rurl=>$rentry, 
					   jurl=>$jentry, id=>$jira_id, summary=>$jira_summary,
					   status=>$status, grcurl=>$grc_url};
     }

     $html .= &add_navmenu(\%jira_hash);

     my @cols = ( 
	 { key => 'jiraid',       sort => 'string',   width=>'7%',   title => 'JiraID'              },
	 { key => 'region',       sort => 'position',   width=>'18%',  title => 'Region'              },
	 { key => 'desc',         sort => 'string',   width=>'50%',  title => 'Description'         },
	 { key => 'status',       sort => 'string',   width=>'15%',  title => 'Status'              },
	 { key => 'grcrep',       sort => 'string',   width=>'10%',  title => 'GRC report'          },
	 );

     foreach my $seq_name ( sort { $a cmp $b } keys %jira_hash ) {
	 my $issue_counts = @{$jira_hash{ $seq_name }} || '';
	 $html .= "<h3><a name=$seq_name></a> Chromosome: $seq_name (no of issues: $issue_counts)</h3>";

	 my @rows;
	 foreach my $entry ( sort { $$a{start} <=> $$b{start} } @{$jira_hash{ $seq_name }} ) {
	     push @rows, { jiraid   =>  $$entry{jurl}, 
			   region   =>  "<em>".$$entry{rurl}."</em>",
			   desc     =>  $$entry{summary},
			   status   =>  $$entry{status},
			   grcrep   =>  '<a href="'.$$entry{grcurl}.'" rel="external" class="nodeco">GRC Report</a>',
	     };
	 }
	 
	 my $table = $self->new_table(\@cols, \@rows, {
	     data_table        => 1,
	     exportable        => 1
				      });
	 
	 $html .= $table->render;
     }
 }
 




 # 
 # OPTION: True GAPS ::: List GAPs as seen from the TPF.

   elsif ( $action eq "gap_true" ) {
    my @punches = @{$pa->fetch_by_punch_type( $action )};
  
    my %feature_hash = ();
    
    foreach my $punch ( @punches ) {
      
      my $slice_name  = $punch->name();
      my ($chr_name, $chr_start, $chr_end) = $slice_name =~ /^(.*?):(.*?)-(.*)/;
      my $gap_size = $chr_end - $chr_start + 1;


      my $region  = "$chr_name:$chr_start-$chr_end";
      my $url     = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});

      my $entry = "Gap region: <a href=$url> $chr_name:$chr_start-$chr_end </a>(size $gap_size)";     
      
      push @{$feature_hash{ $chr_name }}, {start => $chr_start, url => $entry};
      
    }
    
    foreach my $seq_name ( sort { $a cmp $b } keys %feature_hash ) {
      
      $html .= "<h3> Chromosome: $seq_name </h3>";

      foreach my $entry ( sort { $$a{start} <=> $$b{start} } @{$feature_hash{ $seq_name }} ) {
	$html .= " $$entry{url}<br>\n";
      }
    }

  }




 # 
 # OPTION: Complete Overlaps ::: Contained or Complete Overlapped clones.

 elsif ( $action =~ /complete_over/ ) {
     my @punches = @{$pa->fetch_by_punch_type( $action )};
     
     my %feature_hash = ();
     
     foreach my $punch ( @punches ) {
	 
	  my $slice_name  = $punch->name();
	  my $comment     = $punch->comment();
	  my ($chr_name, $chr_start, $chr_end) = $slice_name =~ /^(.*?):(.*?)-(.*)/;
	  my $gap_size = $chr_end - $chr_start + 1;
	  
	  
	  my $region  = "$chr_name:$chr_start-$chr_end";
	  my $url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});	  
	  
	  my $entry = "<a href=$url> $region </a>";	   
	  push @{$feature_hash{ $chr_name }}, {start => $chr_start, url => $entry, comment => $comment};	  
      }
     
     my @cols = ( 
		 { key => 'url',        sort => 'string',      title => 'Region'              },
		 { key => 'comment',    sort => 'string',     title => 'Overlapping components'              },
		);
     
     foreach my $seq_name ( sort { $a cmp $b } keys %feature_hash ) {
	 
       $html .= "<h3> Chromosome: $seq_name </h3>";
       
       my @rows;
       foreach my $entry ( sort { $$a{start} <=> $$b{start} } @{$feature_hash{ $seq_name }} ) { 
	 push @rows, { url=>$$entry{url}, comment=>$$entry{comment} };
       }
       my $table = $self->new_table(\@cols, \@rows, {
						     data_table        => 0,
						     margin            => '0.5em 0px',
						     width             => '65%',
						     exportable        => 0
						    });
       
       $html .= $table->render;
     
     }
     
 }
 



 # 
 # OPTION: Gap Spanners ::: Clone (end/mate pairs) that span gaps.

 elsif ( $action =~ /gap_spanner/ ) {
     my @punches = @{$pa->fetch_by_punch_type( $action )};
     
     my %feature_hash = ();
     
     foreach my $punch ( @punches ) {
	 
	 my $slice_name  = $punch->name();
	 my $comment     = $punch->comment();
	 my ($chr_name, $chr_start, $chr_end) = $slice_name =~ /^(.*?):(.*?)-(.*)/;
	 
	 my $region  = "$chr_name:$chr_start-$chr_end";

	 my ($readpair, $scaf_count, $gapdist)  =  split (/\|/, $comment);
	 
	 my ($read) = split(",", $readpair);
	 $read = $readpair if (!$read);
	 
	 my $url = $hub->url({ type    =>"Location",
			       action  =>"View",
			       r       =>$region, 
			      # h       =>$read, 
			     });	 

	 my $entry = "<a href=$url>$slice_name</a>";	 
	 $readpair =~ s/(\(same end\))/<em style='color:#8A4B08'>$1<\/em>/;

	 push @{$feature_hash{ $chr_name }}, {start => $chr_start, end => $chr_end, url => $entry, reads => $readpair, scaf=>$scaf_count, gapdist=>$gapdist, reg=>$region};
	 
     }
     $html .= &add_navmenu(\%feature_hash);
     
     my $gs_type   =  ($action =~ /all/) ? "ctgs" : "scaf/fpc";

     my @cols = ( {key=>'region',               sort=>'position', width=>'10%',  title=>'Region'},
		  {key=>'reads',                sort=>'string',   width=>'55%',  title=>'Reads involved'},
		  {key=>'scaf',                 sort=>'number',   width=>'15%',  title=>"Num of $gs_type involved"},
		  {key=>'gap',                  sort=>'number',   width=>'20%',  title=>"Approx Gap size or dist between seq component if more than 2 $gs_type (kb)"},		  
	 );
     foreach my $seq_name ( sort { $a cmp $b } keys %feature_hash ) {
	 
	 $html .= "<h3><a name='$seq_name'>Chromosome: $seq_name</a></h3>";
	 
	 my @rows;
	 my $prev_end   = 0; 
	 foreach my $entry ( sort { $$a{start} <=> $$b{start} } @{$feature_hash{ $seq_name }} ) {
	     
	     if ( ($prev_end != 0 ) && ($$entry{start} > $prev_end) ){
		 #$html .= "<BR>\n";
		 push @rows, {region=>"-----", reads=>"-----"};
	     }
	     
	     #$html .= " $$entry{url}<br>\n";
	     push @rows, {  region  =>$$entry{url}, 
			    reads   =>$$entry{reads},
			    scaf    =>$$entry{scaf},
			    gap     =>$$entry{gapdist}};
	     
	     $prev_end   = $$entry{end};  
	 }
	 my $table = $self->new_table(\@cols, \@rows, {
						       data_table        => 0,
						       exportable        => 1
						      });
	 
	 $html .= $table->render;
     }
     
 }


 # 
 # OPTION: Unplaced Optical Maps ::: List regions of unplaced Optical Map fragments ( >3 regions).

 elsif ( $action eq 'unplaced_om') {
     
     $html .= "<h3><b style='text-decoration:underline'>Key</b>: Seq Region(chr:start-end), Total Fragment Size, [Total Fragments], (Source),<br> Singleton optical map contigs in region in grey</h3>";

     my @punches = @{$pa->fetch_by_punch_type( $action )};
     
     my %sorted_punches;
     foreach my $punch ( @punches ) {
	 
	 my $dbID  = $punch->name();
	 my $feature = $adaptor->fetch_by_dbID( $dbID );
	 
	 next if ( ! $feature );
	 
	 my $seq_name  = $feature->seq_region_name;
	 my $seq_start = $feature->start;
	 my $seq_end   = $feature->end;
	
	 push @{$sorted_punches{$seq_name}{$seq_start}}, { punch => $punch, feature => $feature };
     }

     foreach my $toplevel (sort { $a <=> $b } keys %sorted_punches){
	 $html .= "<h3> Chromosome: $toplevel </h3>";
	 my %results = %{$sorted_punches{$toplevel}};
	 foreach my $start (sort { $a <=> $b } keys %results ){
	     foreach  my $p_obj (@{$sorted_punches{$toplevel}{$start}}){

		 my $seq_region  = $$p_obj{feature}->seq_region_name.":".$$p_obj{feature}->start."-". $$p_obj{feature}->end;

		 my $comments = $$p_obj{punch}->comment;
		 my ($size, $fragnum, $type) = $comments =~/(\d+)\((\d+)\)(.*)/;
		 my $url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$seq_region});
		 my $line;
		 $line  = "<div style='color:grey'>" if (@{$sorted_punches{$toplevel}{$start}} <2);
		 $line .= "<a href=$url ";
		 $line .= "style='color:grey;text-decoration:none'" if (@{$sorted_punches{$toplevel}{$start}} <2);
		 $line .= ">$seq_region</a>, <b>$size</b>, [$fragnum], $type<br>";
		 $line .= "</div>" if (@{$sorted_punches{$toplevel}{$start}} <2);
		 $html .= $line;
	     }
	     $html .= "&nbsp;<p>";
	 }
     }


 }
 

#
# Selfcomp Overlap Punchlists will highlight selfcomp results on clones that hit to adjacent regions, that may be seperated by gap, indicating potential join.
  elsif ( $action =~ /selfcomp_overla/ ) {

      $html .= "<h3><b style='text-decoration:underline'>Key</b>: </h3>".
	       "<ul><li>\"h/g\" - hit to gap ratio (value of 1 means no gaps). ".
	       "<li>\"sgap\" - location of sequence gap (left - preceding query clone, right - following query clone, both - gap on both sides)  ".
	       "<li>\"ctn\" - potential for contained clone (greater than 95% coverage)</ul>";

      my @punches = @{$pa->fetch_by_punch_type( $action )};

      my %feature_hash = ();
      foreach my $punch (sort {$a->name cmp $b->name} @punches ) {
	  
          my $slice_name  = $punch->name();
          my $comment     = $punch->comment();
          my ($chr_name, $chr_start, $chr_end) = $slice_name =~ /^(.*?):(.*?)-(.*)/;
	  my $clone_length = $chr_end-$chr_start+1;
	  push @{$feature_hash{$chr_name}{$chr_start}}, { region         => $slice_name,
							  comment        => $comment,
							  qclonelength   => $clone_length,
						      };
      }

      $html .= &add_navmenu(\%feature_hash);

      foreach my $chr (sort {$a <=> $b} keys %feature_hash){

	  $html .= "<p><h3><a name='$chr'>Chr: $chr</a></h3>";
	  $html .= "<table>";
	  $html .= "<th>region</th><th>qname</th><th>qlength</th><th>&nbsp;</th>".
	           "<th>hname</th><th>chr</th><th>hlength</th><th>h/g</th><th>sgap</th>".
		   "<th>ctn</th><th>&nbsp;</th><th>jira [login req]</th>";

	  foreach my $start (sort { $a <=> $b } keys %{$feature_hash{$chr}} ){
	      foreach my $hit ( @{$feature_hash{$chr}{$start}} ){


		  my $url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$$hit{region}});
		  my ($query_clone, $hit_clone, $hit_chr, $hit_length, $cov, $gap_loc, $qstrand, $jira) = split (",", $$hit{comment});

		  my $q_clone_length = $$hit{qclonelength};

		  my $overall_cov = $hit_length/$q_clone_length;
		  my $complete_ov = ($overall_cov > 0.95) ? "ctn" : "";
		  

		  # fetch Jira Info
		  my $jira_comment;
		  my @entries = split (/\./, $jira);

		  foreach my $dbid (@entries){
		      my $mf_obj    = $adaptor->fetch_by_dbID($dbid);
		      next if (!$mf_obj);
		      my $jira_id   = $mf_obj->get_scalar_attribute('jira_id');
		      my $seq_name  = $mf_obj->seq_region_name;
		      my $seq_start = $mf_obj->start;
		      my $seq_end   = $mf_obj->end;
		      my $mf_region = "$seq_name:$seq_start-$seq_end";
		      #my $jira_url  = $hub->url({'type'=>'Location','action' =>"View",'r'=>$mf_region});
		      my $jira_url = "https://ncbijira.ncbi.nlm.nih.gov/browse/$jira_id";
		      $jira_comment .= "<a href=$jira_url class='nodeco'>$jira_id</a> ";
		      
		  }
		  # --

		  $html .= "<tr><td><a href=$url class='nodeco'>".$$hit{region}."</a></td>";
		  $html .= "<td>$query_clone</td><td>$q_clone_length</td>".
		           "<td style='background-color:grey'>&nbsp;</td>".
			   "<td>$hit_clone</td>";

		  # Colour Code the Chr Hit
		  if ($hit_chr eq $chr){
		      $html .= "<td style ='background-color:green'>$hit_chr</td>";
		  }
		  elsif ($hit_chr =~ /H_$chr|AB_$chr/){
		      $html .= "<td style ='background-color:lightblue'>$hit_chr</td>";
		  }
		  else {
		      $html .= "<td style ='background-color:red'>$hit_chr</td>";
		  }
		  

		  $html .= "<td>$hit_length</td><td>$cov</td>".
		           "<td>$gap_loc</td><td>$complete_ov</td>".
			   "<td style='background-color:grey'>&nbsp;</td>".
			   "<td>$jira_comment</td>";
		  
		  $html .= "<tr>";
	      }
	  }
	  $html .= "</table></p>";

      }


  }



 # 
 # OPTION: Incomplete cDNA ::: Lists all Incomplete coverage cDNA and lists their whereabouts .


  elsif ( $action =~ /incomplete_cdna/ ) {
      my @punches = @{$pa->fetch_by_punch_type( $action )};

      my %feature_hash = ();

      foreach my $punch ( @punches ) {

          my $slice_name  = $punch->name();
          my $comment     = $punch->comment();
          my ($chr_name, $chr_start, $chr_end) = $slice_name =~ /^(.*?):(.*?)-(.*)/;
          my ($cdna_name, $coord, $coverage, $repstatus, $ctg_span) = split (":", $comment);
          my ($coord_start, $coord_end) = split ("-", $coord);

          my $region  = "$chr_name:$chr_start-$chr_end";
          my $url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});

          my $entry;
          $entry  = "<B>" if ($repstatus ne "R");
          $entry .= "<a href=$url>$slice_name</a>  $coord ($coverage), spanning $ctg_span ctgs";
          $entry .= "</B>" if ($repstatus ne "R");

          push @{$feature_hash{ $cdna_name}}, {start => $coord_start, end => $coord_end, url => $entry};

      }

      my @filtered_leftovers;

      foreach my $seq_name ( sort { @{$feature_hash{$b}} <=> @{$feature_hash{$a}} } keys %feature_hash ) {

        if ( (@{$feature_hash{$seq_name}} > 3) || (@{$feature_hash{$seq_name}} == 1) ){
                push (@filtered_leftovers, $seq_name);
                next;
        }

          $html .= "<h4> read: $seq_name </h4>";

          foreach my $entry ( sort { $$a{start} <=> $$b{start} } @{$feature_hash{ $seq_name }} ) {

              $html .= " $$entry{url}<br>\n";

          }
      }

     $html .= "<br><hr><br>\n";

     foreach my $seq_name_leftover (@filtered_leftovers){

          $html .= "<h4> read: $seq_name_leftover </h4>";

          foreach my $entry ( sort { $$a{start} <=> $$b{start} } @{$feature_hash{ $seq_name_leftover }} ) {

              $html .= " $$entry{url}<br>\n";

          }
     }

  }





#
# # OPTION: Helminth Hangers ::: Lists all hanger reads and their associating contigs of the other pair . (**Also at Risk b/c of low usage)


  elsif ( $action =~ /gap_hangers/ ) {
      my @punches = @{$pa->fetch_by_punch_type( $action )};

      my %feature_hash = ();
      my %ctg_atend=();

      foreach my $punch (  sort { $a->name cmp $b->name} @punches ) {
          my ($toplevel, $scaffold, $dir, $ctgname) = split (/:/, $punch->name());
	  my $comment = $punch->comment();
	  push @{ $feature_hash{$toplevel}{$scaffold}{$dir} },  $comment;
	  $ctg_atend{$scaffold}{$dir} = $ctgname;
      }

      foreach my $header (sort keys %feature_hash){
	  
	  $html .= "<h4>$header</h4>";
	  
	  foreach my $scaf ( sort keys %{$feature_hash{$header}} ){
	      my $scaf_length   = $self->hub->database('core')->get_SliceAdaptor->fetch_by_region('scaffold', $scaf)->seq_region_length;  
	      my $threshold     = ($scaf_length < 20000) ? $scaf_length : 20000;

	      foreach my $dir ( sort keys %{$feature_hash{$header}{$scaf}} ){ 
		  my $mapped_onctg = $ctg_atend{$scaf}{$dir};

		  my $scaf_reg = ($dir eq "L") ? ("$scaf:1-$threshold") : ("$scaf:".($scaf_length-$threshold +1)."-".$scaf_length);
		  
		  my $scaf_url = $hub->url({'type'=>'Location','action' =>"View",'r'=>"$scaf_reg"});
		  $html .= "<ul><li>$scaf ($scaf_length bp) [<i>$mapped_onctg</i>]-- <a href=$scaf_url>$dir</a> <ul>";

		  my @sorted_ctgs = sort { ($b =~ /\((\d+)\)/)[0] <=> ($a =~ /\((\d+)\)/)[0] }  @{$feature_hash{$header}{$scaf}{$dir}};
		  
		  while (my $co = shift(  @sorted_ctgs ) ){
		      my ($split, $ctg, $read_count)    = split (/:/, $co);
		      my $ctg_url = $hub->url({'type'=>'Location','action' =>"View",'region'=>$ctg});
		      $html .= "<li><a href=$ctg_url>$ctg</a> <i>[$split]</i> ($read_count)<br>";
		  }
		  $html .= "</ul></ul>";

	      }
	      $html.= "<br>";

	  }	  
      }      
  }
 

#
#  # Incorrect Placments based on Marker Placements.
  elsif ( $action eq 'marker_orient' || $action eq 'marker_order' || $action eq 'marker_chr' || $action eq 'gapmap_orient' || $action eq 'gapmap_order' || $action eq 'gapmap_chr') {
     my @punches = @{$pa->fetch_by_punch_type( $action )};
     
     my %feature_hash = ();
     
     foreach my $punch ( @punches ) {
	 
	  my $slice_name  = $punch->name();
	  my $comment     = $punch->comment();
	  my ($chr_name, $chr_start, $chr_end) = $slice_name =~ /^(.*?):(.*?)-(.*)/;
	  
	  my $slice           = $sa->fetch_by_region('toplevel', $chr_name, $chr_start, $chr_end);
	  my $proj_components = @{$slice->project('seqlevel')};

	  my $region  = "$chr_name:$chr_start-$chr_end";
	  my $url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});
	  	 
	  # Add href end-tag after first word
	  $comment  =~ s/(NEW)/<em style='color:blue'>$1<\/em>/;
	  $comment  =~ s/(ctg\d+)/<strong>$1<\/strong>/g;

	  my $rurl = "<a href=$url class='nodeco'> $region</a>";	  
	  
	  push @{$feature_hash{ $chr_name }}, {start => $chr_start, url => $rurl, comment => $comment, cmp_count => $proj_components};
	  
      }

     $html .= &add_navmenu(\%feature_hash);

     my @cols =(   { key => 'region',       sort => 'position', width => '15%', title => 'Region'          },
		   { key => 'comment',      sort => 'string',  width => '65%', title => 'Comment'         },
		   { key => 'count',        sort => 'numeric', width => '20%', title => 'Components in FPC/Scaffold region'},

	       );
     foreach my $seq_name ( sort { $a cmp $b } keys %feature_hash ) {
	 
	 my $chr_url = $hub->url({'type'=>'Location','action' =>"Chromosome",'r'=>"$seq_name:1-1"});
	 $html      .= "<p><h3><a name=$seq_name>Chromosome: $seq_name</a></h3>";
	 
	 my @rows;
	 foreach my $entry ( sort { $$a{start} <=> $$b{start} } @{$feature_hash{ $seq_name }} ) {
	   push @rows, { region=>$$entry{url}, comment=>$$entry{comment}, count=>$$entry{cmp_count} };
	 }
	 my $table = $self->new_table(\@cols, \@rows, {
						       data_table        => 0,
						       margin            => '0.2em 0px',
						       exportable        => 0
						      });
	 $html .= $table->render;
	 $html .= "</p>";
     }     
 }




  #
  # End pair analysis to see if any regions can be linked(jt8)
  elsif ( $action eq 'end_pairs') {
     my @punches = @{$pa->fetch_by_punch_type( $action )};
     
     my %feature_hash = ();
     
     foreach my $punch ( @punches ) {
	 
	  my $slice_name  = $punch->name();
	  my ($comment, $linked_fpc_slice_name) = split(/#/, $punch->comment());

	  my ($chr_name, $chr_start, $chr_end) = $slice_name =~ /^(.*?):(.*?)-(.*)/;
	  my $region  = "$chr_name:$chr_start-$chr_end"; 
	  my ($linked_chr_name, $linked_chr_start, $linked_chr_end) = $linked_fpc_slice_name =~ /^(.*?):(.*?)-(.*)/;
	  my $linked_fpc_region  = "$linked_chr_name:$linked_chr_start-$linked_chr_end";
 
	  my $url        = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});
	  my $linked_url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$linked_fpc_region});
	  
	  # Add href for linked FPC around fourth word
	  my ($newtag, $ctg1, $ctg2) = ($comment =~ /(NEW:\s)?(\S+)\s+\S+\s+\S+\s+(\S+)/);
	  $ctg1 =~ s/(.*)/<a href='$url'        class='nodeco'>$1 ($chr_name)<\/a>/;
	  $ctg2 =~ s/(.*)/<a href='$linked_url' class='nodeco'>$1 ($linked_chr_name)<\/a>/;

	
	  # Add href end-tag after first word
	  $comment =~ s/(NEW)/<em style='color:blue'>$1<\/em>/ if ($newtag);
	  
	  push @{$feature_hash{ $chr_name }}, {start => $chr_start, comment => $comment, ctg1=>$ctg1, ctg2=>$ctg2};
	  
      }
     
     my @cols = ( { key => 'region1',      sort => 'string',  width => '20%', title => 'Region1'          },
		  { key => 'region2',      sort => 'string',  width => '20%', title => 'Region2'          },
		  { key => 'comment',      sort => 'numeric', width => '80%', title => 'Comment'          },
		  );

     $html .= &add_navmenu(\%feature_hash);

     foreach my $seq_name ( sort { $a cmp $b } keys %feature_hash ) {
       my $chr_url = $hub->url({'type'=>'Location','action' =>"Chromosome",'r'=>"$seq_name:1-1"});
       $html .= "<h3><a name='$seq_name'>Chromosome:$seq_name</a> </h3>";
       
       my @rows;
       foreach my $entry ( sort { $$a{start} <=> $$b{start} } @{$feature_hash{ $seq_name }} ) {
	 push @rows, {region1=>$$entry{ctg1}, region2=>$$entry{ctg2}, comment=>$$entry{comment}};
       }
       my $table = $self->new_table(\@cols, \@rows, {
						     data_table        => 0,
						     margin            => '0.2em 0px',
						     exportable        => 0
						    });
       $html .= $table->render;
       $html .= "</p>";      

     }     

 }


  elsif ( $action =~ /soma_map_unalig/ ) {
      my @punches = @{$pa->fetch_by_punch_type( $action )};
      
      my %feature_hash = ();
      
      my @columns = ( 
	  { key => 'source',         sort => 'string',   title => 'source'          },
	  { key => 'reg',            sort => 'string',   title => 'region'          },
	  { key => 'ctgs',           sort => 'numeric',  title => 'Num of ctgs aligned'          },
	  { key => 'frags',          sort => 'numeric',  title => 'Num of cut frags in ctgs'  },
	  { key => 'mean',           sort => 'numeric',  title => 'Avg combined size (bp)'    },
	  { key => 'gap',            sort => 'string',   title => 'Near Gap?'    },
	  );
      
      # sort the data out by chr
      my %data;
      foreach my $punch ( @punches ) {
	      
	  my $slice_name  = $punch->name();
	  my $comment     = $punch->comment();
	  my ($chr_name, $chr_start, $chr_end) = $slice_name =~ /^(.*?):(.*?)-(.*)/;
	  
	  push @{$data{$chr_name}}, {start    => $chr_start,
				     end      => $chr_end,
				     comment  => $comment,
	  };
	  
      }

      # Info on top of page
      $html .= "<h3><b style='text-decoration:underline'>Key</b>: </h3>".
	  "<ul><li>\"Source\" - the source for the soma genome map. ".
	  "<li>\"Region\"  - Region in assembly.  ".
	  "<li>\"Num of ctgs aligned\" - number of genome map contig fragments that align.  ".
	  "<li>\"Num of cut frags in ctgs\" - number of fragments cut by enzyme in region of contig that is not aligned .  ".
	  "<li>\"Avg combined size\" - the average size of each unaligned region in contig (combined individual frag size of each ctg then averaged).  ".
	  "<li>\"Near Gap\" - if unaligned region is near a gap (100kb window).  </ul>".
	  "<h3>Jump to Chromosome: </h3>";

      $html .= &add_navmenu(\%data);

      foreach my $chr ( sort {$a <=> $b} keys %data){
	  my @entries  = @{$data{$chr}};
	  $html .= "<h3><a name=$chr>Chromosome: $chr</a></h3>";

	  my @rows;

	  for (my $i=0;$i<@entries;$i++){
	      my $sr_start  = $entries[$i]->{start};
	      my $sr_end    = $entries[$i]->{end};
	      my $comment   = $entries[$i]->{comment};

	      my $region  = "$chr:$sr_start-$sr_end";
	      my $url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});	  
	      my $html= qq(<a href=$url>$region</a>);

	      my ($line_tag, $ctgpieces, $frags, $meansize, $neargap) = split (/:/, $comment);
	  
	      my $data = {    source     => $line_tag,
			      reg        => $html,
			      ctgs       => $ctgpieces,
			      frags      => $frags,
			      mean       => $meansize,
			      gap        => ($neargap) ? "yes" : "no",
      
	      };

	      push @rows, $data;
	  }
	 
	  my $table = $self->new_table(\@columns, \@rows, {
	      data_table        => 1,
	      sorting           => [ 'source asc' ] ,
	      exportable        => 0
				       });
	  
	  $html .= $table->render;
	  
      }
 }



 #
 # Punchlist for Optical Map Fragments not aligned to the genome.
 elsif ( $action =~ /op_map_unalign/ ) {
     my @punches = @{$pa->fetch_by_punch_type( $action )};
     
     my %feature_hash = ();
     
     my %chr;
     my @columns = ( 
		     { key => 'cellline',       sort => 'string',   title => 'Cell line'          },
		     { key => 'ctgs',           sort => 'numeric',  title => 'Num of ctgs aligned'          },
		     { key => 'frags',          sort => 'numeric',  title => 'Num of cut frags in ctgs'  },
		     { key => 'mean',           sort => 'numeric',  title => 'Avg combined size (bp)'    },
		     { key => 'gap',            sort => 'string',   title => 'Near Gap?'    },
		     { key => 'outliers',       sort => 'string',   title => 'Outliers'        },
		     );
     

     foreach my $punch ( @punches ) {
	 
	  my $slice_name  = $punch->name();
	  my $comment     = $punch->comment();
	  my ($chr_name, $chr_start, $chr_end) = $slice_name =~ /^(.*?):(.*?)-(.*)/;
	  
	  my $region  = "$chr_name:$chr_start-$chr_end";
	  my $url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});	  
	  
	  my ($line_tag, $ctgpieces, $frags, $meansize, $neargap, $outliers) = split (/:/, $comment);

	  my $data = {    cell_line  => $line_tag,
			  ctgpieces  => $ctgpieces,
			  frags      => $frags,
			  mean       => $meansize,
			  neargap    => $neargap,
			  outliers   => $outliers || undef,
			      
		      };	 
	  
	  push @{$feature_hash{ $chr_name }{$region}{data}}, $data; 
	  $feature_hash{$chr_name}{$region}{url}   = $url;
	  $feature_hash{$chr_name}{$region}{start} = $chr_start;
	
	  $chr{$chr_name}++;

      }
     
     # Info on top of page
     $html .= "<h3><b style='text-decoration:underline'>Key</b>: </h3>".
	       "<ul><li>\"Cell line\" - the cell line used to produce the optical map. ".
	       "<li>\"Num of ctgs aligned\" - number of optical map contig fragments that align.  ".
	       "<li>\"Num of cut frags in ctgs\" - number of fragments cut by enzyme in region of contig that is not aligned .  ".
	       "<li>\"Avg combined size\" - the average size of each unaligned region in contig (combined individual frag size of each ctg then averaged (outliers removed).  ".
	       "<li>\"Outliers\" - outlier sizes pulled out from set according to Grubbs Test.</ul>";
     $html .= "<h3>Jump to Chromosome: </h3>";
     
     # Link to indiv Chr.
     foreach my $chrtarget (sort {$a <=> $b} keys %chr){
	 my $anchor = "<a href='#$chrtarget'>$chrtarget</a>&nbsp;";
	 $html .= $anchor;
     }
     
     foreach my $seq_name ( sort { $a cmp $b } keys %feature_hash ) {
	 
	 $html .= "<h3><a name='$seq_name'> Chromosome: $seq_name </h3>";
	 
	 my %region_Data = %{$feature_hash{$seq_name}};

	 foreach my $region (sort {$region_Data{$a}{start} <=> $region_Data{$b}{start} }keys %region_Data ) {
	     my @rows;
	     my @ctgdata = @{$region_Data{$region}{data}};
	     my $url = $region_Data{$region}{url};
	     
	     $html .= "<h4><a href='$url'>$region</a></h4>";
	     
	     foreach my $data_ref ( sort { $a->{cell_line} cmp $b->{cell_line} || $b->{ctgpieces} <=> $a->{ctgpieces} } @ctgdata){
		 my $cellline = $data_ref->{cell_line};
		 my $ctgs     = $data_ref->{ctgpieces};
		 my $frags    = $data_ref->{frags};
		 my $mean     = $data_ref->{mean};
		 my $gap      = $data_ref->{neargap};
		 my $outliers = $data_ref->{outliers} || "";
		 
		 my $cellline_color;
		 if ($cellline =~ /15510/)    { $cellline_color = {value=>$cellline, style=>'background-color:#D7DF01'} }
		 elsif ($cellline =~ /18994/) { $cellline_color = {value=>$cellline, style=>'background-color:#01DFD7'} }
		 elsif ($cellline =~ /10860/) { $cellline_color = {value=>$cellline, style=>'background-color:#F79F81'} }
		 else { $cellline_color = $cellline; }

		 my $gapcol = {value=>"n"};
		 $gapcol    = {value=>"y", style=>'color:blue'} if ($gap);		     
		
		 my $row = {
		     cellline       => $cellline_color,
		     ctgs           => $ctgs,
		     frags          => $frags,
		     mean           => $mean,
		     gap            => ($gap) ? {value=>"y", style=>'color:blue'} : {value=>"n"},
		     outliers       => $outliers,          
		 };
		 
		 push @rows, $row;
	     }

	     my $table = $self->new_table(\@columns, \@rows, {
		 #data_table        => 1,
		 sorting           => [ 'cellline asc' ] ,
		 exportable        => 0
		 });

	     $html .= $table->render;
	     
	 }
     }
     
 }
  

  #   
  # This punchlists lists all the regions on the chromosomes where there are no OM alignments, and if its due to region with many gaps.   
  elsif ( $action =~ /no_om_regions/ ) {

     my @punches = @{$pa->fetch_by_punch_type( $action )};
     
     my @columns = ( 
		     { key => 'chr',            sort => 'numeric',   title => 'Chr'          },
		     { key => 'region',         sort => 'position',  title => 'Region'       },
		     { key => 'length',         sort => 'numeric',   title => 'Length'       },
		     { key => 'perc',           sort => 'string',    title => 'Percent of Region that is Gap (ie 0% = no gap)'       },

		     );
    
     my @rows;
     my $textcolor;
     my $prev_chr = "";
     my $count    = 1;
     
     foreach my $punch ( sort { $a->name <=> $b->name} @punches ) {


	 my $slice_name  = $punch->name();
	 my $comment     = $punch->comment();
	 my ($chr_name, $chr_start, $chr_end) = $slice_name =~ /^(.*?):(.*?)-(.*)/;
	 
	 # Used to alternate colours between chromosome names.
	 $count++ if ($chr_name ne $prev_chr);
	 
	 my $length  = $chr_end - $chr_start +1;
	
	 my $region  = "$chr_name:$chr_start-$chr_end";
	 my $url_obj = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});
	 my $url     = "<a href='$url_obj'>$region</a>";

	 my $row = {
	     chr       => ($count % 2) ? {value=>$chr_name, style=>'color:blue'} : {value=>$chr_name, style=>'color:green'},
	     region    => $url,
	     length    => $length,
	     perc      => $comment,
	 };
	 
	 push @rows, $row;
	 
	 $prev_chr = $chr_name;
	     
     }	 
     my $table = $self->new_table(\@columns, \@rows, {
	 data_table        => 1,
	 sorting           => [ 'chr asc', 'region asc'] ,
	 exportable        => 0
	 });
     
     $html .= $table->render;	      

  }
  elsif ($action =~ /gapmap_lg/){
      my @punches = @{$pa->fetch_by_punch_type( $action )};
  
      my %feature_hash = ();
      my @cols = (    { key => 'maploc',            sort => 'string',   title => 'MapLocation'             },
		      { key => 'mpoc',              sort => 'numeric',   title => 'Marker Proportion on Chr'        },
		      { key => 'chr',               sort => 'string',    title => 'Chr'         },
		      { key => 'orient',            sort => 'numeric',   title => 'Orientation'         },
		      { key => 'orient_r',          sort => 'numeric',   title => 'Orientation Rsquared'         },
	  );
      
      my @rows;
      foreach my $punch ( @punches ) {
	  my $name       = $punch->name();
	  my $comment    = $punch->comment();

	  #TEMP HACK for hashref until James fixes the input
	  $comment =~ s/\s+//g;
	  $comment =~ s/'//g;
	  my ($mpoc, $chr, $orient, $or) = ($comment =~ /.*marker_proportion_on_chromosome=>(.*),chromosome=>(.*),orientation=>(.*),orientation_r_squared=>(\w+\.{0,}\d{0,}).*/);

	  my $url_obj = $hub->url({'type'=>'Marker','action' =>"MarkerMapLocation",'map'=>"GAPMap", 'maploc' => $name});
	  my $url = "<a href=$url_obj class='nodeco'> $name</a>";	  

	  
	  push @rows, { maploc       => $url, 
			mpoc         => sprintf ("%.3f",$mpoc),
			chr          => $chr,
			orient       => $orient,
			orient_r     => sprintf ("%.3f", $or)

	  };
	  
      }
      my $table = $self->new_table(\@cols, \@rows, {
						    data_table        => 1,
						    sorting           => [ 'chr asc maploc asc' ] ,
						    exportable        => 1 
						   });
      
      $html .= $table->render;

  }
 
  elsif ($action =~ /cdnalist/){
      my @punches = @{$pa->fetch_by_punch_type( $action )};
  
      my %feature_hash = ();
      my @cols = (    { key => 'loc',                sort => 'string',    title => 'Location'             },
	      	      { key => 'cdna',               sort => 'string',    title => 'cDNA Name'         },
		      { key => 'cov',                sort => 'numeric',   title => 'Coverage'        },
		      { key => 'percid',             sort => 'numeric',   title => 'Percent ID'         },
		      { key => 'details',            sort => 'string',    title => 'Details'         },
	  );
      
      my @rows;
      foreach my $punch ( @punches ) {
	  my $region       = $punch->name();
	  my $comment    = $punch->comment();

	  my ($hit, $details, $percid, $cov) = split (/\|/, $comment);
	  
	  my $url_obj = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});
	  my $url     = "<a href=$url_obj class='nodeco'> $region</a>";	  

	  
	  push @rows, { loc         => $url, 
			cdna        => $hit,
			cov         => $cov,
			percid      => $percid,
			details       => $details,

	  };
	  
      }
      my $table = $self->new_table(\@cols, \@rows, {
						    data_table        => 1,
						    sorting           => [ 'chr asc maploc asc' ] ,
						    exportable        => 1 
						   });
      
      $html .= $table->render;

  }  


  elsif ($action =~ /incomplete_transc/){
      my @punches = @{$pa->fetch_by_punch_type( $action )};
  
      my %feature_hash = ();
      my @cols = (    { key => 'tname',            sort => 'string',   title => 'Transcript Name'                  },
		      { key => 'topcovloc',        sort => 'string',   title => 'Top Location based on coverage'                  },
		      { key => 'loc_cov',          sort => 'numeric',  title => 'Location/coverage of hits'        },

	  );
      my @rows;
      foreach my $punch ( @punches ) {
	  my $name       = $punch->name();
	  my $comment    = $punch->comment();
	  
	  my $url_obj = $hub->url({'type'   => "Location",
				   'action' => "Genome",
				   'ftype'  => "DnaAlignFeature", 
				   'db'     => "core", 
				   'id'     => $name});
	  my $url = "<a href=$url_obj class='nodeco'> $name</a>";	  

	  my @hits = split (/\|/, $comment);
	  my $hits_count = @hits;

	  @hits = map { s/(.*):(.*)/cov: $1 (loc:$2)/; $_ } @hits;

	  my $top_cov = $hits[0];	  
	  my $loc_cov = join ("<br>", @hits[1..$hits_count]);
	  
	  push @rows, { tname       => $url,
			topcovloc   => $top_cov,
			loc_cov     => $loc_cov
	  };
      }
      my $table = $self->new_table(\@cols, \@rows, {
	  data_table        => 1,
	  sort => 'string',   
	  title => 'Transcript Name'  ,               
	  sorting           => [ 'tname asc' ] ,
	  exportable        => 1 
	  });
      
      $html .= $table->render;
      
      
  }

  elsif ($action =~ /transcript_orphans/){
      my @punches = @{$pa->fetch_by_punch_type( $action )};
  
      my %feature_hash = ();
      my @cols = (    { key => 'tname',            sort => 'string',    width=>'40%',   title => 'Transcript Name'                  },
		      { key => 'unloc',            sort => 'string',    width=>'5%',   title => 'Unlocalized/Unplaced Location'        },
		      { key => 'cmp',              sort => 'string',    width=>'5%',   title => 'Compoonent'    },
		      { key => 'alt',              sort => 'string',    width=>'50%',   title => 'Contains hits in other locations with weaker coverage' },

	  );
      my @rows;
      foreach my $punch ( @punches ) {
	  my $name       = $punch->name();
	  my $comment    = $punch->comment();
	  
	  my $url_obj = $hub->url({'type'   => "Location",
				   'action' => "Genome",
				   'ftype'  => "DnaAlignFeature", 
				   'db'     => "core", 
				   'id'     => $name});
	  my $url = "<a href=$url_obj class='nodeco'> $name</a>";	  

	  my $alt = undef;
	  if ($comment =~ /\*/){
	      $alt = "<img src='/i/16/check.png' style='height:80%'/>";
	  }
	  
	  my ($toplevelname, $cmp) = ($comment =~ /(.*)\((.*)\)/);

	  push @rows, { tname       => $url,
			unloc       => $toplevelname,
			cmp         => $cmp,
			alt         => $alt,
	  };
      }
      my $table = $self->new_table(\@cols, \@rows, {
	  data_table        => 1,
	  sorting           => [ 'tname asc' ] ,
	  exportable        => 1,
	  #width             => '80%'
				   });
      
      $html .= $table->render;
      
      
  }
  
  # Genome Builder chain Data
  elsif ($action =~ /om_chain/){
      my @punches = @{$pa->fetch_by_punch_type( $action )};

      my %feature_hash = ();
      my @cols = (    { key => 'score',              sort => 'numeric',   title => 'Score'             },
                      { key => 'chain',              sort => 'string',    title => 'Chain Order'        },
          );

      my @rows;	
      my @color_code = ("black", "green", "blue", "red", "orange", "purple");	

      foreach my $punch ( @punches ) {
          my $name       = $punch->name();
          my $comment    = $punch->comment();

	  my @chain = split (/\|/, $comment);

	  my $count = 0;
	  my $prev_entry;
	  my @format_chain;
	  foreach my $tag (@chain){
		my ($name, $region, $ori, $fori) = ($tag =~ /(.*):(.*):(\d+)\((\d+)\)/);
		$count++ if ($name ne $prev_entry);
	        my $url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$name.":".$region});
	        my $id = "<span style='color:".$color_code[$count]."'>$tag</span>&nbsp;&nbsp;&nbsp;<a href=$url class=nodeco>[r]</a>";
		push @format_chain, $id;
		$prev_entry = $name;

		$count = 0 if ($count == 5);
	  }

          push @rows, { score         => $name,
                        chain         => join ("<br>", @format_chain),

	  };
       }	

      my $table = $self->new_table(\@cols, \@rows, {
          data_table        => 1,
          sorting           => [ 'score desc' ] ,
          exportable        => 1,
                                   });

      $html .= $table->render;

  }
  # Genome Builder Join Data
  elsif ($action =~ /om_join/){
      my @punches = @{$pa->fetch_by_punch_type( $action )};

      my %feature_hash = ();
      my @cols = (    { key => 'score',                 sort => 'numeric',  width => '12%',  title => 'Score'         },
                      { key => 'gap',                   sort => 'numeric',  width => '12%',  title => 'Gap Size(kb)'  },
                      { key => 'chr',                   sort => 'numeric',  width => '12%',  title => 'TopLevel'      },		      
                      { key => 'scaf1',                 sort => 'string',   width => '30%',  title => 'Scaffold 1'    },
                      { key => 'ori1',                  sort => 'numeric',  width => '5%',   title => 'Ori 1'         },
                      { key => 'scaf2',                 sort => 'string',   width => '30%',  title => 'Scaffold 2'    },
                      { key => 'ori2',                  sort => 'numeric',  width => '5%',   title => 'Ori 2'         },
                      { key => 'scaftag',               sort => 'numeric',  width => '6%',   title => 'Diff Scaf?'    },
          );

      my @rows;
      foreach my $punch ( @punches ) {
          my $name       = $punch->name();
          my $comment    = $punch->comment();

          my @f = split (/\|/, $comment);

	  # Project toplevel
	  my ($name1, $start1, $end1, $ori1)  = ($f[1] =~ /(\w+_{0,1}\w+\.{0,1}\w+):(\d+)-(\d+):(\d)/);
	  my ($name2, $start2, $end2, $ori2)  = ($f[3] =~ /(\w+_{0,1}\w+\.{0,1}\w+):(\d+)-(\d+):(\d)/);	  

	  my $scaf1_slice   =  $sa->fetch_by_region('scaffold', $name1, $start1, $end1, $ori1) if ($name1);
	  my $scaf2_slice   =  $sa->fetch_by_region('scaffold', $name2, $start2, $end2, $ori2) if ($name2);	

	  my ($scaf1_proj, $scaf2_proj);
	  my ($scaf1_toplev_loc, $scaf2_toplev_loc);
          if ($scaf2_slice || $scaf1_slice){
	    
	      if ($scaf1_slice){
		  my ($proj1)  =  @{$scaf1_slice->project('toplevel')};	   
		  $scaf1_proj  = $proj1->to_Slice->seq_region_name. ":". $proj1->to_Slice->start. "-". $proj1->to_Slice->end;
		  $scaf1_toplev_loc = $proj1->to_Slice->seq_region_name;
	      }
	      if ($scaf2_slice){
		  my ($proj2)  =  @{$scaf2_slice->project('toplevel')};       
		  $scaf2_proj = $proj2->to_Slice->seq_region_name. ":". $proj2->to_Slice->start. "-". $proj2->to_Slice->end;
		  $scaf2_toplev_loc = $proj2->to_Slice->seq_region_name;		  
	      }
	  }
			
	  my $scaf1_url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$f[1]});	
          my $scaf2_url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$f[3]});  
	  
	  my ($header1) = ($f[1] =~ /(.*):.*:\d+/); 
	  my ($header2) = ($f[3] =~ /(.*):.*:\d+/); 

	  my $scaf_tag = ($header1 ne $header2) ? "yes" : undef;

          push @rows, { score         => $name,
			gap           => $f[0],
			chr           => ( $scaf1_toplev_loc  eq  $scaf2_toplev_loc ) ? "-$scaf1_toplev_loc-" : "-$scaf1_toplev_loc/$scaf2_toplev_loc-", 
			scaf1         => "<a href=$scaf1_url class=nodeco> $f[1]</a><br>$scaf1_proj" ,
			ori1          => $f[2],
			scaf2         => "<a href=$scaf2_url class=nodeco> $f[3]</a><br>$scaf2_proj" , 
			ori2          => $f[4],
			scaftag       => $scaf_tag,
          };
       }        
  
      my $table = $self->new_table(\@cols, \@rows, {
          data_table        => 1,
          sorting           => [ 'score desc' ] ,
          exportable        => 1,
          #width             => '80%'
                                   });

      $html .= $table->render;
  }

  elsif ($action =~ /soma_unaligned/){
      my @punches = @{$pa->fetch_by_punch_type( $action )};
      
      my @cols = (     { key => 'region',                   sort => 'position',  width => '',  title => 'Region'                 },
		       { key => 'mapctg',                   sort => 'string',    width => '',  title => 'Contig Map Name'        },
		       { key => 'fragcount',                sort => 'numeric',   width => '',  title => 'Fragment count'         },		       
		       { key => 'fragsize',                 sort => 'numeric',   width => '',  title => 'Total Fragment size'    },
		       { key => 'idx_range',                sort => 'string',    width => '',  title => 'Fragment Range'  },	
		       { key => 'link',                     sort => 'string',    width => '',  title => 'List View'              },
		       
          );

      my %filt_list;
      foreach my $punch ( @punches ) {
          my $slice_name  = $punch->name();
          my $comment     = $punch->comment();

          my ($chr_name, $chr_start, $chr_end) = ($slice_name =~ /^(.*?):(.*?)-(.*)/);
	  my ($mapctg, $size, $range) = split (":", $comment);
	  
	  push @{$filt_list{$chr_name}}, { start      => $chr_start,
					   end        => $chr_end,
					   region     => $slice_name,
					   mapctg     => $mapctg,
					   fragsize   => $size,
					   idx_range  => $range,
	  };	  
      }

      foreach my $chr ( sort {$a cmp $b} keys %filt_list){
	  my @entries = @{$filt_list{$chr}};
	  my @rows;
	  $html .= "<h2> Chromosome: $chr</h2>";
	  foreach my $entry (sort {$$a{start} <=> $$b{start}} @entries){
	      
	      my $region   = "$chr:". ($$entry{start}-500)."-". ($$entry{start}+500);
	      my $listview_url = $hub->url({'species' => $hub->species, 'type' => 'Location', 'action' => 'Soma', 'r'=>$region, 'mapname' => $$entry{mapctg}});
	      my $region_url   = $hub->url({'species' => $hub->species, 'type'=>'Location','action' =>"View",'r'=>$region});

	      my ($start_idx, $end_idx) = ($$entry{idx_range} =~ /(\d+)-(\d+)/);
	      my $total_frags = $end_idx - $start_idx +1;

	      my $row  =  { mapctg     => $$entry{mapctg},
			    region     => "<a href=$region_url>$$entry{region}</a>",
			    fragcount  => $total_frags,
			    fragsize   => $$entry{fragsize},
			    idx_range  => $$entry{idx_range},
			    link       => "<a href=$listview_url>View</a>",
	      };
	      push @rows, $row;
	  }
	  my $table = $self->new_table(\@cols, \@rows, {
	      data_table        => 1,
	      sorting           => [ 'start asc' ] ,
	      #width             => '60%',
	      exportable        => 1 
				       });
	  
	  $html .= $table->render; 
	  
      }     
  }



  elsif ($action =~ /soma_inversions/){
      my @punches = @{$pa->fetch_by_punch_type( $action )};

      my @cols = (    { key => 'mapctg',                  sort => 'string',   width => '',  title => 'Contig Map Name'        },
                      #{ key => 'start',                   sort => 'numeric',  width => '',  title => 'Region Start'           },
                      #{ key => 'end',                     sort => 'numeric',  width => '',  title => 'Region End'             },		      
                      { key => 'scores',                  sort => 'string',   width => '',  title => 'Scores'                 },
		      { key => 'aligned',                 sort => 'numeric',  width => '',  title => 'Aligned Fragments'      },		      
                      { key => 'unaligned',               sort => 'numeric',  width => '',  title => 'Unaligned Fragments'    },
                      { key => 'link',                    sort => 'string',   width => '',  title => 'List View'              },
		      

          );
      
      my %filt_list;
      foreach my $punch ( @punches ) {
          my $slice_name  = $punch->name();
          my $comment     = $punch->comment();
          my ($chr_name, $chr_start, $chr_end) = ($slice_name =~ /^(.*?):(.*?)-(.*)/);
	  #contig414_1:27.095652,4.027191:86:110
	  my ($mapctg, $scores, $aligned_count, $unaligned_count) = split (":", $comment);
	  
	  my @s = map {sprintf ("%.1f", $_) } split(",", $scores);
	  $scores = join (", ",@s);
	  push @{$filt_list{$chr_name}}, { start      => $chr_start,
					   end        => $chr_end,
					   mapctg     => $mapctg,
					   scores     => $scores,
					   aligned    => $aligned_count,
					   unaligned  => $unaligned_count,
	  };
	  
      }
      
      foreach my $chr ( sort {$a cmp $b} keys %filt_list){
	  my @entries = @{$filt_list{$chr}};
	  my @rows;
	  $html .= "<h2> Chromosome: $chr</h2>";
	  foreach my $entry (sort {$$a{start} <=> $$b{start}} @entries){

	      my $r   = "$chr:".$$entry{start}."-".$$entry{end};
	      my $url = $hub->url({'species' => $hub->species, 'type' => 'Location', 'action' => 'Soma', 'r' => $r, 'mapname' => $$entry{mapctg}});

	      my $row  =  { mapctg     => $$entry{mapctg},
			    scores     => $$entry{scores},
			    aligned    => $$entry{aligned},
			    unaligned  => $$entry{unaligned},
			    link       => "<a href=$url>View</a>",
	      };
	      push @rows, $row;
	  }
	  my $table = $self->new_table(\@cols, \@rows, {
	      data_table        => 1,
	      sorting           => [ 'start asc' ] ,
	      #width             => '60%',
	      exportable        => 1 
				       });
	  
	  $html .= $table->render; 
	  	  
      }

      
  }
  
  elsif ($action =~ /indel\w+bn/i){
      my @punches = @{$pa->fetch_by_punch_type( $action )};

      my @cols = (     { key => 'region',                   sort => 'position',  width => '',  title => 'Region'                 },
		       { key => 'mapctg',                   sort => 'string',    width => '',  title => 'Contig Map Name'        },
		       { key => 'type',                     sort => 'string',    width => '',  title => 'Type'         },		       
		       { key => 'size',                     sort => 'numeric',   width => '',  title => 'Indel size'    },
		       { key => 'score',                    sort => 'numeric',   width => '',  title => 'Confidence score'  },	
		       { key => 'orient',                   sort => 'string',    width => '',  title => 'Orientation'              },
#		       { key => 'labels',                   sort => 'numeric',   width => '',  title => 'Labels within indel'              },
		       { key => 'jira',                     sort => 'string',    width => '',  title => 'Jira Ticket'              },

          );
      
      my %filt_list;
      foreach my $punch ( @punches ) {
          my $slice_name  = $punch->name();
          my $comment     = $punch->comment();
	  
          my ($chr_name, $chr_start, $chr_end) = ($slice_name =~ /^(.*?):(.*?)-(.*)/);
	  my ($mapctg, $orient, $score, $value) = split (",", $comment);
	  
	  my ($type, $size, $labels, $unkwn) = ($value =~ /(\w+)_(\d+)I(\d+)D(\d+)/);
         
	  push @{$filt_list{$chr_name}}, { start      => $chr_start,
					   end        => $chr_end,
					   region     => $slice_name,
					   mapctg     => $mapctg,
					   orient     => $orient,
					   score      => $score,
					   type       => $type,
					   size       => $size,
					   labels     => $labels,
					   unkwn      => $unkwn,
	  };	  
      }

      foreach my $chr ( sort {$a <=> $b || $a cmp $b} keys %filt_list){
	  my @entries = @{$filt_list{$chr}};
	  my @rows;
	  $html .= "<h2> Chromosome: $chr</h2>";
	  foreach my $entry (sort {$$a{start} <=>  $$b{start}} @entries){
	      my $r   = "$chr:".$$entry{start}."-".$$entry{end};
	      my $url = $hub->url({'species' => $hub->species, 'type' => 'Location', 'action' => 'View', 'r' => $r, __clear=>1 });
	      my $href = "<a href=$url class=nodeco> $r</a>";

	      #---Add Jira---#
	      # - This should be removed eventually and added in the data in the db, as this actually slows down the load time -#
	      my $indel_slice = $adaptor->fetch_by_region('toplevel', $chr, $$entry{start}, $$entry{end});
	      
	      my $jiras;
	      if ($indel_slice){
		  my @mf = @{$indel_slice->get_all_MiscFeatures('jira_entry')};
		  my @jiranames = map {   $_->get_scalar_attribute('jira_id').
					      " (".$_->get_scalar_attribute('jira_status').
					      ")"} @mf if (@mf > 0);

		  $jiras = join ("<br>", @jiranames);
	      }
	      #--------------#
	      my $type;
	      if ($$entry{type} eq "insertion"){
		  $type = "<div style='color:blue'>".$$entry{type}."</div>";
	      }
	      else {
		  $type = "<div style='color:orange'>".$$entry{type}."</div>";
	      }
	      
	      my $row  =  { region     => $href,
			    mapctg     => $$entry{mapctg},
			    type       => $type,
			    size       => $$entry{size},
			    score      => $$entry{score},
			    orient     => $$entry{orient},
			    #labels     => $$entry{labels},
			    jira       => $jiras,
	      };
	      push @rows, $row;	     
	  }
	  my $table = $self->new_table(\@cols, \@rows, {
	      data_table        => 1,
	      sorting           => [ 'start asc' ] ,
	      #width             => '60%',
	      exportable        => 1 
				       });
     	  $html .= $table->render; 	  
      }
  }
  
  elsif ($feature_type eq "Slice"){

      my @unsorted_punches = @{$pa->fetch_by_punch_type( $action )};      
      my %feature_hash = ();

      my @cols = (    { key => 'region',            sort => 'position',  title => 'Region'           },
		      { key => 'comment',           sort => 'string',    title => 'Comment'        },
	  );
      
      my @rows;
      my @punches = map { $_->[0] }
                    sort {$a->[1] cmp $b->[1]}
                    map { $_->name =~ /(\w+):.*/; [$_, $1] }
                    @unsorted_punches;

      foreach my $punch ( @punches ) {
	  my $region       = $punch->name();
	  my $description  = $punch->comment();
	  my $url = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});
	  my $href = "<a href=$url class=nodeco> $region</a>";

	  push @rows, { region       => $href, 
			comment      => $description,   
	  };
      }

      my $table = $self->new_table(\@cols, \@rows, {
	  data_table        => 1,
          sorting           => [ 'region asc' ] ,
	  width             => '60%',
	  exportable        => 1 
				   });
      
      $html .= $table->render; 
  }
  
 # 
 # OPTION: Everything Else ::: Standardized as returning coordiates and the comment .

  else {
    my @punches = @{$pa->fetch_by_punch_type( $action )};
  
    my %feature_hash = ();

    foreach my $punch ( @punches ) {

      my $dbID    = $punch->name();
      my $feature = $adaptor->fetch_by_dbID( $dbID );
      my $top_level_proj  = $feature->project('toplevel');
      if (!($top_level_proj->[0])){next;}

      my $top_level_slice = $top_level_proj->[0]->to_Slice;
      my $top_level_name  = $top_level_slice->seq_region_name;
      my $top_level_start = $top_level_slice->start;
      my $top_level_end   = $top_level_slice->end;

      if ($action eq "false_gap"){
	$top_level_start   -= 50000;
	$top_level_end     += 50000;
      }

      my $region = "$top_level_name:$top_level_start-$top_level_end";
      my $url    = $hub->url({'type'=>'Location','action' =>"View",'r'=>$region});
      
      my $entry_name    = ($action eq "prob_dbljoin" || $action eq "false_gap" || $punch_type->feature_type =~ /MiscFeature/i ) ? $punch->comment : $feature->hseqname;    
      my $comment       = $punch->comment;
      my $reg_entry     = "<a href=$url class='nodeco'>$region</a>";
      
      my ($var, $osize);
      if ( $action eq "overlap_hi_var" ) {
	my $overlap_variation = sprintf("%3.2f", 100 - $feature->percent_id());
	my $size = $top_level_end - $top_level_start + 1;

	#$entry_name .= " -- Variation: $overlap_variation% Size: $size bp \n";
	
	# Add End support tag
	$entry_name .= " <i style='color:blue'>[end support]</i>" if ($punch->comment =~ /end support/);
	($var, $osize) = ($overlap_variation, $size);
      }

      push @{$feature_hash{ $top_level_name }}, {start => $top_level_start, region => $reg_entry, comment=>$comment, entry => $entry_name, var => $var, size=>$osize};
      
    }

    $html .= &add_navmenu(\%feature_hash);
    
    my @cols = (    { key => 'chr',            sort => 'numeric',  title => 'Chr'           },
		    { key => 'region',         sort => 'position',   title => 'Region'        },
		    { key => 'comment',        sort => 'string',   title => 'Comment'       },
	       );
    push @cols, ({key=>'cmp1', sort=>'string', title=>'Component1'},  
		 {key=>'cmp2', sort=>'string', title=>'Component2'},  
		 {key=>'variation', sort=>'position_html', title=>'Variation'},
		 {key=>'size', sort=>'numeric', title=>'Size'} )
      if ( $action eq "overlap_hi_var");

    foreach my $seq_name ( sort { $a cmp $b } keys %feature_hash ) {
      
      $html .= "<h3><a name=$seq_name>Chromosome: $seq_name</a></h3>";
      my @rows;
      foreach my $entry ( sort { $$a{start} <=> $$b{start} } @{$feature_hash{ $seq_name }} ) {
	my ($cmp1, $cmp2) = split(" vs ", $$entry{comment});
	if ($$entry{var} && $$entry{size}){
	  my $var = $$entry{var};
          $var = ($var>=0.4 && $var<=2) ? "<strong style='color:#AEB404'>$var</strong>" : "<strong style='color:#B40404'>$var</strong>";			
	  push @rows, { chr       => $seq_name, 
			region    => $$entry{region}, 
			comment   => $$entry{entry}, 
			variation => $var,
			size      => $$entry{size},
			cmp1      => $cmp1,
			cmp2      => $cmp2,
		      };
	}
	else { 
	  push @rows, { chr =>$seq_name, region=> $$entry{region}, comment   => $$entry{comment} };
	}
      }
      my $table = $self->new_table(\@cols, \@rows, {
						    data_table        => 1,
						    #width             => '60%',
						    exportable        => 1 
						   });
      
      $html .= $table->render;
      
    }
    
  }
  
  
  return $html;
}

sub jira_colours {
  my $status = shift;
  
  return "#5F04B4" if ($status eq "Awaiting Elec Data"); 
  return "#8904B1" if ($status eq "Awaiting Exptl Data");
  return "#DF0174" if ($status eq "Continuing Investigation");
  return "#DF3A01" if ($status =~ /Open|Reopened/);
  return "#FF0000" if ($status eq "Stalled");
  return "#0404B4" if ($status eq "Under Review");
  
  return "#1C1C1C";

}

sub add_navmenu {
  my $hash_ref    =  shift;
  my %features  = %$hash_ref;
 
  my $html;
  $html .= qq( <form name=myForm> <select name=mySelect onChange="location.href=myForm.mySelect.options[myForm.mySelect.selectedIndex].value">);
  $html .= qq(<option> --Jump to Chr-- </option>);
  
  foreach my $seq_name ( sort { $a cmp $b } keys %features ){
    $html .= "<option value='#$seq_name'>$seq_name</option>";
  }
  $html .= qq(</select></form>);
  $html .= "<hr>";

  return $html;
}




sub configuration {
  return "";
}

sub content_panel {
  return "";
}

1;
