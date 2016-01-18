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


package EnsEMBL::Web::Component::Location::MarkerList;

use strict;
use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->ajaxable(1);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $object    = $self->object;
  my $threshold = 2000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE||1);
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view</p>') if $object->length > $threshold;
  
  my @found_mf = $object->sorted_marker_features($object->slice);
  my ($html, %mfs);

  my %maps;

  my $rank =0;
  foreach my $mf (sort {$a->seq_region_start <=> $b->seq_region_start} @found_mf) {
    my $name    = $mf->marker->display_MarkerSynonym->name;
    my $sr_name = $mf->seq_region_name;
    my $cs      = $mf->coord_system_name;

    my $seqlevel_cs = $self->fetch_seqlevel_cs();

    my $seq_level = @{$mf->project($seqlevel_cs)}[0]->to_Slice || undef;
    my $seq_level_name;
    $seq_level_name = $seq_level->seq_region_name if ($seq_level);

    my $scafcmp = undef;

    my $csa        = $self->hub->database('core')->get_CoordSystemAdaptor(); 

    # wc2 does fpc_contig exists? or is it scaffold/supercontig etc?
    my $scaf_cs = ($csa->fetch_by_name('fpc_contig')) ? "fpc_contig" : undef;

    if ( !$scaf_cs  && $csa->fetch_by_name('scaffold')){
	$scaf_cs = "scaffold";
    }
    elsif ( !$scaf_cs && $csa->fetch_by_name('supercontig')){
	$scaf_cs = "supercontig";
    }
    #--

    my $scafcmp = undef;
    if ( $scaf_cs &&  $seq_level && @{$seq_level->project($scaf_cs)}>0){
	my $ctg_level = @{$mf->project($scaf_cs)}[0]->to_Slice || undef;
	$scafcmp = $ctg_level->seq_region_name if ($ctg_level);
    }
		

    my $map_location_ref = $mf->marker->get_all_MapLocations;
    
    $mfs{$rank} = {       name     => $name,
			  cs       => $cs,
			  mf       => $mf,
			  start    => $mf->seq_region_start,
			  end      => $mf->seq_region_end,
			  ctg      => $scafcmp,	
			  srname   => $sr_name,
			  slname   => $seq_level_name,
			  maps     => $map_location_ref,
		      };    

    foreach my $m (@{$map_location_ref}){
	
	$maps{$m->map_name}++;
    }


    $rank++;

  }
  
  my $c = scalar keys %mfs;
  
  return '<h3>No markers found in this region </h3>' unless $c;
  
  my $s = $c > 1 ? 's' : '';
  
  $html = "
    <h3>$c mapped marker$s found:</h3>
    *map columns: (chromosome)mp: map position. 
  ";


  my %map_rearray;
  my $i = 1;
  foreach my $mapname (sort keys %maps){
      $map_rearray{$mapname} = $i;
      $i++;
  }
  
  my $map_column_count = (keys %map_rearray);


  my @columns = ( 
		  { key => 'name',       sort => 'string',  title => 'Name'          },
		  { key => 'rank',       sort => 'numeric',  title => 'Rank'          },
		  { key => 'start',      sort => 'numeric',  title => 'Region Start'  },
		  { key => 'end',        sort => 'numeric',  title => 'Region End'    },
		  { key => 'placed',     sort => 'string',  title => 'Placed'        },
		  );
  push @columns, { key => 'ctg',        sort => 'string',   title => 'Scaf'         }; # Added this column due to request from kaa

  foreach my $rearray_name (sort { $map_rearray{$a} <=> $map_rearray{$b} } keys %map_rearray){

      push @columns, { key => $rearray_name,       sort => 'string',  title => $rearray_name          },

 }

  my @rows;
  foreach my $rank (sort {$a<=>$b} keys %mfs){
      my ($link, $r);
      
      my $name    = $mfs{$rank}{name};
      my $slname  = $mfs{$rank}{slname};

      my $name_url      = $hub->url({ type => 'Marker', action => 'Details', m => $name });     
      my $href_name     = qq{<a href="$name_url" rel="friend" class="nodeco">$name</a><br>};

      my $slname_url    = $hub->url({ type => 'Location', action => 'View', region => $slname, __clear=>1 });
      my $href_slname   = qq{<a href="$slname_url" rel="external" class="nodeco">$slname</a><br>};

      my $row = {
	  name       => $href_name,
	  rank       => $rank,
	  start      => $mfs{$rank}{start},
	  end        => $mfs{$rank}{end},
	  ctg        => $mfs{$rank}{ctg},
	  placed     => $href_slname,
	  
      };
      

      my @map_location = @{$mfs{$rank}{maps}};
      
      for (my $i=1;$i<($map_column_count+1);$i++){
	  my $is_map = 0;
	  foreach my $map_loc ( sort @map_location){
	      my $map_name = $map_loc->map_name;
	      my $chr      = $map_loc->chromosome_name;
	      my $position = $map_loc->position;
	  

	      if ($map_rearray{$map_name} && $map_rearray{$map_name} == $i){
		  
		  if ($chr ne $mfs{$rank}{srname}){
		      $chr = "<font color=red>$chr</font>";
		  }
		  
		  $$row{$map_name} = "($chr)mp:$position";
		  $is_map = 1;
	      }

	      
	  }
	  if (!$is_map){
	      #$link .= "<TD>&nbsp;</td>";
	      
	  }
      }
     
    
      push @rows, $row;

  }
  my $table = $self->new_table(\@columns, \@rows, {
          data_table        => 1,
          sorting           => [ 'start asc' ] ,
          exportable        => 1
          });

  $html .= $table->render;

  #$html .= '</table>';
  
  return $html;
}




