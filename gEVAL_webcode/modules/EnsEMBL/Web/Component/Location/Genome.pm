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

package EnsEMBL::Web::Component::Location::Genome;

use strict;
use EnsEMBL::Web::Controller::SSI;
use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $id   = $self->hub->param('id'); 
  my $features = {};

  #configure two Vega tracks in one
  my $config = $self->hub->get_imageconfig('Vkaryotype');
  if ($config->get_node('Vannotation_status_left') & $config->get_node('Vannotation_status_right')) {
    $config->get_node('Vannotation_status_left')->set('display', $config->get_node('Vannotation_status_right')->get('display'));
  }

  ## Get features from URL to draw (if any)
  if ($id) {
    my $object = $self->builder->create_objects('Feature', 'lazy');
    if ($object && $object->can('convert_to_drawing_parameters')) {
      $features = $object->convert_to_drawing_parameters;
    }
  }

  my $html = $self->_render_features($id, $features, $config);
  return $html;
}

sub _render_features {
  my ($self, $id, $features, $image_config) = @_;
  my $hub          = $self->hub;
  my $species      = $hub->species;
  my $species_defs = $hub->species_defs;
  my ($html, $total_features, $mapped_features, $unmapped_features, $has_internal_data, $has_userdata);
  my $chromosomes  = $species_defs->ENSEMBL_CHROMOSOMES || [];
  my %chromosome = map {$_ => 1} @$chromosomes;
  while (my ($type, $set) = each (%$features)) {
    foreach my $feature (@{$set->[0]}) {
      $has_internal_data++;
      if ($chromosome{$feature->{'region'}}) {
        $mapped_features++;
      }
      else {
        $unmapped_features++;
      }
      $total_features++;
    }
  }

  if ($id && $total_features < 1) {
    my $ids = ref($id) eq 'ARRAY' ? join(', ', @$id) : $id;
    my $message;
    if ($self->hub->type eq 'Phenotype') {
      $message = 'No mapped variants are available for this phenotype';
    }
    else {
      $message = sprintf('<p>No mapping of %s found</p>', $ids || 'unknown feature');
    }
    return $self->_warning('Not found', $message);
  }

  ## Add in userdata tracks
  my $user_features = $image_config ? $image_config->create_user_features : {};
  while (my ($key, $data) = each (%$user_features)) {
    while (my ($analysis, $track) = each (%$data)) {
      foreach my $feature (@{$track->{'features'}}) {
        $has_userdata++;
        if ($chromosome{$feature->{'chr'}}) {
          $mapped_features++;
        }
        else {
          $unmapped_features++;
        }
        $total_features++;
      }
    }
  }

  ## Attach the colorizing key before making the image
  my $chr_colour_key = $self->chr_colour_key;
  
  $image_config->set_parameter('chr_colour_key', $chr_colour_key) if $image_config;
  
  ## Draw features on karyotype, if any
  if (scalar @$chromosomes && $species_defs->MAX_CHR_LENGTH) {
    my $image = $self->new_karyotype_image($image_config);
    
    ## Map some user-friendly display names
    my $feature_display_name = {
      'Xref'                => 'External Reference',
      'ProbeFeature'        => 'Oligoprobe',
      'DnaAlignFeature'     => 'Sequence Feature',
      'ProteinAlignFeature' => 'Protein Feature',
    };
    my ($xref_type, $xref_name);
    while (my ($type, $feature_set) = each (%$features)) {    
      if ($type eq 'Xref') {
        my $sample = $feature_set->[0][0];
        $xref_type = $sample->{'label'};
        $xref_name = $sample->{'extname'};
        $xref_name =~ s/ \[#\]//;
        $xref_name =~ s/^ //;
      }
    }

    ## Create pointers to be drawn
    my $pointers = [];
    my ($legend_info, $has_gradient);

    if ($mapped_features) {

      ## Title for image - a bit messy, but we want it to be human-readable!
      my $title;
      if ($has_internal_data) { 
        unless ($hub->param('ph')) { ## omit h3 header for phenotypes
          $title = 'Location';
          $title .= 's' if $mapped_features > 1;
          $title .= ' of ';
          my ($data_type, $assoc_name);
          my $ftype = $hub->param('ftype');
          if (grep (/$ftype/, keys %$features)) {
            $data_type = $ftype;
          }
          else {
            my @A = sort keys %$features;
            $data_type = $A[0];
            $assoc_name = $hub->param('name');
            unless ($assoc_name) {
              $assoc_name = $xref_type.' ';
              $assoc_name .= $id;
              $assoc_name .= " ($xref_name)" if $xref_name;
            }
          }

          my %names;
          ## De-camelcase names
          foreach (sort keys %$features) {
            my $pretty = $feature_display_name->{$_} || $self->decamel($_);
            $pretty .= 's' if $mapped_features > 1;
            $names{$_} = $pretty;
          }

          my @feat_names = sort values %names;
          my $last_name = pop(@feat_names);
          if (scalar @feat_names > 0) {
            $title .= join ', ', @feat_names;
            $title .= ' and ';
          }
          $title .= $last_name;
          $title .= " associated with $assoc_name" if $assoc_name;
        }
      }
      else {
        $title = 'Location of your feature';
        $title .= 's' if $has_userdata > 1;
      }
      $html .= "<h3>$title</h3>" if $title;        
     
      ## Create pointers for Ensembl features
      while (my ($feat_type, $set) = each (%$features)) {          
        my $defaults    = $self->pointer_default($feat_type);
        my $colour      = $hub->param('colour') || $defaults->[1];
        my $gradient    = $defaults->[2];
        my $pointer_ref = $image->add_pointers($hub, {
          config_name  => 'Vkaryotype',
          features     => $set->[0],
          feature_type => $feat_type,
          color        => $colour,
          style        => $hub->param('style')  || $defaults->[0],            
          gradient     => $gradient,
        });
        $legend_info->{$feat_type} = {'colour' => $colour, 'gradient' => $gradient};  
        push @$pointers, $pointer_ref;
        $has_gradient++ if $gradient;
      }

      ## Create pointers for userdata
      if (keys %$user_features) {
        push @$pointers, $self->create_user_pointers($image, $user_features);
      } 

    }

    $image->image_name = @$pointers ? "feature-$species" : "karyotype-$species";
    $image->imagemap   = @$pointers ? 'yes' : 'no';
      
    $image->set_button('drag', 'title' => 'Click on a chromosome');
    $image->caption  = 'Click on the image above to jump to a chromosome, or click and drag to select a region';
    $image->imagemap = 'yes';
    $image->karyotype($hub, $self->object, $pointers, 'Vkaryotype');
      
    return if $self->_export_image($image,'no_text');
      
    $html .= $image->render;
    $html .= $self->get_chr_legend($chr_colour_key);

    ## Add colour key if required
    if ($self->html_format && (scalar(keys %$legend_info) > 1 || $has_gradient)) { 
      $html .= '<h3>Key</h3>';

      my $columns = [
        {'key' => 'ftype',  'title' => 'Feature type'},
        {'key' => 'colour', 'title' => 'Colour'},
      ];
      my $rows;

      foreach my $type (sort keys %$legend_info) {
        my $type_name = $feature_display_name->{$type} || $type;
        my $colour    = $legend_info->{$type}{'colour'};
        my @gradient  = @{$legend_info->{$type}{'gradient'}||[]};
        my $swatch    = '';
        my $legend    = '';
        if ($colour eq 'gradient' && @gradient) {
          $gradient[0] = '20';
          my @colour_scale = $hub->colourmap->build_linear_gradient(@gradient);
          my $i = 1;
          foreach my $step (@colour_scale) {                
            my $label;
            if ($i == 1) {
              $label = sprintf("%.1f", $i);
            } 
            elsif ($i == scalar @colour_scale) {
              $label = '>'.$i/2;
            }
            else {
              $label = $i % 3 ? '' : sprintf("%.1f", ($i/3 + 2));
            }
            $swatch .= qq{<div style="background:#$step">$label</div>};
            $i++;
          }
          $legend = sprintf '<div class="swatch-legend">Less significant -log(p-values) &#9668;<span>%s</span>&#9658; More significant -log(p-values)</div>', ' ' x 20;
        }
        else {
          $swatch = qq{<div style="background-color:$colour;" title="$colour"></div>};
        }
        push @$rows, {
              'ftype'  => {'value' => $type_name},
              'colour' => {'value' => qq(<div class="swatch-wrapper"><div class="swatch">$swatch</div>$legend</div>)},
        };
      }
      my $legend = $self->new_table($columns, $rows); 
      $html .= $legend->render;
    }
      
    if ($unmapped_features > 0) {
      my $message;
      if ($mapped_features) {
        my $do    = $unmapped_features > 1 ? 'features do' : 'feature does';
        my $have  = $unmapped_features > 1 ? 'have' : 'has';
        $message = "$unmapped_features $do not map to chromosomal coordinates and therefore $have not been drawn.";
      }
      else {
        $message = 'No features map to chromosomal coordinates.'
      }
      $html .= $self->_info('Undrawn features', "<p>$message</p>");
    }

  } elsif (!scalar @$chromosomes) {
    $html .= $self->_info('Unassembled genome', '<p>This genome has yet to be assembled into chromosomes</p>');
  }

  ## Create HTML tables for features, if any
  my $default_column_info = {
    'names'   => {'title' => 'Ensembl ID'},
    'loc'     => {'title' => 'Genomic location (strand)', 'sort' => 'position_html'},
    'extname' => {'title' => 'External names'},
    'length'  => {'title' => 'Length', 'sort' => 'numeric'},
    'lrg'     => {'title' => 'Name'},
    'xref'    => {'title' => 'Name(s)'},
  };

      #
      # ::ADD:: wc2 adding the dropdown menus of seqregion top level 
      #    components, not drawn from the ENSEMBL_CHROMOSOME variable in the .ini files. 
      #

      my %chromosomes = map {$_, 1} @{$chromosomes};
      my $sa          = $hub->database('core')->get_SliceAdaptor();
      my $top_slices  = $sa->fetch_all('toplevel');

      my @top_links;
      foreach my $top_slice (sort {$a->seq_region_name cmp $b->seq_region_name } @{$top_slices}) {
          next if ( $chromosomes{$top_slice->seq_region_name});
          push @top_links, "<option value='".$top_slice->seq_region_name.":1-10000'>".$top_slice->seq_region_name."</option>";
      }

      if ( @top_links ) {

        $html .= "<BR><table   padding=3 >";
        $html .= "<tr>";
        $html .= "<td valign=middle> Select sub/unplaced/unlocalised-region: &nbsp</td>";
        $html .= "<td>  <form action='/$species/Location/View'> <select name='r'>";
        $html .= "<option value=''>==</option>";
        $html .= join("",@top_links);
        $html .= "</select>";
        $html .= "&nbsp <input type='submit' value='Go' class='red-button' /></form></td>";
        $html .= "</tr></table>";
      }

      # ::

  while (my ($feat_type, $feature_set) = each (%$features)) {
    $html .= $self->_feature_table($feat_type, $feature_set, $default_column_info);
  }

  ## User tables
  if (keys %$user_features) {
    ## Colour key
    my $table_info  = $self->configure_UserData_key($image_config);
    my $column_info = $default_column_info;
    my $columns     = [];
    my $col;

    foreach $col (@{$table_info->{'column_order'}||[]}) {
      push @$columns, {'key' => $col, 'title' => $column_info->{$col}{'title'}};
    }

    my $table = $self->new_table($columns, $table_info->{'rows'}, { header => 'no' });
    $html .= "<h3>$table_info->{'header'}</h3>";
    $html .= $table->render;

    ## Table(s) of features
    while (my ($k, $v) = each (%$user_features)) {
      while (my ($ftype, $data) = each (%$v)) {
        my $extra_columns = $ftype eq 'Gene' ?
                            [{'key'=>'description', 'title'=>'Description'}]
                            : [
                              {'key' => 'align',    'title' => 'Alignment length'},
                              {'key' => 'ori',      'title' => 'Rel ori'},
                              {'key' => 'id',       'title' => '%id'},
                              {'key' => 'score',    'title' => 'Score'},
                              {'key' => 'p-value',  'title' => 'p-value'},
                              ]; 
        $html .= $self->_feature_table($ftype, [$data->{'features'}, $extra_columns], $default_column_info);
      }
    }

  }

  unless (keys %$features || keys %$user_features) {
    $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/stats_$species.html");
  }

  ## Done!
  return $html;
}

sub _feature_table {
  my ($self, $feat_type, $feature_set, $default_column_info) = @_;
  my $html;

  my $method = '_configure_'.$feat_type.'_table';
  if ($self->can($method)) {
    my $table_info = $self->$method($feat_type, $feature_set);
    my $column_info = $table_info->{'custom_columns'} || $default_column_info;
    my $columns = [];
    my $col;

    foreach $col (@{$table_info->{'column_order'}||[]}) {
      push @$columns, { 'key' => $col, %{$column_info->{$col}} };
    }

    ## Add "extra" columns (unique to particular table types)
    my $extras = $feature_set->[1];
    foreach $col (@$extras) {
      my %column_extra = %{$column_info->{$col->{'key'}}||{}};
      push @$columns, {
                  'key'   => $col->{'key'}, 
                  'title' => $col->{'title'}, 
                  'sort'  => $col->{'sort'},
                  %column_extra,
                  }; 
    }
      
    my $table = $self->new_table($columns, $table_info->{'rows'}, { data_table => 1, id => "${feat_type}_table", %{$table_info->{'table_style'} || {}} });
    $html .= "<h3>$table_info->{'header'}</h3>";
    $html .= $table->render;
  }

  return $html;
}


sub _configure_Gene_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $rows = [];
 
  my $header = 'Gene Information';
  if ($self->hub->param('ftype') eq 'Domain') {
    ## Override default header
    my $domain_id = $self->hub->param('id');
    my $count     = scalar @{$feature_set->[0]};
    my $plural    = $count > 1 ? 'genes' : 'gene';
    $header       = "Domain $domain_id maps to $count $plural:";
  }

  my $column_order = [qw(names loc extname)];

  my ($data, $extras) = @$feature_set;
  foreach my $feature ($self->_sort_features_by_coords($data)) {
    my $row = {
              'extname' => {'value' => $feature->{'extname'}},
              'names'   => {'value' => $self->_names_link($feature, $feature_type)},
              'loc'     => {'value' => $self->_location_link($feature)},
              };
    $self->add_extras($row, $feature, $extras);
    push @$rows, $row;
  }

  return {'header' => $header, 'column_order' => $column_order, 'rows' => $rows}; 
}

