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

package EnsEMBL::Web::Factory::Search;
use strict;
use base qw(EnsEMBL::Web::Factory);

#########################################################################
# Simple text-based MySQL search (UniSearch) - default unless overridden
#
# While most ensembl sites use a java based lucene search engine which
# requires software, webservice and specific indices.  gEVAL will use the
# basic mysql search criteria.
#
#   wc2@sanger.ac.uk
#########################################################################

sub createObjects { 
  my $self       = shift;    
  my $idx      = $self->param('type') || $self->param('idx') || 'all';
  ## Action search...
  my $search_method = "search_".uc($idx);
  if( $self->param('q') ) {
    if( $self->can($search_method) ) {
      $self->{to_return} = 25;
      $self->{_result_count} = 0;
      $self->{_results}      = [];
      $self->$search_method();

      ## Count what we actually got!
      while (my ($type, $r) = each(%{$self->{results}})) {
        $self->{_result_count} += scalar(@{$r->[0]||[]});
      }

      $self->DataObjects($self->new_object( 'Search', { 'idx' => $idx , 'q' => $self->param('q'), 'results' => $self->{results}, 'total_hits' => $self->{_result_count} }, $self->__data ));
    } else {
      $self->problem( 'fatal', 'Unknown search method', qq(
      <p>
        Sorry do not know how to search for features of type "$idx"
      </p>) );
    }
  } else {
    $self->DataObjects($self->new_object( 'Search', { 'idx' => $idx , 'q' => '', 'results' => {}, 'total_hits' => 0 }, $self->__data ));
  }

}

#------------------------------#
# parsing, and releasing the
# search terms.
#------------------------------#
sub terms {
  #my $self = shift;
  my ($self, $db, $type) = @_;
  my @list = ();
  my @qs   = $self->param('q');
  my @clean_kws;

  ## deal with quotes and multiple keywords
  foreach my $q (@qs) {
    $q =~ s/\*+$/%/;
    ## pull out terms with quotes around them (and drop the quotes whilst we're at it)
    my @quoted = $q =~ /['"]([^'"]+)['"]/g;
    $q =~ s/(['"][^'"]+['"])//g;
    push @clean_kws, @quoted;
    ## split remaining terms on whitespace
    $q =~ s/^\s|\s$//;
    push @clean_kws, split /\s+/, $q;
  }

  ## create SQL criteria
  foreach my $kw ( @clean_kws ) {
   #
   # ::ADD:: wc2 added this call to take into account the internal/external naming of clones in the Assemblies.
   #
    my ($keyword, $alt_keyword) = $self->get_all_names($kw,$db);
    # User returned a problem warning statement saying the search term isn't specfic enough ie abc.
    if ($keyword =~ /Not Specific Enough/){
        $self->problem( 'fatal', $type.' Search', qq(<p>Sorry the term <strong>"$kw"</strong> is returning more results than expected.  This can be due to a short name or micropatches containing similar names.  Please be more specific, such as including the version number (eg ${kw}.1).</p>) );
        return ();
       }	
   # ::
      
    my $seq = $kw =~ /%/ ? 'like' : '=';
    push @list, [ $seq, $keyword ]     if ($keyword);
    push @list, [ $seq, $alt_keyword ] if ($alt_keyword);
   
  }
  return @list;
}

#----------------------------#
# Quick count of sql results
#----------------------------#
sub count {
  my( $self, $db, $sql, $comp, $kw ) = @_;

  my $dbh = $self->database($db);
  return 0 unless $dbh;
  my $full_kw = $kw; 
  $full_kw =~ s/\%/\*/g;

  #
  # ::ADD:: wc2 added options for non-specific searches.
  #
  my $dbl_kw = $dbh->dbc->db_handle->quote("%".$kw."%");
  my $sgl_kw = $dbh->dbc->db_handle->quote($kw."%");

  $kw = $dbh->dbc->db_handle->quote($kw);
  (my $t = $sql ) =~ s/'\[\[KEY\]\]'/$kw/g;
               $t =~ s/\[\[COMP\]\]/$comp/g;
               $t =~ s/\[\[FULLTEXTKEY\]\]/$full_kw/g; # Eagle extra regexp as we can have ' ' around our search term using full text search 

               $t =~ s/\[\[LIKEKEY_DBL\]\]/$dbl_kw/g;   # For punchlist search with double % - wc2
               $t =~ s/\[\[LIKEKEY_SGL\]\]/$sgl_kw/g;   # For genomealign search with single % - wc2, SINGLE search is much faster than double.
               $t =~ s/\[\[LIKE\]\]/like/g;             # For punchlist search with double % - wc2

  my( $res ) = $dbh->dbc->db_handle->selectrow_array( $t );
  # check which database we are connected to here!! 
  my @check = $dbh->dbc->db_handle->selectrow_array( "select database()" );
  return $res;
}

