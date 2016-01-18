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

package EnsEMBL::Web::Component::Location::SomaList;

use strict;
use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->ajaxable(1);
}

sub fetch_soma_features {
    my ($self, $slice, $logic_name, $mapname)   = @_;

    $logic_name = "Soma" if (!$logic_name);

    my $c = 1000;
    #my %sort = map { $_, $c-- } @{$self->species_defs->ENSEMBL_CHROMOSOMES || []};
    my @soma_features = ref $slice eq 'ARRAY' ? map @{$_->get_all_DnaAlignFeatures($logic_name) || []}, @$slice : @{$slice->get_all_DnaAlignFeatures($logic_name) || []};
    
    return map $_->[-1], sort { 
	    $a->[1] <=> $b->[1] || 
	    $a->[2] <=> $b->[2] 
    } map [ $_->seq_region_name, $_->start, $_->end, $_ ], @soma_features;
    
}


sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $object    = $self->object;
#  my $threshold = 2000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE||1);
  
  my $mapname   = $hub->param('mapname');
  $mapname =~ s/\.[R|N]\d+//;
#  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view</p>') if $object->length > $threshold;
  
  my @somafeats = $self->fetch_soma_features($object->slice, 'Soma', $mapname);




  my ($html, %mfs);
  my %maps;
  my $rank =0;

  my @columns = ( 
      { key => 'name',       title => 'Name'          },
      { key => 'idx',        sort  => 'numeric',  title => 'Index'          },
      { key => 'score',      title => 'SomaScore'          },
      { key => 'type',       title => 'Alignment Type'          },
      { key => 'start',      sort  => 'numeric',  title => 'Region Start'  },
      { key => 'end',        sort  => 'numeric',  title => 'Region End'    },
      { key => 'orient',     title => 'Orient'        },
      { key => 'placed',     sort  => 'string',  title => 'Placed'        },
      { key => 'frag',       title => 'Frag Length'          },
      { key => 'digest',     title => 'Insilico Frag Length' },

      );

  my @rows;
  my ($prev_coord, $prev_type);

  my %contigmaps;

  my $chr        = $object->slice->seq_region_name;
  my $chr_length = $object->slice->seq_region_length || 1000000000;

  foreach my $sf (sort {$a->seq_region_start <=> $b->seq_region_start} @somafeats) {

      my $name    = $sf->hseqname;
      next if ($name !~ /$mapname/);
      
      my $sr_name = $sf->seq_region_name;
      my $cs      = $sf->coord_system_name;
      my $idx     = $sf->extra_data || 0;
      my $score   = $sf->score;
      my $orient  = ($sf->hstrand == 1) ? "+" :"-"; 
      
      my ($type) = @{$sf->get_all_Attributes('soma_type')};
      $type = $type->value();
      my ($fraglength) = @{$sf->get_all_Attributes('frag_length')};
      $fraglength = ($fraglength) ? $fraglength->value() : undef;


      my $seqlevel_cs = $self->fetch_seqlevel_cs();
      
      my $seq_level = ( @{$sf->project($seqlevel_cs)} >0 ) ? @{$sf->project($seqlevel_cs)}[0]->to_Slice : undef;
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
      my @insilico = ($type eq "aligned") ? @{$self->fetch_insilico_digest($sf->slice, $sf->seq_region_start, $sf->seq_region_end, 1)} : ();


      if ( $scaf_cs &&  $sf && @{$sf->project($scaf_cs)}>0){
	  my $ctg_level = @{$sf->project($scaf_cs)}[0]->to_Slice || undef;
	  $scafcmp = $ctg_level->seq_region_name if ($ctg_level);
      }

      ##----Type-Colours-----##
      my $type_color = ($type =~ /downstream|upstream/) ? "grey" : "#088A08";


      if ($type eq "unaligned"){
	  
	  my ($unaligned_bits) = @{$sf->get_all_Attributes('soma_unaligned')};
	  $unaligned_bits = $unaligned_bits->value();
	  
	  my @pairs  =  split (";", $unaligned_bits);
	  
	  @pairs  = reverse @pairs if ($orient eq "-");

	  foreach my $pair (@pairs){
	      my ($index, $size) = ($pair =~ /(\d+):(\d+)/);
	      my $row = {
		  name    => $name,
		  idx     => "<em style='color:$type_color'>$index</em>",
		  score   => 0,
		  type    => "<em style='color:$type_color'>$type</em>",
		  orient  => $orient,
		  placed  => $scafcmp,
		  frag    => $size,
   	      #start      => "<em style='color:green'>".$sf->seq_region_start."</em>",
	      #end        => "<em style='color:green'>".$sf->seq_region_end."</em>",   
      
	      };
	      push @rows, $row;
	      
	  
	  }	  
      }
      elsif ($type =~ /downstream|upstream/){
	  
	  my $row = {
	      name       => "<em style='color:$type_color'>$name</em>",
	      idx        => "<em style='color:$type_color'>$idx</em>",
	      frag       => "<em style='color:$type_color'>$fraglength</em>",
	      type       => "<em style='color:$type_color'>$type</em>",
	      start      => "<em style='color:$type_color'>".$sf->seq_region_start."</em>",
	      end        => "<em style='color:$type_color'>".$sf->seq_region_end."</em>",
	      placed     => "<em style='color:$type_color'>$scafcmp</em>",
	      orient     => $orient,	      
	  };
	  
	  push @rows, $row;

      }
      else {
	  
	  my $mis_ref_block;
	  if ($prev_coord && $sf->seq_region_start - $prev_coord != 1 && $prev_type eq "aligned"){
	      $mis_ref_block = "MisStep!";
	      my @ref_frags = @{$self->fetch_insilico_digest($sf->slice, $prev_coord+1, $sf->seq_region_start-1, 1)}; 
	      
	      my $ref_block_slice = $self->feature_slice($sf->slice, $prev_coord+1, $sf->seq_region_start-1, 1);

	      my $ref_block_cmp = "";
	      if ( $scaf_cs &&  $ref_block_slice && @{$ref_block_slice->project($scaf_cs)}>0){
		  my $ctg_level = @{$ref_block_slice->project($scaf_cs)}[0]->to_Slice || undef;
		  $ref_block_cmp = $ctg_level->seq_region_name if ($ctg_level);
	      }
	      
	      my $bump = {
		  digest     => "<em style='color:blue'>".join (", ", @ref_frags)."</em>",
		  placed     => "<em style='color:blue'>$ref_block_cmp</em>", 
	      };
	      push @rows, $bump;
	  }

	  my $row = {
	      name       => $name,
	      idx        => $idx,
	      score      => $score,
	      frag       => $fraglength,
	      type       => ($type eq "aligned") ? "<strong>$type</strong>" : "<em style='color:$type_color'>$type</em>",
	      start      => $sf->seq_region_start,
	      end        => $sf->seq_region_end,
	      placed     => $scafcmp,
	      orient     => $orient,
	      digest     => join (", ", @insilico),
	      
	  };
	  
	  $prev_coord   =  $sf->seq_region_end;

	  $contigmaps{$name}{regionstart} = $sf->seq_region_start if (!($contigmaps{$name}{regionstart}));
	  $contigmaps{$name}{regionend}   = $sf->seq_region_end   if (!($contigmaps{$name}{regionend}) || $sf->seq_region_end > $contigmaps{$name}{regionend});

	  push @rows, $row;
      }

      $prev_type = $type;
  }
  my $table = $self->new_table(\@columns, \@rows, {
          #data_table        => 1,
          sorting           => [ 'start asc' ] ,
          #exportable        => 1
          });


  $html .= qq(<div class="column-wrapper"><div class="column-two"><div class="column-wrapper"><div class="info-box column-left">);
  $html .= "<h2>Aligned Regions</h2>";
  my $rawmapname;
  foreach my $contig_mapname (sort {$contigmaps{$a}{regionstart} <=> $contigmaps{$b}{regionend}} keys %contigmaps){
      my $regionstart = $contigmaps{$contig_mapname}{regionstart};
      my $regionend   = $contigmaps{$contig_mapname}{regionend};
      my $region = "$chr:$regionstart-$regionend"; 
      my $url = $hub->url({ type => 'Location', action => 'view', r => $region });
      $html .= "<strong>$contig_mapname</strong> - <a href=$url>$regionstart to $regionend</a></br>";
      ($rawmapname = $contig_mapname) =~ s/\.[R|N]\d+//;
  }
  
  my $scan_url   = $hub->url({ mapname => $rawmapname, r => "$chr:1-$chr_length" });
  $html .= "<br><p><a href=$scan_url>Scan entire chromosome $chr</a></p>";
  $html .= "</div></div></div>";
  
  $html .= qq(<div class="info-box column-right"><div class="column-wrapper">);
  $html .= "<h3>Alignment Type: </h3>".
      "<table border=0>".
      "<tr><th>aligned</th><td>Aligned fragment (map vs insilico digest)</td></tr>".
      "<tr><th>unaligned</th><td>Fragments in map not seen in assembly</td></tr>".
      "<tr><th>upstram/downstream</th><td>unaligned fragments flanking the aligned components of map</td></tr></table>";
  
  $html .= "</div></div></div></div>";
  $html .= $table->render;

  
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

sub feature_slice {
    my ($self, $slice, $start, $end, $strand)   = @_;
    
    #test purpose, next check the digest...
    my $featslice  = Bio::EnsEMBL::Slice->new
	(-seq_region_name   => $slice->seq_region_name,
	 -seq_region_length => $slice->seq_region_length,
	 -coord_system      => $slice->coord_system,
	 -start             => $start,
	 -end               => $end,
	 -strand            => $strand,
	 -adaptor           => $slice->adaptor());

    return $featslice;
}


sub fetch_insilico_digest {

    my ($self, $slice, $start, $end, $strand)   = @_;
    
    my $newslice = $self->feature_slice ( $slice, $start, $end, $strand);

    return if (!$newslice);

    my @digest_feats   = @{$newslice->get_all_MiscFeatures('kpn1')};
    
    @digest_feats = map {$_->get_scalar_attribute('frag_length')} @digest_feats;


    return \@digest_feats;
}


1;