sub _configure_Transcript_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $info = $self->_configure_Gene_table($feature_type, $feature_set);
  ## Override default header
  $info->{'header'} = 'Transcript Information';
  return $info; 
}

sub _configure_ProbeFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $rows = [];
  
  my $column_order = [qw(loc length names)];

  my $header = 'Oligoprobe Information';
 
  my ($data, $extras) = @$feature_set;
  foreach my $feature ($self->_sort_features_by_coords($data)) {
    my $row = {
              'loc'     => {'value' => $self->_location_link($feature)},
              'length'  => {'value' => $feature->{'length'},          }, 
              'names'   => {'value' => $feature->{'label'},           },
              };
    $self->add_extras($row, $feature, $extras);
    push @$rows, $row;
  }

  return {'header' => $header, 'column_order' => $column_order, 'rows' => $rows}; 
}

sub _configure_RegulatoryFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $info = $self->_configure_ProbeFeature_table($feature_type, $feature_set);
  ## Override default header
  my $rf_id     = $self->hub->param('id');
  my $ids       = join(', ', $rf_id);
  my $count     = scalar @{$feature_set->[0]};
  my $plural    = $count > 1 ? 'Factors' : 'Factor';
  $info->{'header'} = "Regulatory Features associated with Regulatory $plural $ids";
  return $info;
}

