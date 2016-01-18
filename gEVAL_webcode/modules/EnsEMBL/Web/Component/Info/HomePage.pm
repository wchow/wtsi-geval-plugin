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

package EnsEMBL::Web::Component::Info::HomePage;

use strict;

use EnsEMBL::Web::Document::HTML::HomeSearch;
use EnsEMBL::Web::DBSQL::ProductionAdaptor;
use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}


#---- Added a few extra blocks of text pertaining to Punchlists, GRC, Jira etc. ----#
sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $img_url      = $self->img_url;
  my $common_name  = $species_defs->SPECIES_COMMON_NAME;
  my $display_name = $species_defs->SPECIES_SCIENTIFIC_NAME;
  my $assembly_name= $species_defs->ASSEMBLY_NAME;
  my $assembly_display_name = $species_defs->ASSEMBLY_DISPLAY_NAME;
  my $assembly_accession    = $species_defs->ASSEMBLY_ACCESSION;
  my $assembly_long_name    = $species_defs->ASSEMBLY_LONG_NAME;
  my $orgname               = $species_defs->SPECIES_ORGANISM_NAME || $common_name;
 
  $self->{'icon'}     = qq{<img src="${img_url}24/%s.png" alt="" class="homepage-link" />};
  $self->{'img_link'} = qq{<a class="nodeco _ht _ht_track" href="%s" title="%s"><img src="${img_url}96/%s.png" alt="" class="bordered" />%s</a>};
  
  return sprintf('
    <div class="column-wrapper">  
      <div class="box-left">
        <div class="species-badge">
          <img src="%sspecies/mini_%s.png" alt="" title="%s" />
          %s
        </div>
        %s
      </div>
      %s
    </div>
    <div class="box-left"><div class="round-box tinted-box unbordered">%s</div></div>
    <div class="box-right"><div class="round-box tinted-box unbordered">%s</div></div>
    <div class="box-left"><div class="round-box tinted-box unbordered">%s</div></div>
    <div class="box-right"><div class="round-box tinted-box unbordered">%s</div></div>
    <div class="box-left"><div class="round-box tinted-box unbordered">%s</div></div>
    %s',
    $img_url, $display_name, $species_defs->SAMPLE_DATA->{'ENSEMBL_SOUND'},
    $common_name =~ /\./ ? "<h1>$common_name</h1>" : "<h1>$orgname ($assembly_display_name)</h1><p>$display_name - $assembly_long_name<br>$assembly_accession</p>",
    EnsEMBL::Web::Document::HTML::HomeSearch->new($hub)->render,
    $species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'} ? '<div class="box-right"><div class="round-box info-box unbordered">' . $self->whats_new_text . '</div></div>' : '',
    $self->project_text,
    $self->assembly_text,
    $self->punchlist_text,
    $self->grc_text,
    $self->compara_text,
    $hub->database('funcgen') ? '<div class="box-left"><div class="round-box tinted-box unbordered">' . $self->funcgen_text . '</div></div>' : ''
  );
}

sub whats_new_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $news_url     = $hub->url({ action => 'WhatsNew' });

  my $html = sprintf(
    q{<h2><a href="%s" title="More release news"><img src="%s24/announcement.png" style="vertical-align:middle" alt="" /></a> What's New in %s release %s</h2>},
    $news_url,
    $self->img_url,
    $species_defs->SPECIES_COMMON_NAME,
    $species_defs->ENSEMBL_VERSION,
  );

  if ($species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}) {
    my $changes = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub)->fetch_changelog({ release => $species_defs->ENSEMBL_VERSION, species => $hub->species, limit => 3 });
    
    $html .= '<ul>';
    $html .= qq{<li><a href="$news_url#change_$_->{'id'}" class="nodeco">$_->{'title'}</a></li>} for @$changes;
    $html .= '</ul>';
    $html .= qq{<div style="text-align:right;margin-top:-2em;padding-bottom:8px"><a href="$news_url" class="nodeco">More news</a>...</div>};
  }

  return $html;
}