# used to fetch the sequence level. wc2
sub fetch_seqlevel_cs {
    
    my $self = shift;

    my $db_adaptor = $self->hub->database('core');
    my $csa        = $db_adaptor->get_CoordSystemAdaptor(); 

    my $cs = $csa->fetch_sequence_level();

    my $name = $cs->name;
    return $name || "contig";

}



# depending on number print a list of marker_features, or show details for markers
sub render_marker_features {
	my $self = shift;
  
  my $object   = $self->object;
  my @found_mf = $object->sorted_marker_features($object->Obj->{'slice'});
  my ($html, %mfs);
  
	foreach my $mf (@found_mf) {
		my $name = $mf->marker->display_MarkerSynonym->name;
		my $sr_name = $mf->seq_region_name;
		my $cs = $mf->coord_system_name;
    
		push @{$mfs{$name}->{$sr_name}}, {
      'cs'    => $cs,
      'mf'    => $mf,
      'start' => $mf->seq_region_start,
      'end'   => $mf->seq_region_end
    };
	}
  
	my $c = scalar keys %mfs;
  
	# print a list if we have more than one marker
	if ($c > 1) {
		$html = "
      <h3>$c mapped markers found:</h3>
      <table>
    ";
    
		foreach my $name (sort keys %mfs) {
	    my ($link, $r);
      
	    foreach my $chr (keys %{$mfs{$name}}) {
				$link .= "<td><strong>$mfs{$name}->{$chr}[0]{'cs'} $chr:</strong></td>";
        
				foreach my $det (@{$mfs{$name}->{$chr}}) {
					$link .= "<td>$det->{'start'}-$det->{'end'}</td>";
					$r = "$chr:$det->{'start'}-$det->{'end'}";
				}
	    }
      
      my $url = $self->hub->url({ m => $name, r => $r });
      
	    $html .= qq{<tr><td><a href="$url">$name</a></td>$link</tr>};
		}
    
		$html .= '</table>';
	} else { # otherwise print details
		my @markers = map $_->marker, @found_mf;
		$html = $self->render_marker_details(\@markers);
	}
  
  return $html;
}