sub _configure_Xref_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $rows = [];
  
  my $column_order = [qw(loc length xref)];

  my $header = 'External References';
 
  my ($data, $extras) = @$feature_set;
  foreach my $feature ($self->_sort_features_by_coords($data)) {
    my $row = {
              'loc'     => {'value' => $self->_location_link($feature)},
              'length'  => {'value' => $feature->{'length'},          }, 
              'xref'    => {'value' => $feature->{'label'},           },
              };
    $self->add_extras($row, $feature, $extras);
    push @$rows, $row;
  }

  return {'header' => $header, 'column_order' => $column_order, 'rows' => $rows}; 
}

sub _configure_DnaAlignFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $info = $self->_configure_Xref_table($feature_type, $feature_set);
  ## Override default header
  $info->{'header'} = 'Sequence Feature Information';
  return $info; 
}

sub _configure_ProteinAlignFeature_table {
  my ($self, $feature_type, $feature_set) = @_;
  my $info = $self->_configure_Xref_table($feature_type, $feature_set);
  ## Override default header
  $info->{'header'} = 'Protein Feature Information';
  return $info; 
}

sub add_extras {
  my ($self, $row, $feature, $extras) = @_;
  foreach my $col (@$extras) {
    my $key = $col->{'key'};
    $row->{$key} = {'value' => $feature->{'extra'}{$key} || $feature->{$key}};
  }
}