sub assembly_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ftp             = $species_defs->ENSEMBL_FTP_URL;
  my $ensembl_version = $species_defs->ENSEMBL_VERSION;
  my $assembly        = $species_defs->ASSEMBLY_NAME;

  my $assembly_date   = $species_defs->ASSEMBLY_DATE; # added by wc2 11.2013.
  my $assembly_name   = $species_defs->get_config($species, 'ASSEMBLY_LONG_NAME');
	
  my $mappings        = $species_defs->ASSEMBLY_MAPPINGS;
  my $gca             = $species_defs->ASSEMBLY_ACCESSION;
  my $archive         = $species_defs->get_config($species, 'ENSEMBL_ARCHIVES') || {};
  my $assemblies      = $species_defs->get_config($species, 'ASSEMBLIES')       || {};
  my $pre_species     = $species_defs->get_config('MULTI', 'PRE_SPECIES');
  my @other_assemblies;
 
  my $html = sprintf('
    <div class="homepage-icon">
      %s
      %s
    </div>
    <h2>Genome assembly: %s%s</h2>
    <p><a href="%s#assembly" class="nodeco">%sMore information and statistics</a></p>
    %s
    %s
    <p><a href="%s" class="modal_link nodeco">%sDisplay your data in %s</a></p>',
    
    scalar @{$species_defs->ENSEMBL_CHROMOSOMES || []} ? sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Location', action => 'Genome', __clear => 1 }),
      'Go to ' . $species_defs->SPECIES_COMMON_NAME . ' karyotype', 'karyotype', 'View karyotype'
    ) : '',
    
    sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Location', action => 'View', r => $sample_data->{'LOCATION_TEXT'}, __clear => 1 }),
      "Go to $sample_data->{'LOCATION_TEXT'}", 'region', 'Example region'
    ),
    
    $assembly_date ? "$assembly_date" : $assembly, $gca ? " <small>($gca)</small>" : '',
    $hub->url({ action => 'Annotation', __clear => 1 }), sprintf($self->{'icon'}, 'info'),
    
    $assembly_name ? sprintf(
      '<p><a href="http://www.sanger.ac.uk/cgi-bin/humpub/chromoview" class="nodeco">%sRetrieve a live status of the current tiling path using the tool Chromoview</a></p>', 
      sprintf($self->{'icon'}, 'tool')
    ) : '',
   
    $mappings && ref $mappings eq 'ARRAY' ? sprintf(
      '<p><a href="%s" class="modal_link nodeco">%sConvert your data to %s coordinates</a></p>', ## Link to assembly mapper
      $hub->url({ type => 'UserData', action => 'SelectFeatures', __clear => 1 }), sprintf($self->{'icon'}, 'tool'), $assembly
    ) : '',
    
    $hub->url({ type => 'UserData', action => 'SelectFile', __clear => 1 }), sprintf($self->{'icon'}, 'page-user'), $species_defs->ENSEMBL_SITETYPE
  );
  
  ## Insert dropdown list of old assemblies
  foreach my $release (reverse sort keys %$archive) {
    next if $release == $ensembl_version || $assemblies->{$release} eq $assembly;
    
    push @other_assemblies, {
      url      => sprintf('http://%s.archive.ensembl.org/%s/', lc $archive->{$release}, $species),
      assembly => "$assemblies->{$release}",
      release  => (sprintf '(%s release %s)', $species_defs->ENSEMBL_SITETYPE, $release),
    };
    
    $assembly = $assemblies->{$release};
  }
  
  push @other_assemblies, { url => "http://pre.ensembl.org/$species/", assembly => $pre_species->{$species}[1], release => '(Ensembl pre)' } if $pre_species->{$species};

  if (scalar @other_assemblies) {
    $html .= '<h3 style="color:#808080;padding-top:8px">Other assemblies</h3>';
    
    if (scalar @other_assemblies > 1) {
      $html .= qq{<form action="/$species/redirect" method="get"><select name="url">};
      $html .= qq{<option value="$_->{'url'}">$_->{'assembly'} $_->{'release'}</option>} for @other_assemblies;
      $html .= '</select> <input type="submit" name="submit" class="fbutton" value="Go" /></form>';
    } else { 
      $html .= qq{<ul><li><a href="$other_assemblies[0]{'url'}" class="nodeco">$other_assemblies[0]{'assembly'}</a> $other_assemblies[0]{'release'}</li></ul>};
    }
  }

  return $html;
}

