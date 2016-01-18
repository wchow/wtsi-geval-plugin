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

# wc2@sanger.ac.uk.
# code to return a page of the marker map location.  Sort of the genetic map ordering with the mapping whereabouts.
# Apr, 2014

package EnsEMBL::Web::Component::Marker::MarkerMapLocation;

use strict;
use base qw(EnsEMBL::Web::Component);
use EnsEMBL::Web::Object;

#----------------------------#
# _init.                      #
# initiate MarkerMapLocation #
#  page.                     #
#----------------------------#
sub _init {
  my $self = shift;

  #--Pre-emptive strike for SATMap results as this ranges in the thousands--#
  my $markers   = $self->object->Obj if ($self->object);
  my ($marker)  = @$markers          if ($markers);
  
  my $map_name;
  # -- for non-marker id links, using param map/maploc --#
  if (!$markers){
      my $hub    = $self->hub;
      $map_name  = $hub->param('map');
  }
  #-- else using direct link from marker/marker_id -–#
  else {
      my ($ml)      = @{$marker->get_all_MapLocations};
      $map_name     = $ml->map_name;  
  }
  return  if ($map_name =~ /SATMap/i);
  #----#

  #-- Let er spin --#
  $self->ajaxable(1);

}

#---------------------------------#
# content.
# Main code for the table page.   #
#---------------------------------#
sub content {
  my $self    = shift;
  my $markers = $self->object->Obj if ($self->object);
  my $hub     = $self->hub;
  my $species = $hub->species;

  #-- for direct non-marker id html links --#
  my $mm_param      = $hub->param('maploc');
  my $map_param     = $hub->param('map');
  #--

  my $html;
  my ($loc_chr_name, $loc_position, $map_name);

  #--Prepare table--#
  my @cols = ( {key=> 'mloc',     sort=> 'none',  title=> 'Marker Map Location' },
	       {key=> 'map',      sort=> 'none',  title=> 'Map'},
	       {key=> 'mname',    sort=> 'none',  title=> 'Marker Name'},
	       {key=> 'pos',      sort=> 'none',  title=> 'Map Position'},
	       {key=> 'loc',      sort=> 'none',  title=> 'Mapped Location'},
      );
  #-----------------#

  #-- for direct non-marker id links --#
  if ($mm_param && $map_param) {
      $loc_chr_name = $mm_param;
      $map_name     = $map_param;
  }
  #-- link from marker obj/marker_id --#
  else {
      return '<h3>Oops Something wrong with the marker link</h3>' unless scalar @$markers;
  
      my ($marker)  = @$markers;      
      my ($ml)      = @{$marker->get_all_MapLocations};
  
      return '<h3> This marker is not associated with a MapLocation </h3>' if (!$ml);
      
      $loc_chr_name   = $ml->chromosome_name || return '<h3> This marker does not have a chromosome_name</h3>';
      $loc_position   = $ml->position        || ""; 
      $map_name       = $ml->map_name        || return '<h3> Oops, marker is not associated with a  map</h3>';
  }
  #--

  return "<h3>This feature is currently unavailable for the SATMap Map</h3>".
      "<h3> If you would like this information please contact <a href='mailto:geval-help\@sanger.ac.uk'>gEVAL-help</a> for a data dump.</h3>"
      if ($map_name =~ /SATMap/i);
  



  #-- Fetch Linkage group stats if any--#
  use Bio::EnsEMBL::DBSQL::PunchTypeAdaptor;
  Bio::EnsEMBL::DBSQL::PunchTypeAdaptor->init( $self->hub->species_defs->valid_species() );
  use Bio::EnsEMBL::DBSQL::PunchAdaptor;
  Bio::EnsEMBL::DBSQL::PunchAdaptor->init( $self->hub->species_defs->valid_species() );
  
  my $pta =  $self->hub->database('core')->get_PunchTypeAdaptor();
  my $pa  =  $self->hub->database('core')->get_PunchAdaptor();

  my  ($marker_prop, $pred_chr, $pred_orient, $rsq)    = &fetch_map_stats_from_punch($hub, $loc_chr_name, $pa);

  $html .= "<div>".
      "<strong>Marker Proportion:  </strong><em>$marker_prop</em><br>".
      "<strong>Predicted Chr:  </strong><em>$pred_chr</em><br>".
      "<strong>Predicted Orientation:  </strong><em>$pred_orient</em><br>".
      "<strong>Orientation Rsquared:  </strong><em>$rsq</em><br>".
      "</div>" if ($marker_prop ||  $pred_chr|| $pred_orient || $rsq);



  #---Sanity Count---#
  my $count   =   &count_markers($hub, $species, $loc_chr_name, $map_name);  
  return "<h3>Marker Map Location limits the view to 1000 features per top level component</h3>".
      "<h3> If you would like this information please contact <a href='mailto:geval-help\@sanger.ac.uk'>gEVAL-help</a> for a data dump.</h3>"
      if ($count >1000);
  #------------------#
  
  my $results   =   &fetch_markers_by_chr_and_map($hub, $species, $loc_chr_name, $map_name);

  $html .= "<style> a {text-decoration:none} a.noref:link{color:grey}</style>";

  my @rows;
  foreach my $count (sort {$a <=> $b  ||  @{$$results{$a}{mappings}} <=> @{$$results{$b}{mappings}}
		     } keys %$results){

      my $pos          = $$results{$count}{position};
      my $marker_name  = $$results{$count}{name};
      my @locations    = @{$$results{$count}{mappings}};
      my $locations_to_report = "<table style='width:100%;border: 0px none none;border-spacing:0px'>".
	  join ("", @locations).
	  "</table>";
      
      my $marker_url = $hub->url({'type'=>'Marker','action'=>'Details','m'=>"$marker_name"});
 
      push @rows, { mloc      => $loc_chr_name,
		    map       => $map_name,
		    mname     => qq(<a href="$marker_url">$marker_name</a>),
		    pos       => $pos,
		    loc       => $locations_to_report || "no mappings",
		    #cmp       => scalar @locations,
      };      
  }

  my $table = $self->new_table(\@cols, \@rows, {
      data_table        => 1,
      exportable        => 1
			       });
  $html .= $table->render;
  return $html;
}