sub _sort_features_by_coords {
  my ($self, $data) = @_;

  my @sorted =  map  { $_->[0] }
                sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
                map  { [ $_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20, $_->{'region'}, $_->{'start'} ] }
                @$data;

  return @sorted;
}

sub _location_link {
  my ($self, $f) = @_;
  my $region = $f->{'region'} || $f->{'chr'};
  return 'Unmapped' unless $region;
  my $coords = $region.':'.$f->{'start'}.'-'.$f->{'end'};
  my $link = sprintf(
          '<a href="%s">%s:%d-%d(%d)</a>',
          $self->hub->url({
            type    => 'Location',
            action  => 'View',
            r       => $coords, 
            h       => $f->{'label'},
            ph      => $self->hub->param('ph'),
            __clear => 1
          }),
          $region, $f->{'start'}, $f->{'end'},
          $f->{'strand'}
  );
  return $link;
}

sub _names_link {
  my ($self, $f, $type) = @_;
  my $region = $f->{'region'} || $f->{'chr'};
  my $coords    = $region.':'.$f->{'start'}.'-'.$f->{'end'};
  my $obj_param = $type eq 'Transcript' ? 't' : 'g';
  my $params = {
    'type'      => $type, 
    'action'    => 'Summary',
    $obj_param  => $f->{'label'},
    'r'         => $coords, 
    'ph'        => $self->hub->param('ph'),
    __clear     => 1
  };

  my $names = sprintf('<a href="%s">%s</a>', $self->hub->url($params), $f->{'label'});
  return $names;
}

1;