sub genebuild_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $species      = $hub->species;
  my $sample_data  = $species_defs->SAMPLE_DATA;
  my $ftp          = $species_defs->ENSEMBL_FTP_URL;

  return sprintf('
    <div class="homepage-icon">
      %s
      %s
    </div>
    <h2>Gene annotation</h2>
    <p><strong>What can I find?</strong> Protein-coding and non-coding genes, splice variants, cDNA and protein sequences, non-coding RNAs.</p>
    <p><a href="%s#genebuild" class="nodeco">%sMore about this genebuild</a></p>
    %s
    <p><a href="%s" class="modal_link nodeco">%sUpdate your old Ensembl IDs</a></p>
    %s',
    
    sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Gene', action => 'Summary', g => $sample_data->{'GENE_PARAM'}, __clear => 1 }),
      "Go to gene $sample_data->{'GENE_TEXT'}", 'gene', 'Example gene'
    ),
    
    sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Transcript', action => 'Summary', t => $sample_data->{'TRANSCRIPT_PARAM'} }),
      "Go to transcript $sample_data->{'TRANSCRIPT_TEXT'}", 'transcript', 'Example transcript'
    ),
    
    $hub->url({ action => 'Annotation', __clear => 1 }), sprintf($self->{'icon'}, 'info'),
    
    $ftp ? sprintf(
      '<p><a href="%s/release-%s/fasta/%s/" class="nodeco">%sDownload genes, cDNAs, ncRNA, proteins</a> (FASTA)</p>', ## Link to FTP site
      $ftp, $species_defs->ENSEMBL_VERSION, lc $species, sprintf($self->{'icon'}, 'download')
    ) : '',
    
    $hub->url({ type => 'UserData', action => 'UploadStableIDs', __clear => 1 }), sprintf($self->{'icon'}, 'tool'),
    
    $species_defs->get_config('MULTI', 'ENSEMBL_VEGA')->{$species} ? qq{
      <a href="http://vega.sanger.ac.uk/$species/" class="nodeco">
      <img src="/img/vega_small.gif" alt="Vega logo" style="float:left;margin-right:8px;margin-bottom:1em;width:83px;height:30px;vertical-align:center" title="Vega - Vertebrate Genome Annotation database" /></a>
      <p>Additional manual annotation can be found in <a href="http://vega.sanger.ac.uk/$species/" class="nodeco">Vega</a></p>
    } : ''
  );
}

sub compara_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $sample_data  = $species_defs->SAMPLE_DATA;
  my $ftp          = $species_defs->ENSEMBL_FTP_URL;
  my $compara_url  = $sample_data->{'COMPARA_URL'};
  my ($r, $r1, $s1) = ($compara_url =~ /r=(.*);r1=(.*);s1=(.*)/);	

  return sprintf('
    <div class="homepage-icon">
      %s
    </div>
    <h2>Comparative genomics</h2>
    <p>gEVAL provides intra-species alignments.  This is available for intermediate builds, major reference releases, and WGS/NGS assemblies.</p>
    <p><a href="/info/website/help/pgp_docs_v1.2.htm#compara" class="nodeco">%sMore about comparative analysis</a></p>
    %s',
    
    ($sample_data->{'COMPARA_URL'}) ?
    sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Location', action => 'Multi', r => $r, r1 => $r1, s1 => $s1, __clear => 1 }),
      "Go to compara example for $sample_data->{'GENE_TEXT'}", 'compara', 'Example compara'
    )
    : "",
    
    sprintf($self->{'icon'}, 'info'),
    
    $ftp ? sprintf(
      '<p><a href="%s/release-%s/emf/ensembl-compara/" class="nodeco">%sDownload alignments</a> (EMF)</p>', ## Link to FTP site
      $ftp, $species_defs->ENSEMBL_VERSION, sprintf($self->{'icon'}, 'download')
    ) : ''
  );
}

