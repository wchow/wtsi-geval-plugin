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

package EnsEMBL::Web::Component::Location::ChromosomeStats;

### Module to replace part of the former MapView, in this case 
### displaying the stats for an individual chromosome 
### It also contains the jt8 analysis for marker placements for fish


## wc2 AT RISK 04022014                                 ##
## being replaced by ChromosomeImage and MarkerOverview ##

use strict;
use warnings;
no warnings "uninitialized";
use Statistics::Descriptive;
use base qw(EnsEMBL::Web::Component::Location);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
  $self->configurable( 0 );
}


sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;

  my $chr_name = $object->seq_region_name;
  my $label = "Chromosome $chr_name";

  my @orderlist = (
    'Length (bps)',
    'known protein_coding Gene Count',
    'novel protein_coding Gene Count',
    'pseudogene Gene Count',
    'miRNA Gene Count',
    'ncRNA Gene Count',
    'rRNA Gene Count',
    'snRNA Gene Count',
    'snoRNA Gene Count',
    'tRNA Gene Count',
    'misc_RNA Gene Count',
    'SNP Count',
    'Number of fingerprint contigs',
    'Number of clones selected for sequencing',
    'Number of clones sent for sequencing',
    'Number of accessioned sequence clones',
    'Number of finished sequence clones',
    'Total number of sequencing clones',
    'Raw percentage of map covered by sequence clones',
  );
  my $html = qq(
<h3>Chromosome Statistics</h3>
<table class="ss tint">);
  my ($stats, %chr_stats, $bg);
  my $chr = $object->Obj->{'slice'};
  foreach my $attrib (@{$chr->get_all_Attributes}) {
    $chr_stats{$attrib->name} += $attrib->value;
  }
  $chr_stats{'Length (bps)'} = ($object->seq_region_name eq 'ALL') ? $chr->max_chr_length : $chr->seq_region_length ;

  for my $stat (@orderlist){
    my $value = $object->thousandify( $chr_stats{$stat} );
    next if !$value;
    $stat = 'Estimated length (bps)' if $stat eq 'Length (bps)' && $object->species_defs->NO_SEQUENCE;
    $stat =~ s/Raw p/P/;
    $stat =~ s/protein_coding/Protein-coding/;
    $stat =~ s/_/ /g;
    $stat =~ s/ Count$/s/;
    $stat = ucfirst($stat) unless $stat =~ /^[a-z]+RNA/;
  
    $bg = $stats % 2 != 0 ? 'bg1' : 'bg2';
    $html .= qq(<tr class="$bg"><td><strong>$stat:</strong></td>
                <td style="text-align:right">$value</td>
                </tr>);
    $stats++;
  }
  unless ($stats) {
    $html .= qq(<tr><td><strong>Could not load chromosome stats</strong><td></tr>);
  }
  $html .= qq(  </table>
  );
 # jt8 analysis for fish
 $html .= "SPECIES: $species\n";
	if($species =~ /fish/) {
		# Maximum (exclusive) number of repetitions that a marker may have if it is to be included
		my $marker_cutoff = 3;
		my @panel_priority = qw(SATMap HS_2007 MGH_2005); 

		my $chromosome_slice = $chr->seq_region_Slice;

		my @fpc_projections = @{ $chromosome_slice->project('fpc_contig') };
		warn "Projected FPCs count is " . scalar(@fpc_projections) . " from " . $chromosome_slice->name . "\n";
		my $last_fpc_name;
		my @fpc_slices;
		foreach my $fpc_projection (@fpc_projections) {
			my $fpc_slice = $fpc_projection->to_Slice->seq_region_Slice;
			if(!defined($last_fpc_name) or $fpc_slice->seq_region_name ne $last_fpc_name) {
				push(@fpc_slices, $fpc_slice);
			} 
			$last_fpc_name = $fpc_slice->seq_region_name;
		}

	   my @columns = ( 
 			  { key => 'fpc',       sort => 'string',  title => 'FPC'          },
 			  { key => 'rank',       sort => 'numeric',  title => 'Rank'          },
 			  { key => 'panel',      sort => 'numeric',  title => 'Marker panel'  },
 			  { key => 'marker_count',        sort => 'numeric',  title => 'Marker count'    },
			  { key => 'bottom_decile_map_position',        sort => 'numeric',  title => 'Bottom decile'    },
  			  { key => 'median_map_position',        sort => 'numeric',  title => 'Median position'    },
			  { key => 'top_decile_map_position',        sort => 'numeric',  title => 'Top decile'    },
  			  # { key => 'alternate_positions',        sort => 'numeric',  title => 'Alternate positions'    },
 			  );
		my @rows;


		my $rank = 0;
		foreach my $fpc (@fpc_slices) {
			$rank++;

			my $marker_count_current = ' ';
			my $top_decile_map_position_current = ' ';
			my $bottom_decile_map_position_current = ' ';			
			my $median_map_position_current = ' ';
			my $map_positions_alternate = ' ';
			my $has_higher_priority_panel_succeeded = 0;

			# Consider each panel in order. Only analyse lower panels if there is not higher-panel info
	    	PANEL: foreach my $panel (@panel_priority) {
				my %marker_features_for_chromosome = %{ get_marker_features_for_panel_by_chromosome($fpc, $panel, $marker_cutoff) };

				my @map_chromosomes = keys %marker_features_for_chromosome;
				if(scalar @map_chromosomes > 0) {

					@map_chromosomes = sort {
						if($a eq $chromosome_slice->seq_region_name and $b ne $chromosome_slice->seq_region_name) {
							return -1;
						} 
						elsif($b eq $chromosome_slice->seq_region_name and $a ne $chromosome_slice->seq_region_name) {
							return 1;
						}
						else {
							return $a <=> $b;
						}
					} @map_chromosomes;

					my $markers_for_present_chromosome = 0;
					my $total_markers = 0;
					foreach my $map_chromosome (@map_chromosomes) {
						my $map_location_stats = get_map_location_statistics_descriptive_object($panel, @{$marker_features_for_chromosome{$map_chromosome}});
						my $median_map_location = $map_location_stats->median;

						$total_markers += scalar (@{$marker_features_for_chromosome{$map_chromosome}});
						if($map_chromosome eq $chromosome_slice->seq_region_name) {
							$markers_for_present_chromosome = scalar (@{$marker_features_for_chromosome{$map_chromosome}});

							$median_map_position_current = $median_map_location;
							$bottom_decile_map_position_current = $map_location_stats->percentile(10);
							if(!defined($bottom_decile_map_position_current)) {$bottom_decile_map_position_current = $map_location_stats->min}
							$top_decile_map_position_current = $map_location_stats->percentile(90);
							if(!defined($top_decile_map_position_current)) {$top_decile_map_position_current = $map_location_stats->max}
							
							$marker_count_current = scalar (@{$marker_features_for_chromosome{$map_chromosome}});
						}
						else {
							$map_positions_alternate .= "$map_chromosome:$median_map_location(" . scalar (@{$marker_features_for_chromosome{$map_chromosome}}) . ") ";
						}
					}

					push( @rows, {
						fpc => $fpc->seq_region_name,
						rank => $rank,
						panel => $panel,
						marker_count => $marker_count_current,
						bottom_decile_map_position => $bottom_decile_map_position_current,
						median_map_position => $median_map_position_current,
						top_decile_map_position => $top_decile_map_position_current,
						# alternate_positions => $map_positions_alternate,
						}
					);

					$has_higher_priority_panel_succeeded = 1;
					last PANEL;
				}

			}


			# If there were no markers at all, still list this FPC
			if(!$has_higher_priority_panel_succeeded) {
				push( @rows, {
					fpc => $fpc->seq_region_name,
					rank => $rank,
					panel => '',
					marker_count => '',
					bottom_decile_map_position => '',
					median_map_position => '',
					top_decile_map_position => '',
					alternate_positions => '',
				}
				);
			}

		}

	   my $table = $self->new_table(\@columns, \@rows, {
        	   data_table        => 1,
        	   #data_table_config => { asStripClasses => [ '', '' ], oSearch => { sSearch => '', bRegex => 'false', bSmart => 'false' } },
        	   #class             => 'toggle_table fixed_width',
        	   #id                => 'transcripts_table',
        	   #style             => "", #'display:none' ,
        	   sorting           => [ 'rank asc' ] ,
        	   exportable        => 1
        	   });

	   $html .= $table->render;
	}


  return $html;
}

sub get_marker_features_for_panel_by_chromosome {
	my ($slice, $panel, $marker_cutoff) = @_;
	
	my @marker_features = @{ $slice->get_all_MarkerFeatures(undef,undef,$marker_cutoff) };

	my %marker_features_for_chromosome;
	foreach my $marker_feature (@marker_features) {
		my $ml = $marker_feature->marker->get_MapLocation($panel);
	               
	    next if not defined $ml;      	 
	    push (@{$marker_features_for_chromosome{$ml->chromosome_name}},$marker_feature);
	}
	
	return \%marker_features_for_chromosome;
}

sub get_map_location_statistics_descriptive_object {
	my ($panel, @marker_features) = @_;
	my @map_locations = map {$_->marker->get_MapLocation($panel)->position} @marker_features;
	return make_statistics_descriptive_object(@map_locations);
}

sub make_statistics_descriptive_object {
	my (@data) = @_;
	my $stat = Statistics::Descriptive::Full->new();
	$stat->add_data(@data);
	return $stat;
}

1;