#----------------------#
# called by each search
# group with modified
# keyword.
#----------------------#
sub _fetch {
  my( $self, $db, $search_SQL, $comparator, $kw, $limit ) = @_;
  my $dbh = $self->database( $db );
  return unless $dbh;
  my $full_kw = $kw; 
  $full_kw =~ s/\%/\*/g; 

  #
  # ::ADD:: wc2 added options for non-specific searches.
  #
  my $dbl_kw = $dbh->dbc->db_handle->quote("%".$kw."%");
  my $sgl_kw = $dbh->dbc->db_handle->quote($kw."%");

  $kw = $dbh->dbc->db_handle->quote($kw);
  (my $t = $search_SQL ) =~ s/'\[\[KEY\]\]'/$kw/g;
  $t =~ s/\[\[COMP\]\]/$comparator/g;
  $t =~ s/\[\[FULLTEXTKEY\]\]/$full_kw/g;

  $t =~ s/\[\[LIKEKEY_DBL\]\]/$dbl_kw/g;   # For punchlist search with double % - wc2
  $t =~ s/\[\[LIKEKEY_SGL\]\]/$sgl_kw/g;   # For genomealign search with single % - wc2, SINGLE search ismuch faster than double.
  $t =~ s/\[\[LIKE\]\]/like/g;             # For punchlist search with double % - wc2
  my $res = $dbh->dbc->db_handle->selectall_arrayref( "$t limit $limit" );
  return $res;
}

#--------------------------#
# search_All call is used
# to search all desired PGP 
# tables.
#--------------------------#
sub search_ALL {
  my( $self, $species ) = @_;
  my $package_space = __PACKAGE__.'::';

  no strict 'refs';
  # This gets all the methods in this package ( begining with search and excluding search_all ) 
  my @methods = map { /(search_\w+)/ && $1 ne 'search_ALL' ? $1 : () } keys %$package_space;

   ## Filter by configured indices
  my $SD = EnsEMBL::Web::SpeciesDefs->new();
  
  # These are the methods for the current species that we want to try and run
  my @idxs = @{$SD->ENSEMBL_SEARCH_IDXS};

  # valid methods will contain the methods that we want to run and that are contained in this package
  my @valid_methods;

  if (scalar(@idxs) > 0) {
    foreach my $m (@methods) {
      (my $index = $m) =~ s/search_//;
      foreach my $i (@idxs) {
        if (lc($index) eq lc($i)) {
          push @valid_methods, $m;
          last;
        }
      }
    }
  }
  else {
    @valid_methods = @methods;
  }

  my @ALL = ();
  
  foreach my $method (@valid_methods) {

    #
    # ::ADD:: wc2 added to avoid the other methods, this was found b/c methods don't do 
    #          FULLTEXT and will fail in innoDB databases
    #  
    next if ($method !~ /SEQUENCE|MARKER|GENOMICALIGNMENT|PUNCHLIST|JIRA/);

    $self->{_results}      = [];
    if( $self->can($method) ) {
      $self->$method;
    }
  }
  return @ALL;
}

#----------------------#
# call _fetch and fetch 
# results and store in 
# appropriate result
# location.
#----------------------#
sub _fetch_results {
  my $self = shift;
  #my @terms = $self->terms();
  
  foreach my $query (@_) {
    my( $db, $subtype, $count_SQL, $search_SQL ) = @$query;
    
    # ::ADD:: wc2 added to include db criteria to grab alternate names (follow the call).
    #
    my @terms = $self->terms($db, $subtype);
    last if (@terms < 1);
    # ::

    foreach my $term (@terms ) {
      my $results = $self->_fetch( $db, $search_SQL, $term->[0], $term->[1], $self->{to_return} );
      push @{$self->{_results}}, @$results;
    }
  }
}

#----------------------------#
# Below are the individual
# search sql groups/statments
# for searching the database
#----------------------------#