sub variation_text {
  my $self = shift;
  my $hub  = $self->hub;
  my $html;

  if ($hub->database('variation')) {
    my $species_defs = $hub->species_defs;
    my $sample_data  = $species_defs->SAMPLE_DATA;
    my $ftp          = $species_defs->ENSEMBL_FTP_URL;
       $html         = sprintf('
      <div class="homepage-icon">
        %s
        %s
        %s
      </div>
      <h2>Variation</h2>
      <p><strong>What can I find?</strong> Short sequence variants%s%s</p>
      <p><a href="/info/genome/variation/" class="nodeco">%sMore about variation in %s</a></p>
      %s',
      
      $sample_data->{'VARIATION_PARAM'} ? sprintf(
        $self->{'img_link'},
        $hub->url({ type => 'Variation', action => 'Explore', v => $sample_data->{'VARIATION_PARAM'}, __clear => 1 }),
        "Go to variant $sample_data->{'VARIATION_TEXT'}", 'variation', 'Example variant'
      ) : '',
      
      $sample_data->{'PHENOTYPE_PARAM'} ? sprintf(
        $self->{'img_link'},
        $hub->url({ type => 'Phenotype', action => 'Locations', ph => $sample_data->{'PHENOTYPE_PARAM'}, __clear => 1 }),
        "Go to phenotype $sample_data->{'PHENOTYPE_TEXT'}", 'phenotype', 'Example phenotype'
      ) : '',
      
      $sample_data->{'STRUCTURAL_PARAM'} ? sprintf(
        $self->{'img_link'},
        $hub->url({ type => 'StructuralVariation', action => 'Explore', sv => $sample_data->{'STRUCTURAL_PARAM'}, __clear => 1 }),
        "Go to structural variant $sample_data->{'STRUCTURAL_TEXT'}", 'struct_var', 'Example structural variant'
      ) : '',
      
      $species_defs->databases->{'DATABASE_VARIATION'}{'STRUCTURAL_VARIANT_COUNT'} ? ' and longer structural variants' : '', $sample_data->{'PHENOTYPE_PARAM'} ? '; disease and other phenotypes' : '',
      
      sprintf($self->{'icon'}, 'info'), $species_defs->ENSEMBL_SITETYPE,
      
      $ftp ? sprintf(
        '<p><a href="%s/release-%s/variation/gvf/%s/" class="nodeco">%sDownload all variants</a> (GVF)</p>', ## Link to FTP site
        $ftp, $species_defs->ENSEMBL_VERSION, lc $hub->species, sprintf($self->{'icon'}, 'download')
      ) : ''
    );
  } else {
    $html .= '
      <h2>Variation</h2>
      <p>This species currently has no variation database. However you can process your own variants using the Variant Effect Predictor:</p>
    ';
  }
  
  $html .= sprintf(
    qq{<p><a href="%s" class="modal_link nodeco">$self->{'icon'}Variant Effect Predictor<img src="%svep_logo_sm.png" style="vertical-align:top;margin-left:12px" /></a></p>},
    $hub->url({ type => 'UserData', action => 'UploadVariations', __clear => 1 }),
    'tool',
    $self->img_url
  );

  return $html;
}

sub funcgen_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $sample_data  = $species_defs->SAMPLE_DATA;
  
  if ($sample_data->{'REGULATION_PARAM'}) {
    my $species = $hub->species;
    my $ftp     = $species_defs->ENSEMBL_FTP_URL;
    
    return sprintf('
      <div class="homepage-icon">
        %s
        %s
      </div>
      <h2>Regulation</h2>
      <p><strong>What can I find?</strong> DNA methylation, transcription factor binding sites, histone modifications, and regulatory features such as enhancers and repressors, and microarray annotations.</p>
      <p><a href="/info/genome/funcgen/" class="nodeco">%sMore about the %s regulatory build</a> and <a href="/info/genome/microarray_probe_set_mapping.html" class="nodeco">microarray annotation</a></p>
      %s',
      
      sprintf(
        $self->{'img_link'},
        $hub->url({ type => 'Regulation', action => 'Cell_line', db => 'funcgen', rf => $sample_data->{'REGULATION_PARAM'}, __clear => 1 }),
        "Go to regulatory feature $sample_data->{'REGULATION_TEXT'}", 'regulation', 'Example regulatory feature'
      ),
      
      $species eq 'Homo_sapiens' ? '
        <a class="nodeco _ht _ht_track" href="/info/website/tutorials/encode.html" title="Find out about ENCODE data"><img src="/img/ENCODE_logo.jpg" class="bordered" /><span>ENCODE data in Ensembl</span></a>
      ' : '',

      sprintf($self->{'icon'}, 'info'), $species_defs->ENSEMBL_SITETYPE,
      
      $ftp ? sprintf(
        '<p><a href="%s/release-%s/regulation/%s/" class="nodeco">%sDownload all regulatory features</a> (GFF)</p>', ## Link to FTP site
        $ftp, $species_defs->ENSEMBL_VERSION, lc $species, sprintf($self->{'icon'}, 'download')
      ) : '',
    );
  } else {
    return sprintf('
      <h2>Regulation</h2>
      <p><strong>What can I find?</strong> Microarray annotations.</p>
      <p><a href="/info/genome/microarray_probe_set_mapping.html" class="nodeco">%sMore about the %s microarray annotation strategy</a></p>',
      sprintf($self->{'icon'}, 'info'), $species_defs->ENSEMBL_SITETYPE
    );
  }
}