#------------------------------#
# count_markers.               #
# Return the number of marker  #
#  features quickly.           #
#------------------------------#
sub count_markers {
    my ($hub, $species, $chr, $map) = @_;
    my $db = $hub->databases->get_DBAdaptor('core', $species);

    return "No database adaptor connection" if (!$db);

    my $dbc = $db->dbc;
    my $sql = qq(SELECT count(*) FROM marker_map_location INNER JOIN map using (map_id) WHERE chromosome_name = "$chr" AND map_name = "$map" ORDER BY position);
    
    my $sth = $dbc->prepare($sql);
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
    $sth->finish();
    return $count;
}


#-------------------------------------------#
# fetch_markers_by_chr_and_map.             #
# EnsemblAPI doesn't have this method.      #
# Fetch all markers by chromosome name      #
#  (from map_location) and map_id/map_name  #
# Sort and append html.
#-------------------------------------------#
sub fetch_markers_by_chr_and_map {

    my ($hub, $species, $chr, $map) = @_;
    my $db = $hub->databases->get_DBAdaptor('core', $species);
    # die gracefully
    return "No database adaptor connection" if (!$db);

    #--- Again no ensembl code for this, straight up dbc call ---#
    my $dbc = $db->dbc;
    my $sql = qq(SELECT marker_id FROM marker_map_location INNER JOIN map using (map_id) WHERE chromosome_name = "$chr" AND map_name = "$map" ORDER BY position);
    
    my $sth = $dbc->prepare($sql);
    $sth->execute();

    my @marker_ids;
    while (my @row = $sth->fetchrow_array){
	push @marker_ids, $row[0];
    }
    $sth->finish();
    
    my $ma         = $db->get_MarkerAdaptor();
    my $csa        = $db->get_CoordSystemAdaptor();
    my $scafcsname = undef;

    #-- for adaptation to other assemblies --#
    if (@{$csa->fetch_all_by_name('fpc_contig')} > 0) {
	$scafcsname   = "fpc_contig";
    }
    elsif (@{$csa->fetch_all_by_name('supercontig')} > 0){
	$scafcsname   = "supercontig";
    }
    elsif (@{$csa->fetch_all_by_name('scaffold')} > 0){
	$scafcsname   = "scaffold";
    }
    
    my %results;
    my %finalResults;

    foreach my $id (@marker_ids){
	my $f = $ma->fetch_by_dbID($id);

	my $display_name    = $f->display_MarkerSynonym->name;
	my $position        = $f->get_MapLocation($map)->position;
	my @mfs   = @{$f->get_all_MarkerFeatures};
	
	#-- Report features where the count is between 1 and 3.
	if (@mfs > 3){
	    $finalResults{$id} = {'name'      => $display_name,
				  'mappings'  => ["over 3 mappings"],
				  'position'  => $position,
		};
	}
	elsif (@mfs == 0 ){
	    $finalResults{$id} = {'name'      => $display_name,
				  'mappings'  => [],
				  'position'  => $position,
	    };
	}
	else {
	    
	    my @locations;

	    #--fetch appropriate data out of markerfeatures --#
	    foreach (sort {$a->project('toplevel')->[0]->to_Slice->seq_region_name cmp $b->project('toplevel')->[0]->to_Slice->seq_region_name}
		     @mfs){
		my $topsr_slice = $_->project('toplevel')->[0]->to_Slice;
		my $srname      = $topsr_slice->seq_region_name;
		my $srstart     = $topsr_slice->start;
		my $srend       = $topsr_slice->end;
		my $cmpname     = $_->seq_region_name;
		my ($acc)       = @{$_->project('clone')->[0]->to_Slice->get_all_Attributes('accession')};
		my $istoplevel  = $topsr_slice->is_toplevel();

		next if (!$istoplevel); # ignore the mappings that is not on toplevel.

		my $scaf      = $topsr_slice->project($scafcsname)->[0] if ($scafcsname);
		my $scaf_name = $scaf->to_Slice->seq_region_name if ($scaf);

		push @locations, {  'srname'    => $srname,
				    'srstart'   => $srstart,
				    'srend'     => $srend,
				    'cmpname'   => $cmpname,
				    'scafname'  => $scaf_name,
				    'acc'       => $acc->value,
		};		
	    }
	    
	    #--store as hash--#
	    $results{$id} = {'name'      => $display_name,
			     'mappings'  => \@locations,
			     'position'  => $position,			     
	    };	    
	}	 		
    }    

    #-- add arrows to indicate the change in coordinates ordered by positions  --#
    my $count = 0;
    my %prevcoords;
    foreach my $key ( sort {$results{$a}{position} <=> $results{$b}{position}} keys %results ){ 
	
	my @mappings = @{$results{$key}{mappings}};
	
	my @loc;
	foreach my $mapfeature (@mappings){
	    my $srn  = $$mapfeature{srname};
	    my $srs  = $$mapfeature{srstart};
	    my $sre  = $$mapfeature{srend};
	    my $cmp  = $$mapfeature{cmpname};
	    my $scaf = $$mapfeature{scafname};
	    my $acc  = $$mapfeature{acc};

	    my $sr_url   = $hub->url({'type'=>'Location','action'=>'View','r'=>"$srn:$srs-$sre"});
	    my $cmp_url  = $hub->url({'type'=>'Location','action'=>'View','region'=>"$cmp", __clear=>1});
	    
	    my $class = "";
	    $class = "noref" if ($srn =~ /H|AB/);

	    my $arrow ="";
	    my $snpdist = "";
	    if ($count > 0 && ($prevcoords{$count-1}{$srn}) && ($srn !~ /H|AB/)){
		$arrow   = ($prevcoords{$count-1}{$srn} < $sre) ? "/i/16/plus-button.png" : "/i/16/minus-button.png";
		$snpdist =  "~". sprintf ("%.2f", abs($srs - $prevcoords{$count-1}{$srn} +1)/1000) ."kb";

		#--change the color to blue if the snpdist is <= 0.3kb--#
		if (abs($srs - $prevcoords{$count-1}{$srn} +1)/1000 <= 0.3){
		    $snpdist = "<a style='color:#5882FA'>$snpdist</>";
		}
	    }

	    #-- Add appropriate html markup to the data --#
	    push @loc, "<tr><td style='width:35%;padding:0px'>". 
		qq(<a href="$sr_url" class="$class">$srn:$srs-$sre</a></td>).
		qq(<td style="width:20%;padding:0px"><img src="$arrow" alt="-"/> $snpdist</td>).
		"<td style='width:15%;padding:0px'>($scaf)</td>".
		"<td style='width:15%;padding:0px'>". qq(<a href="$cmp_url" class="$class"><strong>[$cmp]</strong></a></td>).
		"<td style='width:15%;padding:0px'>$acc</td></tr>";			

	    $prevcoords{$count}{$srn} = $sre;
	}		

	#--final features as a hash--#
	$finalResults{$count} = {   'name'      => $results{$key}{name},
				    'position'  => $results{$key}{position},
				    'm_dbid'    => $key,    
				    'mappings'  => \@loc,
	};
	$count++;
    }

    return \%finalResults;
    
}



sub fetch_map_stats_from_punch {

    my ($hub, $maploc, $pa)  = @_;
    my $species = $hub->species;
    
    # Currently built for James GAPMap stuff, but it could probably apply to all maps, will ask him about his intentions.
    my $punch_code = "gapmap_lg";

    my @punches         = @{$pa->fetch_by_punch_type( $punch_code )};
    # there doesn't exist this punch_code or punch features
    return if (@punches == 0);

    foreach my $p (@punches){

	next if ($p->name ne ($maploc));
	my $comment  = $p->comment();
	return if (!$comment);
	
	#TEMP HACK for hashref until James fixes the input
	$comment =~ s/\s+//g;
	$comment =~ s/'//g;
	my ($mpoc, $chr, $orient, $or) = ($comment =~ /.*marker_proportion_on_chromosome=>(.*),chromosome=>(.*),orientation=>(.*),orientation_r_squared=>(\w+\.{0,}\d{0,}).*/);

	return ($mpoc, $chr, $orient, $or);
    }

    #return nothin if can't find anything.
    return;
}

1;