sub search_GENOMICALIGNMENT {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results(
    [
      'core', 'DNA',
      "select count(distinct analysis_id, hit_name) from dna_align_feature where hit_name [[LIKE]] [[LIKEKEY_SGL]]",
      "select a.logic_name, f.hit_name, 'Dna', 'core',count(*)  from dna_align_feature as f, analysis as a where a.analysis_id = f.analysis_id and f.hit_name [[LIKE]] [[LIKEKEY_SGL]] group by a.logic_name, f.hit_name"
    ],
  );
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'idx'     => 'GenomicAlignment',
      'subtype' => "$_->[0] $_->[2] alignment feature",
      'ID'      => $_->[1],
      'URL'     => "$species_path/Location/Genome?ftype=$_->[2]AlignFeature;db=$_->[3];id=$_->[1]", # v58 format
      'desc'    => "This $_->[2] alignment feature hits the genome in $_->[4] place(s).",
      'species' => $species
    };
  }
# Eagle change, this should really match the value in the Species DEFs file, ie. GenomicAlignment not GenomicAlignments
# + the others are all singular so keep this consistent
  $self->{'results'}{'GenomicAlignment'} = [ $self->{_results}, $self->{_result_count} ];
}




sub search_SEQUENCE {
  my $self = shift;
  my $dbh = $self->database('core');
  return unless $dbh;  
  
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results( 

# 			 
# ::ADD:: wc2 these queries is used to work with primarily zfish/pig internal/external names.
#
   # normal			
    [ 'core', 'Sequence',
      "SELECT COUNT(*) FROM seq_region AS sr, coord_system AS cs, seq_region_attrib AS sra, attrib_type AS at WHERE 
               (cs.coord_system_id = sr.coord_system_id) AND 
               (sra.seq_region_id = sr.seq_region_id) AND 
               (at.attrib_type_id = sra.attrib_type_id) AND 
               at.code = 'accession' AND 
               sr.name [[COMP]] '[[KEY]]'",
      "SELECT sr.name, cs.name, sr.length, 'region', sra.value, sr.seq_region_id FROM seq_region AS sr, coord_system AS cs, seq_region_attrib AS sra, attrib_type AS at WHERE 
               (cs.coord_system_id = sr.coord_system_id) AND 
               (sra.seq_region_id = sr.seq_region_id) AND 
               (at.attrib_type_id = sra.attrib_type_id) AND 
               at.code = 'accession' AND 
               sr.name [[COMP]] '[[KEY]]'" ],

   # wgs sequences
    [ 'core', 'Sequence',
      "SELECT COUNT(*) FROM seq_region AS sr, coord_system AS cs, seq_region_attrib AS sra, attrib_type AS at WHERE 
               (cs.coord_system_id = sr.coord_system_id) AND 
               (sra.seq_region_id = sr.seq_region_id) AND 
               (at.attrib_type_id = sra.attrib_type_id) AND 
               at.code = 'sc' AND 
               sr.name [[COMP]] '[[KEY]]'",
      "SELECT sr.name, cs.name, sr.length, 'region', sra.value, sr.seq_region_id FROM seq_region AS sr, coord_system AS cs, seq_region_attrib AS sra, attrib_type AS at WHERE 
               (cs.coord_system_id = sr.coord_system_id) AND 
               (sra.seq_region_id = sr.seq_region_id) AND 
               (at.attrib_type_id = sra.attrib_type_id) AND 
               at.code = 'sc' AND 
               sr.name [[COMP]] '[[KEY]]'" ],

   # attributes
    [ 'core', 'Sequence',
      "SELECT COUNT(*) FROM seq_region AS sr, coord_system AS cs, seq_region_attrib AS sra, attrib_type AS at WHERE 
               (cs.coord_system_id = sr.coord_system_id) AND 
               (sra.seq_region_id = sr.seq_region_id) AND 
               (at.attrib_type_id = sra.attrib_type_id) AND 
               at.code = 'accession' AND 
               sra.value [[COMP]] '[[KEY]]'" ,
      "SELECT sr.name, cs.name, sr.length, 'region', sra.value, sr.seq_region_id FROM seq_region AS sr, coord_system AS cs, seq_region_attrib AS sra, attrib_type AS at where 
               (cs.coord_system_id = sr.coord_system_id) AND 
               (sra.seq_region_id = sr.seq_region_id) AND 
               (at.attrib_type_id = sra.attrib_type_id) AND 
               at.code = 'accession' AND 
               sra.value [[COMP]] '[[KEY]]'" ],
		 
# ::
#   [ 'core', 'Sequence',
#      "select count(*) from seq_region where name [[COMP]] '[[KEY]]'",
#      "select sr.name, cs.name, sr.length, 'region','', sr.seq_region_id from seq_region as sr, coord_system as cs where cs.coord_system_id = sr.coord_system_id and sr.name [[COMP]] '[[KEY]]'" ],

    [ 'core', 'Sequence',
      "select count(*) from seq_region where name [[LIKE]] [[LIKEKEY_SGL]]",
      "select sr.name, cs.name, sr.length, 'region', '', sr.seq_region_id from seq_region as sr, coord_system as cs where cs.coord_system_id = sr.coord_system_id and sr.name [[LIKE]] [[LIKEKEY_SGL]]" ],


  );


  my $sa = $dbh->get_SliceAdaptor(); 

  my %filterlist;
  my @filter_results;
  foreach ( @{$self->{_results}} ) {
    my $KEY =  $_->[2] < 1e6 ? 'contigview' : 'cytoview';
    $KEY = 'cytoview' if $self->species_defs->NO_SEQUENCE;
    # The new link format is usually 'r=chr_name:start-end'
    my $hitname = $_->[0]. "--" . $_->[1];

    #
    # ::ADD::  wc2 Added to display alternate names for the sequence
    #
    my $display_name = "";
    if ($self->{'data'}{'_search_species'}){
      $display_name .= "In: ".$self->{'data'}{'_search_species'}. "<br />";
    }
    if ($_->[4]){
      $display_name .= "also known as: ".$_->[4];
    }
    # ::

    my $slice = $sa->fetch_by_seq_region_id($_->[5]); 


    my $url_detailed = "$species_path/Location/View?r=" . $slice->seq_region_name . ":" . $slice->start . "-" . $slice->end;
    my $url_overview = [ 'Region overview', 'View region overview', "$species_path/Location/Overview?r=" . $slice->seq_region_name . ":" . $slice->start . "-" . $slice->end ];

    # Check for Dup regions such as PAR.
    my $isMultiHit_ref  =  &isMultiHit($slice); 
    if (@$isMultiHit_ref > 1) {	
   	my @results;
    	foreach my $reg (@$isMultiHit_ref){
		$display_name .= "MultiLoc: <a href=$species_path/Location/View?r=$reg>$reg</a><br />";
    	}
	$url_overview = undef;
        $url_detailed = undef;	

    }	

    $_ = {
      'URL'       => $url_detailed,   # v58 format
      'URL_extra' => $url_overview,
      'idx'       => 'Sequence',
      'subtype'   => ucfirst( $_->[1] ),
      'ID'        => $_->[0],
      'desc'      => $display_name ,
      'species'   => $species
    };

    push @filter_results, $_ if ($filterlist{$hitname} < 1);
    $filterlist{$hitname}++

  }
  $self->{'results'}{ 'Sequence' }  = [ \@filter_results, $self->{_result_count} ]
}

sub search_OLIGOPROBE {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results(
    [ 'funcgen', 'OligoProbe',
      "select count(distinct name) from probe_set where name [[COMP]] '[[KEY]]'",
       "select ps.name, group_concat(distinct a.name order by a.name separator ' '), vendor from probe_set ps, array a, array_chip ac, probe p
     where ps.name [[COMP]] '[[KEY]]' AND a.array_id = ac.array_id AND ac.array_chip_id = p.array_chip_id AND p.probe_set_id = ps.probe_set_id group by ps.name"],
  );
  foreach ( @{$self->{_results}} ) {
    $_ = {
#      'URL'       => "$species_path/Location/Genome?ftype=OligoProbe;id=$_->[0]",
      'URL'       => "$species_path/Location/Genome?ftype=ProbeFeature;fdb=funcgen;ptype=pset;id=$_->[0]", # v58 format
      'idx'       => 'OligoProbe',
      'subtype'   => $_->[2] . ' Probe set',
      'ID'        => $_->[0],
      'desc'      => 'Is a member of the following arrays: '.$_->[1],
      'species'   => $species
    };
  }
  $self->{'results'}{ 'OligoProbe' }  = [ $self->{_results}, $self->{_result_count} ];
}

sub search_QTL {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results(
  [ 'core', 'QTL',
"select count(*)
  from qtl_feature as qf, qtl as q
 where q.qtl_id = qf.qtl_id and q.trait [[COMP]] '[[KEY]]'",
"select q.trait, concat( sr.name,':', qf.seq_region_start, '-', qf.seq_region_end ),
       qf.seq_region_end - qf.seq_region_start
  from seq_region as sr, qtl_feature as qf, qtl as q
 where q.qtl_id = qf.qtl_id and qf.seq_region_id = sr.seq_region_id and q.trait [[COMP]] '[[KEY]]'" ],
  [ 'core', 'QTL',
"select count(*)
  from qtl_feature as qf, qtl_synonym as qs ,qtl as q
 where qs.qtl_id = q.qtl_id and q.qtl_id = qf.qtl_id and qs.source_primary_id [[COMP]] '[[KEY]]'",
"select q.trait, concat( sr.name,':', qf.seq_region_start, '-', qf.seq_region_end ),
       qf.seq_region_end - qf.seq_region_start
  from seq_region as sr, qtl_feature as qf, qtl_synonym as qs ,qtl as q
 where qs.qtl_id = q.qtl_id and q.qtl_id = qf.qtl_id and qf.seq_region_id = sr.seq_region_id and qs.source_primary_id [[COMP]] '[[KEY]]'" ]
  );

  foreach ( @{$self->{_results}} ) {
    $_ = {
#      'URL'       => "$species_path/cytoview?l=$_->[1]",
      'URL'       => "$species_path/Location/View?r=$_->[1]", # Eagle change, updated link to v58 ensembl format
      'idx'       => 'QTL',
      'subtype'   => 'QTL',
      'ID'        => $_->[0],
      'desc'      => '',
      'species'   => $species
    };
  }
  $self->{'results'}{'QTL'} = [ $self->{_results}, $self->{_result_count} ];
}


sub search_MARKER {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;
  
  $self->_fetch_results( 
    [ 'core', 'Marker',
      "select count(distinct name) from marker_synonym where name [[COMP]] '[[KEY]]'",
      "select distinct name from marker_synonym where name [[COMP]] '[[KEY]]'" ]
  );

  foreach ( @{$self->{_results}} ) {
    my $KEY =  $_->[2] < 1e6 ? 'contigview' : 'cytoview';
    $KEY = 'cytoview' if $self->species_defs->NO_SEQUENCE;
    $_ = {
#      'URL'       => "$species_path/markerview?marker=$_->[0]",
      'URL'       => "$species_path/Marker/Details?db=core;m=$_->[0]", # v58 format
#     'URL_extra' => [ 'C', 'View marker in ContigView', "$species_path/$KEY?marker=$_->[0]" ],
      'idx'       => 'Marker',
      'subtype'   => 'Marker',
      'ID'        => $_->[0],
      'desc'      => '',
      'species'   => $species
    };
  }
  $self->{'results'}{'Marker'} = [ $self->{_results}, $self->{_result_count} ];
}

sub search_GENE {
  my $self = shift;
  my $species = $self->species;
  my $species_path = $self->species_path;
  my @databases = ('core');
  push @databases, 'vega' if $self->species_defs->databases->{'DATABASE_VEGA'};
  push @databases, 'est' if $self->species_defs->databases->{'DATABASE_OTHERFEATURES'};
  foreach my $db (@databases) {
  $self->_fetch_results( 

      # Search Gene, Transcript, Translation stable ids.. 
    [ $db, 'Gene',
      "select count(*) from gene_stable_id WHERE stable_id [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, g.description, '$db', 'Gene', 'gene' FROM gene_stable_id as gsi, gene as g WHERE gsi.gene_id = g.gene_id and gsi.stable_id [[COMP]] '[[KEY]]'" ],
    [ $db, 'Gene',
      "select count(*) from transcript_stable_id WHERE stable_id [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, g.description, '$db', 'Transcript', 'transcript' FROM transcript_stable_id as gsi, transcript as g WHERE gsi.transcript_id = g.transcript_id and gsi.stable_id [[COMP]] '[[KEY]]'" ],
    [ $db, 'Gene',
      "select count(*) from translation_stable_id WHERE stable_id [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, x.description, '$db', 'Transcript', 'peptide' FROM translation_stable_id as gsi, translation as g, transcript as x WHERE g.transcript_id = x.transcript_id and gsi.translation_id = g.translation_id and gsi.stable_id [[COMP]] '[[KEY]]'" ],

      # search dbprimary_acc ( xref) of type 'Gene'
    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Gene' and ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, concat( display_label, ' - ', g.description ), '$db', 'Gene', 'gene' from gene_stable_id as gsi, gene as g, object_xref as ox, xref as x
        where gsi.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and gsi.gene_id = g.gene_id and
              ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'" ],
      # search display_label(xref) of type 'Gene' where NOT match dbprimary_acc !! - could these two statements be done better as one using 'OR' ?? !! 
      # Eagle change  - added 2 x distinct clauses to prevent returning duplicate stable ids caused by multiple xref entries for one gene
    [ $db, 'Gene',
      "select count( distinct(ensembl_id) ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Gene' and ox.xref_id = x.xref_id and
              x.display_label [[COMP]] '[[KEY]]' and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT distinct(gsi.stable_id), concat( display_label, ' - ', g.description ), '$db', 'Gene', 'gene' from gene_stable_id as gsi, gene as g, object_xref as ox, xref as x
        where gsi.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and gsi.gene_id = g.gene_id and
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ],

      # Eagle added this to search gene.description.  Could really do with an index on description field, but still works. 
      [ $db, 'Gene', 
      "SELECT count(distinct(g.gene_id)) from  gene as g, object_xref as ox, xref as x where g.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' 
           and ox.xref_id = x.xref_id and match(g.description) against('+[[FULLTEXTKEY]]' IN BOOLEAN MODE) and not(x.display_label [[COMP]] '[[KEY]]' ) and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT distinct(gsi.stable_id), concat( display_label, ' - ', g.description ), 'core', 'Gene', 'gene' from gene_stable_id as gsi, gene as g, object_xref as ox, xref as x
         where gsi.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and gsi.gene_id = g.gene_id and ox.xref_id = x.xref_id 
         and match(g.description) against('+[[FULLTEXTKEY]]' IN BOOLEAN MODE) and not(x.display_label [[COMP]] '[[KEY]]' ) and not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ],

      # Eagle added this to search external_synonym.  Could really do with an index on description field, but still works. 
      [ $db, 'Gene', 
      "SELECT count(distinct(g.gene_id)) from  gene as g, object_xref as ox, xref as x, external_synonym as es  where g.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' 
           and ox.xref_id = x.xref_id and es.xref_id = x.xref_id and es.synonym [[COMP]] '[[KEY]]' and not(match(g.description) against('+[[FULLTEXTKEY]]' IN BOOLEAN MODE)) and not(x.display_label [[COMP]] '[[KEY]]' ) and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT distinct(gsi.stable_id), concat( display_label, ' - ', g.description ), 'core', 'Gene', 'gene' from gene_stable_id as gsi, gene as g, object_xref as ox, xref as x, external_synonym as es
         where gsi.gene_id = ox.ensembl_id and ox.ensembl_object_type = 'Gene' and gsi.gene_id = g.gene_id and ox.xref_id = x.xref_id  and es.xref_id = x.xref_id
         and es.synonym [[COMP]] '[[KEY]]' and not( match(g.description) against('+[[FULLTEXTKEY]]' IN BOOLEAN MODE)) and not(x.display_label [[COMP]] '[[KEY]]' ) and not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ],


      # search dbprimary_acc ( xref) of type 'Transcript' - this could possibly be combined with Gene above if we return the object_xref.ensembl_object_type rather than the fixed 'Gene' or 'Transcript' 
      # to make things simpler and perhaps faster
    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Transcript' and ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, concat( display_label, ' - ', g.description ), '$db', 'Transcript', 'transcript' from transcript_stable_id as gsi, transcript as g, object_xref as ox, xref as x
        where gsi.transcript_id = ox.ensembl_id and ox.ensembl_object_type = 'Transcript' and gsi.transcript_id = g.transcript_id and
              ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'" ],
      # search display_label(xref) of type 'Transcript' where NOT match dbprimary_acc !! - could these two statements be done better as one using 'OR' ?? !! -- See also comment about combining with Genes above
    [ $db, 'Gene',
      "select count( distinct(ensembl_id) ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Transcript' and ox.xref_id = x.xref_id and
              x.display_label [[COMP]] '[[KEY]]' and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT distinct(gsi.stable_id), concat( display_label, ' - ', g.description ), '$db', 'Transcript', 'transcript' from transcript_stable_id as gsi, transcript as g, object_xref as ox, xref as x
        where gsi.transcript_id = ox.ensembl_id and ox.ensembl_object_type = 'Transcript' and gsi.transcript_id = g.transcript_id and
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ],


      ## Same again but for Translation - see above
    [ $db, 'Gene',
      "select count( * ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Translation' and ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'",
      "SELECT gsi.stable_id, concat( display_label ), '$db', 'Transcript', 'peptide' from translation_stable_id as gsi, object_xref as ox, xref as x
        where gsi.translation_id = ox.ensembl_id and ox.ensembl_object_type = 'Translation' and 
              ox.xref_id = x.xref_id and x.dbprimary_acc [[COMP]] '[[KEY]]'" ],
    [ $db, 'Gene',
      "select count( distinct(ensembl_id) ) from object_xref as ox, xref as x
        where ox.ensembl_object_type = 'Translation' and ox.xref_id = x.xref_id and
              x.display_label [[COMP]] '[[KEY]]' and not(x.dbprimary_acc [[COMP]] '[[KEY]]')",
      "SELECT distinct(gsi.stable_id), concat( display_label ), '$db', 'Transcript', 'peptide' from translation_stable_id as gsi, object_xref as ox, xref as x
        where gsi.translation_id = ox.ensembl_id and ox.ensembl_object_type = 'Translation' and 
              ox.xref_id = x.xref_id and x.display_label [[COMP]] '[[KEY]]' and
              not(x.dbprimary_acc [[COMP]] '[[KEY]]')" ]
  );
  }

  ## Remove duplicate hits
  my (%gene_id, @unique);

  foreach ( @{$self->{_results}} ) {

      next if $gene_id{$_->[0]};
      $gene_id{$_->[0]}++;

      # $_->[0] - Ensembl ID/name
      # $_->[1] - description 
      # $_->[2] - db name 
      # $_->[3] - Page type, eg Gene/Transcript 
      # $_->[4] - Page type, eg gene/transcript

#    my $KEY =  $_->[2] < 1e6 ? 'contigview' : 'cytoview';
      my $KEY = 'Location'; 
      $KEY = 'cytoview' if $self->species_defs->NO_SEQUENCE;

      my $page_name_long = $_->[4]; 
      (my $page_name_short = $page_name_long )  =~ s/^(\w).*/$1/; # first letter only for short format. 

      my $summary = 'Summary';  # Summary is used in URL for Gene and Transcript pages, but not for protein
      $summary = 'ProteinSummary' if $page_name_short eq 'p'; 

      push @unique, {
        'URL'       => "$species_path/$_->[3]/$summary?$page_name_short=$_->[0];db=$_->[2]",
        'URL_extra' => [ 'Region in detail', 'View marker in LocationView', "$species_path/$KEY/View?$page_name_long=$_->[0];db=$_->[2]" ],
        'idx'       => 'Gene',
        'subtype'   => ucfirst($_->[4]),
        'ID'        => $_->[0],
        'desc'      => $_->[1],
        'species'   => $species
      };

  }
  $self->{'results'}{'Gene'} = [ \@unique, $self->{_result_count} ];
}



###############
# PGP Specific #
################


#
# ::ADD:: wc2, new method to return int/ext names of a search term.
#
sub get_all_names {
    my ($self, $kw, $db) = @_;

    my $dbh = $self->database($db, $self->{'data'}{'_search_species'} ||  $self->species);
    next if (!$dbh);

    #filter the search term.
    my $return_count = $dbh->dbc->db_handle->selectrow_array("select count(*) from seq_region_attrib as sra inner join seq_region as sr using (seq_region_id) where sra.value like '%$kw%'");

    if ($return_count > 4)  { return "Not Specific Enough";} # search term is too broad, return an arbitrary term, theres no point searching anymore
    if ($return_count == 0) { return $kw;}                   # if count returns 0, most likely its not a clone name, could be cdna etc.#
    
    my $seq_region_name = $dbh->dbc->db_handle->selectrow_array("select sr.name from seq_region_attrib as sra inner join seq_region as sr using (seq_region_id) where sra.value like '%$kw%' limit 1");

    if ($seq_region_name eq $kw){
	$seq_region_name = $dbh->dbc->db_handle->selectrow_array("select sra.value from seq_region_attrib as sra inner join seq_region as sr using (seq_region_id) inner join attrib_type as at using (attrib_type_id) where at.code = 'int_name' and sr.name like '%$kw%' limit 1");

    }

    return ($seq_region_name, $kw);
}


#
#  ::ADD:: wc2, search punchlist section

sub search_PUNCHLIST {
  my $self = shift;
  $self->_fetch_results(
    [
      'core', 'Punch',
      "select count(*) from punch where comment [[LIKE]] [[LIKEKEY_DBL]]",
      "select p.name, pt.name, pt.code, p.comment, p.punched,'Punch', 'core' from punch as p inner join punch_type as pt using (punch_type_id) where p.comment [[LIKE]] [[LIKEKEY_DBL]]"
    ]

  );
  my %filterlist;
  my @filter_results;
  foreach ( @{$self->{_results}} ) {

      my $key = $_->[2]."--".$_->[3];    
      my $id = "<br>Name: $_->[0]<br>Comment:$_->[3]";

    $_ = {
      'idx'     => 'Punchlist',
      'subtype' => "$_->[1]  ",
      'ID'      => $id,
      'URL'     => "/@{[$self->species]}/Punchlist/Overview?punchtype=$_->[2]",
      'desc'    => "Item punched? ".uc($_->[4]).".",
      'species' => $self->species
    };

      push @filter_results, $_ if ($filterlist{$key} < 1);
      $filterlist{$key}++


  }
  $self->{'results'}{'Punchlist'} = [ \@filter_results, $self->{_result_count} ];
}

# ::



#
#  ::ADD:: wc2, search for JIRA ID 
#
sub search_JIRA {

  my $self = shift;
  $self->_fetch_results(
    [
      'core', 'MiscFeature',
      "select count(*) from misc_attrib inner join attrib_type using (attrib_type_id) where value = '[[KEY]]' and code = 'jira_id'",
      "select value, sr.name, mf.seq_region_start, mf.seq_region_end, mf.misc_feature_id from misc_attrib 
              inner join attrib_type as at using (attrib_type_id) 
              inner join misc_feature as mf using (misc_feature_id) 
              inner join seq_region as sr using (seq_region_id)
	      inner join misc_feature_misc_set as mfms using (misc_feature_id)
	      inner join misc_set as ms using (misc_set_id) 
              where value = '[[KEY]]' and at.code = 'jira_id' and ms.code ='jira_entry'", 
    ],

  );
  foreach ( @{$self->{_results}} ) {
    $_ = {
      'idx'     => 'Jira',
      'subtype' => "jira ",
      'ID'      => $_->[0],
#      'URL'     => "/@{[$self->species]}/Location/View?r=$_->[1]:$_->[2]-$_->[3]",
      'URL'     => "/@{[$self->species]}/Jira/JiraSummary?id=$_->[4]",
      'species' => $self->species
    };
    
  }
  $self->{'results'}{'Jira'} = [ $self->{_results}, $self->{_result_count} ];
}


#
#
#  This was added to identify if the slice is on multiple toplevels, indicating for example the PAR.  This could not be distinguished both PGPviewer and Ensembl browser.
#  This should be ideally be sorted with assembly exceptions but when I search in ensembl it doesn't work as well.
#  wc2

sub isMultiHit {

  my $slice = shift;

  my %regions;	
  my @reg_toreturn;
  my @proj = @{$slice->project('toplevel')};
	
  foreach my $pj ( sort{$a->to_Slice->start <=> $b->to_Slice->start} @proj){
     my $name = $pj->to_Slice->seq_region_name;

     if ($regions{$name}){
	$regions{$name}{end} = $pj->to_Slice->end;
     }
     else {	
        $regions{$name} = { start => $pj->to_Slice->start,
                            end   => $pj->to_Slice->end,
        };	
     }

  }

  foreach my $chr (sort {$a cmp $b} keys %regions){

     push @reg_toreturn, $chr.":". $regions{$chr}{start}."-".$regions{$chr}{end};
  }

  return \@reg_toreturn;
}	





## Result hash contains the following fields...
## 
## { 'URL' => ?, 'type' => ?, 'ID' => ?, 'desc' => ?, 'idx' => ?, 'species' => ?, 'subtype' =>, 'URL_extra' => [] }  
1;
