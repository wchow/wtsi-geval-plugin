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

package Bio::EnsEMBL::GlyphSet::gEVAL_contig;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

#-----------------------#
#			#
# Glyph for the Contigs	#
# track.		#	 
#			#
#   wc2@sanger.ac.uk	#
#			#
#-----------------------#

use constant MAX_VIEWABLE_ASSEMBLY_SIZE => 5e6;

#--------------------#
# _init
#  the main drawing
#  code.
#--------------------#
sub _init {
  my ($self) = @_;
  # only draw contigs once - on one strand
  
  return $self->render_text if $self->{'text_export'};
  
  if( $self->species_defs->NO_SEQUENCE ) {
    my $msg = "Clone map - no sequence to display";
    $self->errorTrack($msg);
    return;
  }

  my $Container = $self->{'container'};
  $self->{'vc'} = $Container;
  my $length = $Container->length();
  my $module = ref($self);
     $module = $1 if $module=~/::([^:]+)$/;

  my $gline = $self->Rect({
    'x'         => 0,
    'y'         => 0,
    'width'     => $length,
    'height'    => 0,
    'colour'    => 'grey50',
    'absolutey' => 1,
  });
  $self->push($gline);

  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res   = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $h     = $res[3];
  my $box_h = $self->my_config('h');

  if( !$box_h ) {
    $box_h = $h + 4;
  } elsif( $box_h < $h + 4 ) {
    $h = 0;
  }

  my $pix_per_bp = $self->scalex;

  my $gline = $self->Rect({
    'x'         => 0,
    'y'         => $box_h,
    'width'     => $length,
    'height'    => 0,
    'colour'    => 'grey50',
    'absolutey' => 1,
  });
  $self->push($gline);
  
  my @features = ();
  my @segments = ();

  @segments = @{$Container->project('seqlevel')||[]};

  my @coord_systems;
  if ( ! $Container->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice") && ($Container->{__type__} ne 'alignslice')) {
    @coord_systems = @{$Container->adaptor->db->get_CoordSystemAdaptor->fetch_all() || []};
  }

  my $threshold_navigation = ($self->my_config('threshold_navigation')|| 2e6)*1001;
  my $navigation           = $self->my_config( 'navigation') || 'on';
  my $show_navigation = ($length < $threshold_navigation) && ($navigation eq 'on');

  foreach my $segment (@segments) {
    my $start      = $segment->from_start;
    my $end        = $segment->from_end;
    my $ctg_slice  = $segment->to_Slice;
    my $ORI        = $ctg_slice->strand;
    my $feature = { 'start' => $start, 'end' => $end, 'name' => $ctg_slice->seq_region_name, 'slice'=> $ctg_slice };
    if ($ctg_slice->coord_system->name eq "ancestralsegment") {
      ## This is a Slice of Ancestral sequences: display the tree instead of the ID
      $feature->{'name'} = $ctg_slice->{_tree};
    }

      $feature->{'locations'}{ $ctg_slice->coord_system->name } = [ $ctg_slice->seq_region_name, $ctg_slice->start, $ctg_slice->end, $ctg_slice->strand  ];

      #is it a haplotype contig ?
      my ($hap_name) = @{$ctg_slice->get_all_Attributes('hap_contig')};
      $feature->{'haplotype_contig'} = $hap_name->{'value'} if $hap_name;

      if( $show_navigation ) {
          if ( ! $Container->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice") && ($Container->{__type__} ne 'alignslice')) {
              foreach( @coord_systems ) {
                  my $path;
                  eval { $path = $ctg_slice->project($_->name); };

                  next unless $path;
                  next unless(@$path == 1);

                  $path = $path->[0]->to_Slice;
                  # get clone id out of seq_region_attrib for link to webFPC 
                  if ($_->{'name'} eq 'clone') {
                      my ($clone_name)            = @{$path->get_all_Attributes('fpc_clone_id')};
                      $feature->{'internal_name'} = $clone_name->{'value'} if $clone_name;

                  }

		  my $accession     = $path->get_all_Attributes('accession');
		  my $version       = $path->get_all_Attributes('version');
		  my $intname_obj   = $path->get_all_Attributes('int_name');

		  if (@$intname_obj){
		      my $intname = $$intname_obj[0]->{'value'} || "";
		      $feature->{'int_name'} = $intname;
		  }
		  
		  if ($accession ne $feature->{'name'}){   
		    $feature->{'accession'} = $$accession[0]->{'value'}.".".$$version[0]->{'value'} if ( @$accession );
		  }

                  $feature->{'locations'}{$_->name} = [ $path->seq_region_name, $path->start, $path->end, $path->strand ];
              }
          }
      }
      $feature->{'ori'} = $ORI;
      push @features, $feature;
  }
  
  if( @features) {
      $self->_init_non_assembled_contig($h,$box_h,$fontname,$fontsize,\@features);
  } else {
      my $msg = "Golden path gap - no contigs to display!";
      if ($Container->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice") && $Container->{compara} ne 'primary') {
          $msg = "Alignment gap - no contigs to display!";
      }
      $self->errorTrack($msg);
  }
}