#---- Returns the SpeciesBlurb that is seen in the old PGPViewer ----#
#-- This takes into account what file to return due to the date    --#
#-- in PGP Builds.                                                 --#
sub project_text {

  my $self        = shift;
  my $hub         = $self->hub;	
  my $species     = $hub->species;
  
  my $common_name = $hub->species_defs->SPECIES_COMMON_NAME;

  my $file1   = "/ssi/species/about_".$species.".html";

  # add wc2, this is to solve the issue of new pgpviewers with timestamp not defaulting to the static organism page. 
  if ( $species =~/mini/ ){
       $file1 = "/ssi/species/about_mini_pgp.html";
  }   
  elsif ( $species =~ /(zfish|human|mouse)_(\d+)/i ) {
      my ($justSpecies) = ($species =~ /(\w+)_\d+/);
      $file1 = "/ssi/species/about_".$justSpecies.".html";    
  }     
  elsif ( $species =~/GRC\w+p\d+/ ){
      my ($justSpecies) = ($species =~ /(\w+)p\d+/);
      $file1 = "/ssi/species/about_".$justSpecies.".html";
  }
  
  $species        =~ s/_/ /g;
  my $name_string = $common_name =~ /\./ ? "<i>$species</i>" : "$common_name (<i>$species</i>)";
  my $html;

  ## Assembly blurb
  use EnsEMBL::Web::Controller::SSI;
  if ( EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $file1) eq ""){
      $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/about_unavailable.html");
  }
  else {
      $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $file1);	
  }	

  return $html;

}

#---- A bit about the GRC and Jira System ----#
sub grc_text {

  my $self        = shift;
  my $hub         = $self->hub; 
  my $species     = $hub->species;
 
  my $sitename       = $hub->species_defs->ENSEMBL_SITETYPE; 
  my $common_name    = $hub->species_defs->SPECIES_COMMON_NAME;
  my $organism_name  = $hub->species_defs->SPECIES_ORGANISM_NAME || $hub->species_defs->SPECIES_DESCRIPTION ||'';
  my $sample_data    = $hub->species_defs->SAMPLE_DATA;



  return sprintf('
    <div class="homepage-icon">
      %s
      %s
    </div>
    <h2>The Genome Reference Consortium</h2>
    <p>The %s %s is maintained and improved by the Genome Reference Consortium <strong>(GRC)</strong></p>
    <p><strong>Jira Ticketing System:</strong> Jira is the ticketing tracking system used by the GRC for genome issues.
	This can be a <i>gap, path, variation, gene or other issues</i> submitted by external users</p>
    <p>%s<a href="http://www.ncbi.nlm.nih.gov/projects/genome/assembly/grc/%s/issues/" class="nodeco">List of Jira issues for %s</a></p>',

    #--img link calls a sprintf, with %s=>href,title,img.png,text.	
    sprintf(
      $self->{'img_link'},
      "http://www.ncbi.nlm.nih.gov/projects/genome/assembly/grc/",
      "Genome Reference Consortium", "GRC", ""
    ),

    ($sample_data->{'JIRA_TEXT'}) ?
    sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Jira', action => 'JiraSummary', id => $sample_data->{'JIRA_ID'}, __clear => 1 }),
      "Go to $sample_data->{'JIRA_TEXT'}", "struct_var", "Example Jira Ticket"
    )
    : "",

    $organism_name, $sitename,
    sprintf($self->{'icon'}, 'download'), lc($organism_name), $organism_name,

   );
}

#---- Punchlist relevant text ----#
sub punchlist_text {

  my $self        = shift;
  my $hub         = $self->hub; 
  my $species     = $hub->species;
 
  my $sitename       = $hub->species_defs->ENSEMBL_SITETYPE; 
  my $common_name    = $hub->species_defs->SPECIES_COMMON_NAME;
  my $organism_name  = $hub->species_defs->SPECIES_ORGANISM_NAME || $hub->species_defs->SPECIES_DESCRIPTION ||'';
  my $sample_data    = $hub->species_defs->SAMPLE_DATA;

  return sprintf('
    <div class="homepage-icon">
      %s
    </div>
    <h2>Punchlists</h2>
    <p>The %s Punchlists are automated lists created to facilitate identification of and navigation to common issues or regions of interest.</p>
    <p> Examples include: <ul><li>Gap Locations</li><li>Overlap Issues</li><li>Clone Spanning Locations</li></ul></p>
    <p> If you would like to recommend a punchlist to be added to a specific organism or in general please %s </p>',
    
    sprintf(
      $self->{'img_link'},
      $hub->url({ type => 'Punchlist', action => 'Overview', __clear => 1 }),
      "Go to Punchlist Overview", "glove", "Punchlist Overview"
    ),

    $organism_name,
    '<a href="mailto:geval-help@sanger.ac.uk" class="nodeco">contact us</a>'    

  );	
}



1;