sub render_marker_details {
	my ($self, $markers) = @_;
  
	my $hub     = $self->hub;
	my $species = $hub->species;
	my $html;
  
	return '<h3>No markers found</h3>' unless scalar @$markers;
  
	foreach my $m (@$markers) {
		my $table  = $self->new_twocol;
		my $m_name = $m->display_MarkerSynonym ? $m->display_MarkerSynonym->name : '';
    
		$html .= "<h3>Marker $m_name</h3>";
		
    # location of marker features
		$table->add_row('Location', $self->render_location($m));
		
		# synonyms
		if (my @important_syns = @{$self->marker_synonyms($m, 1)}) {
			my $syn_text;
      
			foreach my $syn (@important_syns) {
				my $db  = $syn->source;
				my $id  = $syn->name;
				my $url = $hub->get_ExtURL($db, $id);
        
				$id = qq{<a href="$url">$id</a>} if $url;
				$syn_text .= "<table><tr><td>$id ($db)</td></tr></table>";
			}
      
			$table->add_row('Source', $syn_text);
		}
		
		# other synonyms (rows of $max_cols entries)
		if (my @other_syns = @{$self->marker_synonyms($m, 0)}) {
      my $other_syn_text = '<table><tr>';
	    my $max_cols = 8;
	    my $syn_dbs;
      
	    foreach my $syn (@other_syns) {
				my $db_name = $syn->source;
				push @{$syn_dbs->{$db_name}}, $syn->name;
	    }
      
	    foreach my $db (keys %$syn_dbs) {
				my $c = 0;
        
				$other_syn_text .= "<td><strong>$db:</strong></td>";
        
				foreach my $id (@{$syn_dbs->{$db}}) {
					my $url = $hub->get_ExtURL_link($id, uc $db, $id);
          
					if ($c < $max_cols) {
						$other_syn_text .= "<td>$url</td>";
						$c++;
					} else {
						$other_syn_text .= "
              </tr>
              <tr>
                <td></td>
                <td>$url</td>";
            
						$c = 1;
					}
				}
        
				$other_syn_text .= '</tr>';
	    }
      
	    $other_syn_text .= '</table>';
	    
	    $table->add_row('Synonyms', $other_syn_text);
		}
		
		# primer details
		my $l         = $m->left_primer;
		my $r         = $m->right_primer;
		my $min_psize = $m->min_primer_dist;
		my $max_psize = $m->max_primer_dist;
		my ($product_size, $primer_txt);
    
		if (!$min_psize) {
	    $product_size = "&nbsp";
		} elsif ($min_psize == $max_psize) {
	    $product_size = "$min_psize";
		} else {
	    $product_size = "$min_psize - $max_psize";
		}
		
		if ($r) {
	    $l =~ s/([\.\w]{30})/$1<br \/>/g;
	    $r =~ s/([\.\w]{30})/$1<br \/>/g;
	    $primer_txt .= "
      <table>
        <tr><td><strong>Expected Product Size:</strong></td><td>$product_size</td></tr>
        <tr><td><strong>Left Primer:</strong></td><td>$l</td></tr>
        <tr><td><strong>Right Primer:</strong></td><td>$r</td></tr>
      </table>
      ";
		} else {
	    $primer_txt = "Marker $m_name primers are not in the database";
		}
    
		$table->add_row('Primers', $primer_txt);
		
		$html .= $table->render;
		
		if (my @mml = @{$m->get_all_MapLocations}) {
	    my $map_table = $self->new_table([], [], { 'margin' => '1em 0px' });
      
	    $map_table->add_columns({ 'key' => 'map', 'align' => 'left', 'title' => 'Map Name'   });
	    $map_table->add_columns({ 'key' => 'syn', 'align' => 'left', 'title' => 'Synonym'    });
	    $map_table->add_columns({ 'key' => 'chr', 'align' => 'left', 'title' => 'Chromosome' });
	    $map_table->add_columns({ 'key' => 'pos', 'align' => 'left', 'title' => 'Position'   });
	    $map_table->add_columns({ 'key' => 'lod', 'align' => 'left', 'title' => 'LOD Score'  });
      
	    foreach my $ml (@mml) {
				my $row = {
          'map'  => $ml->map_name,
          'syn'  => $ml->name || '-',
          'chr'  => $ml->chromosome_name || '&nbsp;' ,
          'pos'  => $ml->position || '-',
          'lod'  => $ml->lod_score || '-',
          '_raw' => $ml
        };
        
				$map_table->add_row($row);
			}
      
	    $html .= $map_table->render;
		}		
	}
  
	return $html;
}

sub marker_synonyms {
	my ($self, $m, $important) = @_;
  
	my @syns;
	my %is_important = map { $_, 1 } qw(rgd oxford unists mgi:markersymbol);
  
  if ($important) {
    @syns = grep $is_important{lc $_->source}, @{$m->get_all_MarkerSynonyms};
  } else {
    @syns = grep !$is_important{lc $_->source}, @{$m->get_all_MarkerSynonyms};
  }
  
	return \@syns;
}

sub render_location {
	my ($self, $m) = @_;
	
	my $m_name         = $m->display_MarkerSynonym ? $m->display_MarkerSynonym->name : '';
	my $hub            = $self->hub;
	my $species        = $hub->species;
	my $sitetype       = $hub->species_defs->ENSEMBL_SITETYPE;
  my @mfs            = $self->object->sorted_marker_features($m);
	my $c              = scalar @mfs;
	my $loc_text       = '<table>';
  my $max_map_weight = 15;
  my $map_weight     = 2;
  my $priority       = 50;
  
	if ($c) {
		if ($c > 1) {
	    my $extra = $c > $map_weight ? ' (note that for clarity markers mapped more than twice are not shown on location based views)' : '';
	    $loc_text .= sprintf '<tr><td>%s is currently mapped to %d different %s locations%s%s%s</td></tr>', $m_name, $c, $sitetype, $extra, ($c > $max_map_weight ? '.' : ':');
		}
    
		foreach my $mf (@mfs) {
	    my $sr_name = $mf->seq_region_name;
	    my $start   = $mf->start;
	    my $end     = $mf->end;
	    my $url     = $hub->url({ action => 'View', r => "$sr_name:$start-$end", m => $m_name }); 
	    my $extra   = $m->priority < $priority ? " [Note that for reasons of clarity this marker is not shown on 'Region in detail']" : '';
			
	    $loc_text .= sprintf '<tr><td>%s%s <a href="%s">%s:%s-%s</a>%s</td></tr>', $c > 1 ? '&nbsp;' : '', $mf->coord_system_name, $url, $sr_name, $start, $end, $extra;
		}
	} else {
		$loc_text .= "<tr><td>Marker $m_name is not mapped to the assembly in the current $sitetype database</td></tr>";
	}
  
	$loc_text .= '</table>';
  
	return $loc_text;
}

1;