#----------------------------#
# _init_non_assembled_contig
#  Its been used for most features 
#  and called from above.
#----------------------------#
sub _init_non_assembled_contig {
  my ($self, $h, $box_h, $fontname, $fontsize, $contig_tiling_path) = @_;
  my $Container = $self->{'vc'};
  my $length = $Container->length();
  my $ch = $Container->seq_region_name;

  my $pix_per_bp = $self->scalex;

  my $module               = ref($self);
     $module               = $1 if $module=~/::([^:]+)$/;
  my $threshold_navigation = ($self->my_config( 'threshold_navigation')|| 2e6)*1001;
  my $navigation           = $self->my_config( 'navigation') || 'on';
  my $show_navigation      = ($length < $threshold_navigation) && ($navigation eq 'on');
  my $show_href            = ($length < 1e8 ) && ($navigation eq 'on');

########
# Vars used only for scale drawing
#
  my $black    = 'black';
  my $red      = 'red';
  my $highlights = join('|', $self->highlights());
     $highlights = $highlights ? ";highlight=$highlights" : '';
  if( $self->{'config'}->{'compara'} ) { ## this is where we have to add in the other species....
    my $C = 0;
    foreach( @{ $self->{'config'}{'other_slices'}} ) {
      if( $C!= $self->{'config'}->{'slice_number'} ) {
        if( $C ) {
          if( $_->{'location'} ) {
            $highlights .= sprintf( ";s$C=%s;c$C=%s:%s:%s;w$C=%s", $_->{'location'}->species,
                         $_->{'location'}->seq_region_name, $_->{'location'}->centrepoint, $_->{'ori'}, $_->{'location'}->length );
          } else {
            $highlights .= sprintf( ";s$C=%s", $_->{'species'} );
          }
        } else {
          $highlights .= sprintf( ";c=%s:%s:1;w=%s",
                       $_->{'location'}->seq_region_name, $_->{'location'}->centrepoint,
                       $_->{'location'}->length );
        }
      }
      $C++;
    }
 } ##

  my $contig_strand  = $Container->can('strand') ? $Container->strand : 1;
  my $clone_based    = $self->get_parameter( 'clone_based') eq 'yes';
  my $global_start   = $clone_based ? $self->get_parameter( 'clone_start') : $Container->start();
  my $global_end     = $global_start + $length - 1;
  my $im_width = $self->image_width();
#
########

#######
# Draw the Contig Tiling Path
#
  my $i = 1;
  my @colours  = ( [qw(contigblue1 contigblue2)] , [qw(lightgoldenrod1 lightgoldenrod3)] ) ;
  my @label_colours = qw(white black);

  foreach my $tile ( sort { $a->{'start'} <=> $b->{'start'} } @{$contig_tiling_path} ) {
    my $strand = $tile->{'ori'};
    my $rend   = $tile->{'end'};
    my $rstart = $tile->{'start'};

# AlignSlice segments can be on different strands - hence need to check if start & end need a swap

    ($rstart, $rend) = ($rend, $rstart) if $rstart > $rend ;

    my $rid = $tile->{'name'};
    $rstart = 1 if $rstart < 1;
    $rend   = $length if $rend > $length;

    #if this is a haplotype contig then need a different pair of colours for the contigs
    my $i = 0;
    if( exists($tile->{'haplotype_contig'}) ) {
      $i = $tile->{'haplotype_contig'} ? 1 : 0;
    }
    #if this is a wgs contig used in an AGP, need different colour.
    if( $tile->{'name'} =~ /CABZ/ ) {
      $i = 1;
    }

    my $action = 'View';#$ENV{'ENSEMBL_ACTION'};
    my $region = $tile->{'name'};
    my $dets = {
      'x'         => $rstart - 1,
      'y'         => 0,
      'width'     => $rend - $rstart+1,
      'height'    => $box_h,
      'colour'    => $colours[$i]->[0],
      'absolutey' => 1,
    };
    if ($show_navigation) {
      my $url = $self->_url({
	'species'  => $self->species,  # Needed especially for Compara track distincitons
	'type'     => 'Contig',
	'action'   => $action,
	'region'   => $region,
	'objstrand'        => $strand,
      });
      $dets->{'href'} = $url;
    }
    my $glyph = $self->Rect($dets);

    push @{$colours[$i]}, shift @{@colours[$i]};
    my $label = $tile->{'name'};

    $label .= " / " . $tile->{'accession'} if ( $tile->{'accession'}  && ($tile->{'accession'} ne $tile->{'name'}));
    $label .= " / " . $tile->{'int_name'} if ( $tile->{'int_name'} );

    $self->push($glyph);

    if( $h ) {
      my @res = $self->get_text_width(
        ($rend-$rstart)*$pix_per_bp,
        $strand > 0 ? "$label >" : "< $label",
        $strand > 0 ? '>' : '<',
        'font'=>$fontname, 'ptsize' => $fontsize
      );
      if( $res[0] ) {
        $self->push($self->Text({
          'x'          => ($rend + $rstart - $res[2]/$pix_per_bp)/2,
          'height'     => $res[3],
          'width'      => $res[2]/$pix_per_bp,
          'textwidth'  => $res[2],
          'y'          => ($h-$res[3])/2,
          'font'       => $fontname,
          'ptsize'     => $fontsize,
          'colour'     => $label_colours[$i],
          'text'       => $res[0],
          'absolutey'  => 1,
        }));
      }
    }
  }
}

#------------------#
# render_text
#  as advertised,
#  render_text.
#------------------#
sub render_text {
  my $self = shift;
  
  return if $self->species_defs->NO_SEQUENCE;
  
  my $container = $self->{'container'};
  my $sa = $container->adaptor;
  my $export;  
  
  foreach (@{$container->project('seqlevel')||[]}) {
    my $ctg_slice = $_->to_Slice;
    my $feature_name = $ctg_slice->coord_system->name eq 'ancestralsegment' ? $ctg_slice->{'_tree'} : $ctg_slice->seq_region_name;
    my $feature_slice = $sa->fetch_by_region('seqlevel', $feature_name)->project('toplevel')->[0]->to_Slice;
    
    $export .= $self->_render_text($_, 'Contig', { 'headers' => [ 'id' ], 'values' => [ $feature_name ] }, {
      'seqname' => $feature_slice->seq_region_name,
      'start'   => $feature_slice->start, 
      'end'     => $feature_slice->end, 
      'strand'  => $feature_slice->strand
    });
  }
  
  return $export;
}



1;
