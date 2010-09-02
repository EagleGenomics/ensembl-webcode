package EnsEMBL::Web::ConfigPacker;

use strict;
use warnings;
no warnings qw(uninitialized);

use Bio::EnsEMBL::ExternalData::DAS::SourceParser;
use Data::Dumper;

use base qw(EnsEMBL::Web::ConfigPacker_base);

sub munge {
  my ($self, $func) = @_;
  
  $func .= '_multi' if $self->species eq 'MULTI';
  
  my $munge  = "munge_$func";
  my $modify = "modify_$func";
  
  $self->$munge();
  $self->$modify();
}

sub munge_databases {
  my $self   = shift;
  my @tables = qw(core cdna vega otherfeatures);
  
  $self->_summarise_core_tables($_, 'DATABASE_' . uc $_) for @tables;
  $self->_summarise_xref_types('DATABASE_' . uc $_) for @tables;
  $self->_summarise_variation_db('variation', 'DATABASE_VARIATION');
  $self->_summarise_funcgen_db('funcgen', 'DATABASE_FUNCGEN');
}

# creates das.packed
sub munge_das {
  my $self = shift;
  $self->_summarise_dasregistry;
}

sub munge_databases_multi {
  my $self = shift;
  $self->_summarise_website_db;
  $self->_summarise_compara_db('compara', 'DATABASE_COMPARA');
  $self->_summarise_compara_db('compara_pan_ensembl', 'DATABASE_COMPARA_PAN_ENSEMBL');
  $self->_summarise_ancestral_db('core', 'DATABASE_CORE');
  $self->_summarise_go_db;
}

sub munge_config_tree {
  my $self = shift;
  
  # munge the results obtained from the database queries of the website and the meta tables
  $self->_munge_meta;
  $self->_munge_variation;
  $self->_munge_website;

  # parse the BLAST configuration
  $self->_configure_blast;
}

sub munge_config_tree_multi {
  my $self = shift;
  $self->_munge_website_multi;
}

# Implemented in plugins
sub modify_databases         {}
sub modify_databases_multi   {}
sub modify_das               {}
sub modify_config_tree       {}
sub modify_config_tree_multi {}

sub _summarise_generic {
  my( $self, $db_name, $dbh ) = @_;
  my $t_aref = $dbh->selectall_arrayref( 'show table status' );
#---------- Table existance and row counts
  foreach my $row ( @$t_aref ) {
    $self->db_details($db_name)->{'tables'}{$row->[0]}{'rows'} = $row->[4];
  }
#---------- Meta coord system table...
  if( $self->_table_exists( $db_name, 'meta_coord' )) {
    $t_aref = $dbh->selectall_arrayref(
      'select table_name,max_length
         from meta_coord'
    );
    foreach my $row ( @$t_aref ) {
      $self->db_details($db_name)->{'tables'}{$row->[0]}{'coord_systems'}{$row->[1]}=$row->[2];
    }
  }
#---------- Meta table (everything except patches)
## Needs tweaking to work with new ensembl_ontology_xx db, which has no species_id in meta table
  if( $self->_table_exists( $db_name, 'meta' ) ) {
    my $hash = {};

    $t_aref  = $dbh->selectall_arrayref(
      'select meta_key,meta_value,meta_id, species_id
         from meta
        where meta_key != "patch"
        order by meta_key, meta_id'
    );

    foreach my $r( @$t_aref) {
      push @{ $hash->{$r->[3]+0}{$r->[0]}}, $r->[1];
    }
    
    $self->db_details($db_name)->{'meta_info'} = $hash;
  }
}

sub _summarise_core_tables {
  my $self   = shift;
  my $db_key = shift;
  my $db_name = shift; 
  my $dbh    = $self->db_connect( $db_name ); 
  return unless $dbh; 
  
  push @{ $self->db_tree->{'core_like_databases'} }, $db_name;

  $self->_summarise_generic( $db_name, $dbh );
##
## Grab each of the analyses - will use these in a moment...
##
  my $t_aref = $dbh->selectall_arrayref(
    'select a.analysis_id, lower(a.logic_name), a.created,
            ad.display_label, ad.description,
            ad.displayable, ad.web_data
       from analysis a left join analysis_description as ad on a.analysis_id=ad.analysis_id'
  );
  my $analysis = {};
  foreach my $a_aref (@$t_aref) { 
    ## Strip out "crap" at front and end! probably some q(')s...
    ( my $A = $a_aref->[6] ) =~ s/^[^{]+//;
    $A =~ s/[^}]+$//;
    my $T = eval($A);
    if (ref($T) ne 'HASH') {
      if ($A) {
        warn "Deleting web_data for $db_key:".$a_aref->[1].", check for syntax error";
      }
      $T = {};
    }
    $analysis->{ $a_aref->[0] } = {
      'logic_name'  => $a_aref->[1],
      'name'        => $a_aref->[3],
      'description' => $a_aref->[4],
      'displayable' => $a_aref->[5],
      'web_data'    => $T
    };
  }
  ## Set last repeat mask date whilst we're at it, as needed by BLAST configuration, below
  my $r_aref = $dbh->selectall_arrayref( 
      'select max(date_format( created, "%Y%m%d"))
      from analysis, meta
      where logic_name = meta_value and meta_key = "repeat.analysis"' 
  );
  my $date;
  foreach my $a_aref (@$r_aref){
    $date = $a_aref->[0];
  } 
  if ($date) { $self->db_tree->{'REPEAT_MASK_DATE'} = $date; } 

  #get website version the db was first released on - needed for Vega BLAST auto configuration
  (my $initial_release) = $dbh->selectrow_array(qq(SELECT meta_value FROM meta WHERE meta_key = 'initial_release.version'));
  if ($initial_release) { $self->db_tree->{'DB_RELEASE_VERSION'} = $initial_release; }

## 
## Let us get analysis information about each feature type...
##
  foreach my $table ( qw(
        dna_align_feature protein_align_feature simple_feature
        protein_feature marker_feature qtl_feature
        repeat_feature ditag_feature 
        transcript gene prediction_transcript unmapped_object
  )) { 
    my $res_aref = $dbh->selectall_arrayref(
      "select analysis_id,count(*) from $table group by analysis_id"
    );
    foreach my $T ( @$res_aref ) {
      my $a_ref = $analysis->{$T->[0]}
        || ( warn("Missing analysis entry $table - $T->[0]\n") && next );
      my $value = {
        'name'  => $a_ref->{'name'},
        'desc'  => $a_ref->{'description'},
        'disp'  => $a_ref->{'displayable'},
        'web'   => $a_ref->{'web_data'},
        'count' => $T->[1]
      };
      $self->db_details($db_name)->{'tables'}{$table}{'analyses'}{$a_ref->{'logic_name'}} = $value;
    }
  }

#---------- Additional queries - by type...

#
# * Check to see if we have any interpro? - not sure why may drop...
#

#
# * Repeats
#
  $t_aref = $dbh->selectall_arrayref(
    'select rf.analysis_id,rc.repeat_type, count(*)
       from repeat_consensus as rc, repeat_feature as rf
      where rc.repeat_consensus_id = rf.repeat_consensus_id
      group by analysis_id, repeat_type'
  );
  foreach my $row (@$t_aref) {
    my $a_ref = $analysis->{$row->[0]};
    $self->db_details($db_name)->{'tables'}{'repeat_feature'}{'analyses'}{$a_ref->{'logic_name'}}{'types'}{$row->[1]} = $row->[2];
  }
#
# * Misc-sets
#
  $t_aref = $dbh->selectall_arrayref(
    'select ms.code, ms.name, ms.description, count(*) as N, ms.max_length
       from misc_set as ms, misc_feature_misc_set as mfms
      where mfms.misc_set_id = ms.misc_set_id
      group by ms.misc_set_id'
  );
  $self->db_details($db_name)->{'tables'}{'misc_feature'}{'sets'} = { map {
    ( $_->[0] => { 'name' => $_->[1], 'desc' => $_->[2], 'count' => $_->[3], 'max_length' => $_->[4] })
  } @$t_aref };

#
# * External-db
#
  my $sth = $dbh->prepare(qq(select * from external_db));
  $sth->execute;
  my $hashref;
  while ( my $t =  $sth->fetchrow_hashref) {
    $hashref->{$t->{'external_db_id'}} = $t;
  }
  $self->db_details($db_name)->{'tables'}{'external_db'}{'entries'} = $hashref;

#---------- Now for the core only ones.......

  if( $db_key eq 'core' ) {
#
# * Co-ordinate systems..
#

    my $aref =  $dbh->selectall_arrayref(
      'select sr.name, sr.length 
         from seq_region as sr, coord_system as cs 
        where cs.name in( "chromosome", "group" )
              and cs.attrib like "%default_version%"
              and cs.coord_system_id = sr.coord_system_id' 
    );
    $self->db_tree->{'MAX_CHR_NAME'  } = undef;
    $self->db_tree->{'MAX_CHR_LENGTH'} = undef;
    my $max_length = 0;
    my $max_name;
    foreach my $row (@$aref) {
      $self->db_tree->{'ALL_CHROMOSOMES'}{$row->[0]} = $row->[1];
      if( $row->[1] > $max_length ) {
        $max_name = $row->[0];
        $max_length = $row->[1];
      }
    }
    $self->db_tree->{'MAX_CHR_NAME'  } = $max_name;
    $self->db_tree->{'MAX_CHR_LENGTH'} = $max_length;
  }

#---------------
#
# * Assemblies...
# This is a bit ugly, because there's no easy way to sort the assemblies via MySQL
  $t_aref = $dbh->selectall_arrayref(
    'select version, attrib from coord_system where version is not null' 
  );
  my (%default, %not_default);
  foreach my $row (@$t_aref) {
    my $version = $row->[0];
    my $attrib = $row->[1];
    if ($attrib =~ /default_version/) {
      $default{$version}++;
    }
    else {
      $not_default{$version}++;
    }
  }
  my @assemblies = keys %default;
  push @assemblies, sort keys %not_default;
  $self->db_tree->{'CURRENT_ASSEMBLIES'} = join(',', @assemblies);

#----------
  $dbh->disconnect();
}

sub _summarise_xref_types {
  my $self   = shift;
  my $db_name = shift; 
  my $dbh    = $self->db_connect( $db_name ); 
warn "xref types:--------------------------------------------";
use Data::Dumper;
  
  return unless $dbh; 
  my @xref_types;
  my %xrefs_types_hash;


  if($self->db_tree->{'XREF_TYPES'}){
  warn "yes!";
    @xref_types=  split(/,/, $self->db_tree->{'XREF_TYPES'});
	foreach(@xref_types){
	  my @type_priority=  split(/=/, $_);
	  $xrefs_types_hash{$type_priority[0]}=$type_priority[1];
	}
  }else{
  warn "no!";
  }

  my $aref =  $dbh->selectall_arrayref(qq(
  SELECT distinct(edb.db_display_name), max(priority) as m
  FROM object_xref ox join xref x on ox.xref_id=x.xref_id  join external_db edb on x.external_db_id = edb.external_db_id
    where edb.type IN ('MISC', 'LIT')
    and (ox.ensembl_object_type ='Transcript' or ox.ensembl_object_type ='Translation' ) group by edb.db_display_name order by m desc) );
  foreach my $row (@$aref) {
    if($xrefs_types_hash{$row->[0]} ){
      $xrefs_types_hash{$row->[0]}= ($row->[1]>$xrefs_types_hash{$row->[0]})?$row->[1]:$xrefs_types_hash{$row->[0]};
	}else{
      $xrefs_types_hash{$row->[0]}=$row->[1];
	}
  }
  my $xref_types_string="";
  for my $key ( keys %xrefs_types_hash ) {
      my $value = $xrefs_types_hash{$key};
	  $xref_types_string.=$key."=".$value.",";
  }
  $self->db_tree->{'XREF_TYPES'} = $xref_types_string;
  $dbh->disconnect();
}

sub _summarise_variation_db {
  my($self,$code,$db_name) = @_;
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  push @{ $self->db_tree->{'variation_like_databases'} }, $db_name;
  $self->_summarise_generic( $db_name, $dbh );
  my $t_aref = $dbh->selectall_arrayref( 'select source_id,name,description from source' );
#---------- Add in information about the sources from the source table
  my $temp = {map {$_->[0],[$_->[1],0]} @$t_aref};
  my $temp_description = {map {$_->[1],$_->[2]} @$t_aref};
  foreach my $t (qw(variation variation_synonym)) {
    my $t_aref = $dbh->selectall_arrayref( "select source_id,count(*) from $t group by source_id" );
    foreach (@$t_aref) {
      $temp->{$_->[0]}[1] += $_->[1];
    }
  }
  $self->db_details($db_name)->{'tables'}{'source'}{'counts'} = { map {@$_} values %$temp};
  $self->db_details($db_name)->{'tables'}{'source'}{'descriptions'} = \%$temp_description;
#---------- Store dbSNP version 
 my $s_aref = $dbh->selectall_arrayref( 'select version from source where name = "dbSNP"' );
 foreach (@$s_aref){
    my ($version) = @$_;
    $self->db_tree->{'databases'}{'DATABASE_VARIATION'}{'dbSNP_VERSION'} = $version;   
  }
#---------- Add in information about the display type from the sample table
   my $d_aref = $dbh->selectall_arrayref( "select name, display from sample where display not like 'UNDISPLAYABLE'" );
   my (@default, $reference, @display, @ld);
   foreach (@$d_aref){
     my  ($name, $type) = @$_;  
     if ($type eq 'REFERENCE') { $reference = $name;}
     elsif ($type eq 'DISPLAYABLE'){ push(@display, $name); }
     elsif ($type eq 'DEFAULT'){ push (@default, $name); }
     elsif ($type eq 'LD'){ push (@ld, $name); } 
   }
   $self->db_details($db_name)->{'tables'}{'individual.reference_strain'} = $reference;
   $self->db_tree->{'databases'}{'DATABASE_VARIATION'}{'REFERENCE_STRAIN'} = $reference; 
   $self->db_details($db_name)->{'meta_info'}{'individual.default_strain'} = \@default;
   $self->db_tree->{'databases'}{'DATABASE_VARIATION'}{'DEFAULT_STRAINS'} = \@default;  
   $self->db_details($db_name)->{'meta_info'}{'individual.display_strain'} = \@display;
   $self->db_tree->{'databases'}{'DATABASE_VARIATION'}{'DISPLAY_STRAINS'} = \@display; 
   $self->db_tree->{'databases'}{'DATABASE_VARIATION'}{'LD_POPULATIONS'} = \@ld;
#---------- Add in strains contained in read_coverage_collection table
  if ($self->db_details($db_name)->{'tables'}{'read_coverage_collection'}){
    my $r_aref = $dbh->selectall_arrayref(
        'select distinct s.name, s.sample_id
        from sample s, read_coverage_collection r
        where s.sample_id = r.sample_id' 
     );
     my @strains;
     foreach my $a_aref (@$r_aref){
       my $strain = $a_aref->[0] . '_' . $a_aref->[1];
       push (@strains, $strain);
     }
     if (@strains) { $self->db_details($db_name)->{'tables'}{'read_coverage_collection_strains'} = join(',', @strains); } 
  }

#--------- Add in structural variation information
  my $v_aref = $dbh->selectall_arrayref( "select s.name, count(*), s.description from structural_variation sv, source s where sv.source_id=s.source_id  group by sv.source_id");
  my %structural_variations;
  my %sv_descriptions;
  foreach (@$v_aref) {
   $structural_variations{$_->[0]} = $_->[1];    
   $sv_descriptions{$_->[0]} = $_->[2];
  }
  $self->db_details($db_name)->{'tables'}{'structural_variation'}{'counts'} = \%structural_variations;
  $self->db_details($db_name)->{'tables'}{'structural_variation'}{'descriptions'} = \%sv_descriptions;

#--------- Add in Variation set information
  # First get all toplevel sets
  my (%super_sets, %sub_sets);

  my $st_aref = $dbh->selectall_arrayref( 
    'select  vs.variation_set_id, vs.name, vs.description 
        from variation_set vs 
        where not exists (
          select * 
            from variation_set_structure vss 
           where vss.variation_set_sub = vs.variation_set_id
        )'
    );
    # then get subsets foreach toplevel set
    foreach( @$st_aref){
      $super_sets{$_->[0]} = {};
      $super_sets{$_->[0]}{'name'} = $_->[1];
      $super_sets{$_->[0]}{'description'} = $_->[2];
      $super_sets{$_->[0]}{'subsets'} = [];
      my $set_id = $_->[0];

      my $ss_aref = $dbh->selectall_arrayref(
        "select vs.variation_set_id, vs.name, vs.description 
           from variation_set vs, variation_set_structure vss 
          where vss.variation_set_sub = vs.variation_set_id 
            and vss.variation_set_super = $set_id"  
      );

      foreach my $sub_set (@$ss_aref){
        push @{$super_sets{$_->[0]}{'subsets'}}, $sub_set->[0];
        $sub_sets{$sub_set->[0]} = {};
        $sub_sets{$sub_set->[0]}{'name'} = $sub_set->[1];
        $sub_sets{$sub_set->[0]}{'description'} = $sub_set->[2]; 
      } 
    }

  $self->db_details($db_name)->{'tables'}{'variation_set'}{'supersets'} = \%super_sets;  
  $self->db_details($db_name)->{'tables'}{'variation_set'}{'subsets'} = \%sub_sets;

#--------- Add in somatic mutation information
  my %somatic_mutations;
  my $sm_aref =  $dbh->selectall_arrayref(  
    'select distinct(p.description), va.phenotype_id, s.name 
       from phenotype p, variation_annotation va, source s 
      where p.phenotype_id=va.phenotype_id and va.source_id=s.source_id and s.somatic =1'
  );

  foreach (@$sm_aref){ 
    $somatic_mutations{$_->[2]}->{$_->[0]} = $_->[1] ;
  } 
  
  $self->db_tree->{'databases'}{'DATABASE_VARIATION'}{'SOMATIC_MUTATIONS'} = \%somatic_mutations;
  $dbh->disconnect();
}

sub _summarise_funcgen_db {
  my($self, $db_key, $db_name) = @_;
  my $dbh  = $self->db_connect( $db_name );
  return unless $dbh;
  push @{ $self->db_tree->{'funcgen_like_databases'} }, $db_name;
  $self->_summarise_generic( $db_name, $dbh );
##
## Grab each of the analyses - will use these in a moment...
##
  my $t_aref = $dbh->selectall_arrayref(
    'select a.analysis_id, a.logic_name, a.created,
            ad.display_label, ad.description,
            ad.displayable, ad.web_data
       from analysis a left join analysis_description as ad on a.analysis_id=ad.analysis_id'
  );
  my $analysis = {};
  foreach my $a_aref (@$t_aref) {
## Strip out "crap" at front and end! probably some q(')s...
    ( my $A = $a_aref->[6] ) =~ s/^[^{]+//;
    $A =~ s/[^}]+$//;
    my $T = eval($A);

    $T = {} unless ref($T) eq 'HASH';
    $analysis->{ $a_aref->[0] } = {
      'logic_name'  => $a_aref->[1],
      'name'        => $a_aref->[3],
      'description' => $a_aref->[4],
      'displayable' => $a_aref->[5],
      'web_data'    => $T
    };
  }

##
## Let us get analysis information about each feature type...
##
  foreach my $table ( qw(
   probe_feature feature_set result_set 
  )) {
    my $res_aref = $dbh->selectall_arrayref(
      "select analysis_id,count(*) from $table group by analysis_id"
    );
    foreach my $T ( @$res_aref ) {
      my $a_ref = $analysis->{$T->[0]};
        #|| ( warn("Missing analysis entry $table - $T->[0]\n") && next );
      my $value = {
        'name'  => $a_ref->{'name'},
        'desc'  => $a_ref->{'description'},
        'disp'  => $a_ref->{'displayable'},
        'web'   => $a_ref->{'web_data'},
        'count' => $T->[1]
      }; 
      $self->db_details($db_name)->{'tables'}{$table}{'analyses'}{$a_ref->{'logic_name'}} = $value;
    }
  }

###
### Store the external feature sets available for each species
###
  my @feature_sets;
  my $f_aref = $dbh->selectall_arrayref(
    "select name
      from feature_set
      where type = 'external'"
  );
  foreach my $F ( @$f_aref ){ push (@feature_sets, $F->[0]); }  
  $self->db_tree->{'databases'}{'DATABASE_FUNCGEN'}{'FEATURE_SETS'} = \@feature_sets;


#---------- Additional queries - by type...

#
# * Oligos
#
#  $t_aref = $dbh->selectall_arrayref(
#    'select a.vendor, a.name,count(*)
#       from array as a, array_chip as c straight_join probe as p on
#            c.array_chip_id=p.array_chip_id straight_join probe_feature f on
#            p.probe_id=f.probe_id where a.name = c.name
#      group by a.name'
#  );

  $t_aref = $dbh->selectall_arrayref(
    'select a.vendor, a.name, a.array_id  
       from array a, array_chip c, status s, status_name sn where  sn.name="DISPLAYABLE" 
       and sn.status_name_id=s.status_name_id and s.table_name="array" and s.table_id=a.array_id 
       and a.array_id=c.array_id
    '       
  );
  my $sth = $dbh->prepare(
    'select pf.probe_feature_id
       from array_chip ac, probe p, probe_feature pf, seq_region sr, coord_system cs
       where ac.array_chip_id=p.array_chip_id and p.probe_id=pf.probe_id  
       and pf.seq_region_id=sr.seq_region_id and sr.coord_system_id=cs.coord_system_id 
       and cs.is_current=1 and ac.array_id = ?
       limit 1 
    '
  );
  foreach my $row (@$t_aref) {
    my $array_name = $row->[0] .':'. $row->[1];
    $sth->bind_param(1, $row->[2]);
    $sth->execute;
    my $count = $sth->fetchrow_array();# warn $array_name ." ". $count;
    if( exists $self->db_details($db_name)->{'tables'}{'oligo_feature'}{'arrays'}{$array_name} ) {
      warn "FOUND";
    }
    $self->db_details($db_name)->{'tables'}{'oligo_feature'}{'arrays'}{$array_name} = $count ? 1 : 0;
  }
  $sth->finish;
#
# * functional genomics tracks
#

  $f_aref = $dbh->selectall_arrayref(
    'select ft.name, ct.name 
       from supporting_set ss, data_set ds, feature_set fs, feature_type ft, cell_type ct  
       where ds.data_set_id=ss.data_set_id and ds.name="RegulatoryFeatures" 
       and fs.feature_set_id = ss.supporting_set_id and fs.feature_type_id=ft.feature_type_id 
       and fs.cell_type_id=ct.cell_type_id 
       order by ft.name;
    '
  );   
  foreach my $row (@$f_aref) {
    my $feature_type_key =  $row->[0] .':'. $row->[1];
    $self->db_details($db_name)->{'tables'}{'feature_type'}{'analyses'}{$feature_type_key} = 2;   
  }

  my $c_aref =  $dbh->selectall_arrayref(
    'select  ct.name, ct.cell_type_id 
       from  cell_type ct, feature_set fs  
       where  fs.type="regulatory" and ct.cell_type_id=fs.cell_type_id 
    group by  ct.name order by ct.name'
  );
  foreach my $row (@$c_aref) {
    my $cell_type_key =  $row->[0] .':'. $row->[1];
    $self->db_details($db_name)->{'tables'}{'cell_type'}{'ids'}{$cell_type_key} = 2;
  }

  my $ft_aref =  $dbh->selectall_arrayref(
    'select ft.name, ft.feature_type_id from feature_type ft, feature_set fs, data_set ds, feature_set fs1, supporting_set ss 
      where fs1.type="regulatory" and fs1.feature_set_id=ds.feature_set_id and ds.data_set_id=ss.data_set_id 
        and ss.type="feature" and ss.supporting_set_id=fs.feature_set_id and fs.feature_type_id=ft.feature_type_id 
   group by ft.name order by ft.name'
  );
  foreach my $row (@$ft_aref) {
    my $feature_type_key =  $row->[0] .':'. $row->[1];
    $self->db_details($db_name)->{'tables'}{'feature_type'}{'ids'}{$feature_type_key} = 2;
  }

  my $mt_aref = $dbh->selectall_arrayref(
    'select meta_key, meta_value 
       from meta 
      where meta_key like "%regbuild%" and 
            meta_key like "%ids"'
  );
  foreach my $row (@$mt_aref ){
    my ($meta_key, $meta_value) = @$row;
    $meta_key =~s/regbuild\.//;
    my @key_info = split(/\./,$meta_key); 
    my %data;  
    my @ids = split(/\,/,$meta_value);
    my $sth = $dbh->prepare(
          'select feature_type_id
             from feature_set
            where feature_set_id = ?'
    );
    foreach (@ids){
      if($key_info[1] =~/focus/){
        my $feature_set_id = $_;
        $sth->bind_param(1, $feature_set_id);
        $sth->execute;
        my ($feature_type_id)= $sth->fetchrow_array;
        $data{$feature_type_id} = $_;
      }
      else {
        $data{$_} = 1;
      }
      $sth->finish;
    } 
    $self->db_details($db_name)->{'tables'}{'meta'}{$key_info[1]}{$key_info[0]} = \%data;
  }

  $dbh->disconnect();
}

#========================================================================#
# The following functions munge the multi-species databases              #
#========================================================================#

sub _summarise_website_db {
  my $self    = shift;
  my $db_name = 'DATABASE_WEBSITE';
  my $dbh     = $self->db_connect( $db_name );

  ## Get component-based help
  my $t_aref = $dbh->selectall_arrayref(
    'select hl.page_url, hl.help_record_id from help_record as hr, help_link as hl where hr.help_record_id = hl.help_record_id and status = "live"'
  );
  foreach my $row (@$t_aref) {
    $self->db_tree->{'ENSEMBL_HELP'}{$row->[0]} = $row->[1];
  }

  ## Get glossary
  $t_aref = $dbh->selectall_arrayref(
    'select data from help_record where type = "glossary" and status = "live"'
  );
  foreach my $row (@$t_aref) {
    my $entry = eval($row->[0]);
    $self->db_tree->{'ENSEMBL_GLOSSARY'}{$entry->{'word'}} = $entry->{'meaning'}; 
  }

  $t_aref = $dbh->selectall_arrayref(
    'select s.name, r.release_id,rs.assembly_code
       from species as s, ens_release as r, release_species as rs
      where s.species_id =rs.species_id and r.release_id =rs.release_id and rs.assembly_code !=""'
  );
  foreach my $row ( @$t_aref ) {
    $self->db_tree->{'ASSEMBLIES'}->{$row->[0]}{$row->[1]}=$row->[2];
  }
  $t_aref = $dbh->selectall_arrayref(
    'select s.name, r.release_id, r.archive
       from ens_release as r, species as s, release_species as rs
      where s.species_id = rs.species_id and r.release_id = rs.release_id and r.online = "Y"'
  );
  foreach my $row ( @$t_aref ) {
    $self->db_tree->{'ENSEMBL_ARCHIVES'}->{$row->[0]}{$row->[1]}=$row->[2];
  }

  $dbh->disconnect();
}

sub _summarise_compara_db {
  my ($self, $code, $db_name) = @_;
  
  my $dbh = $self->db_connect($db_name);
  return unless $dbh;
  
  push @{$self->db_tree->{'compara_like_databases'}}, $db_name;

  $self->_summarise_generic($db_name, $dbh);
  
  # Lets first look at all the multiple alignments
  ## We've done the DB hash...So lets get on with the multiple alignment hash;
  my $res_aref = $dbh->selectall_arrayref('
    select ml.class, ml.type, gd.name, mlss.name, mlss.method_link_species_set_id, ss.species_set_id
      from method_link ml, 
        method_link_species_set mlss, 
        genome_db gd, species_set ss 
      where mlss.method_link_id = ml.method_link_id and
        mlss.species_set_id = ss.species_set_id and 
        ss.genome_db_id = gd.genome_db_id and
        (ml.class like "GenomicAlign%" or ml.class like "%.constrained_element" or ml.class = "ConservationScore.conservation_score")
  ');
  
  my $constrained_elements = {};
  my %valid_species = map {($_, 1)} keys %{$self->full_tree};
  
  foreach my $row (@$res_aref) {
    my ($class, $type, $species, $name, $id, $species_set_id) = ($row->[0], uc $row->[1], ucfirst $row->[2], $row->[3], $row->[4], $row->[5]);
    my $key = 'ALIGNMENTS';
    
    if ($class =~ /ConservationScore/ || $type =~ /CONSERVATION_SCORE/) {
      $key  = 'CONSERVATION_SCORES';
      $name = 'Conservation scores';
    } elsif ($class =~ /constrained_element/ || $type =~ /CONSTRAINED_ELEMENT/) {
      $key = 'CONSTRAINED_ELEMENTS';
      $constrained_elements->{$species_set_id} = $id;
    } elsif ($type !~ /EPO_LOW_COVERAGE/ && ($class =~ /tree_alignment/ || $type  =~ /EPO/)) {
      $self->db_tree->{$db_name}{$key}{$id}{'species'}{'ancestral_sequences'} = 1 unless exists $self->db_tree->{$db_name}{$key}{$id};
    }
    
    $species =~ tr/ /_/;
    
    $self->db_tree->{$db_name}{$key}{$id}{'id'}                = $id;
    $self->db_tree->{$db_name}{$key}{$id}{'name'}              = $name;
    $self->db_tree->{$db_name}{$key}{$id}{'type'}              = $type;
    $self->db_tree->{$db_name}{$key}{$id}{'class'}             = $class;
    $self->db_tree->{$db_name}{$key}{$id}{'species_set_id'}    = $species_set_id;
    $self->db_tree->{$db_name}{$key}{$id}{'species'}{$species} = 1;
  }
  
  foreach my $species_set_id (keys %$constrained_elements) {
    my $constr_elem_id = $constrained_elements->{$species_set_id};
    
    foreach my $id (keys %{$self->db_tree->{$db_name}{'ALIGNMENTS'}}) {
      $self->db_tree->{$db_name}{'ALIGNMENTS'}{$id}{'constrained_element'} = $constr_elem_id if $self->db_tree->{$db_name}{'ALIGNMENTS'}{$id}{'species_set_id'} == $species_set_id;
    }
  }

  $res_aref = $dbh->selectall_arrayref('select meta_key, meta_value FROM meta where meta_key LIKE "gerp_%"');
  
  foreach my $row (@$res_aref) {
    my ($meta_key, $meta_value) = ($row->[0], $row->[1]);
    my ($conservation_score_id) = $meta_key =~ /gerp_(\d+)/;
    
    next unless $conservation_score_id;
    
    $self->db_tree->{$db_name}{'ALIGNMENTS'}{$meta_value}{'conservation_score'} = $conservation_score_id;
  }
  
  my %sections = (
    ENSEMBL_ORTHOLOGUES => 'GENE',
    HOMOLOGOUS_GENE     => 'GENE',
    HOMOLOGOUS          => 'GENE',
  );
  
  # We've done the DB hash... So lets get on with the DNA, SYNTENY and GENE hashes;
  $res_aref = $dbh->selectall_arrayref('
    select ml.type, gd1.name, gd2.name
      from genome_db gd1, genome_db gd2, species_set ss1, species_set ss2,
       method_link ml, method_link_species_set mls1,
       method_link_species_set mls2
     where mls1.method_link_species_set_id = mls2.method_link_species_set_id and
       ml.method_link_id = mls1.method_link_id and
       ml.method_link_id = mls2.method_link_id and
       gd1.genome_db_id != gd2.genome_db_id and
       mls1.species_set_id = ss1.species_set_id and
       mls2.species_set_id = ss2.species_set_id and
       ss1.genome_db_id = gd1.genome_db_id and
       ss2.genome_db_id = gd2.genome_db_id
  ');

  # See if there are any intraspecies alignments (ie a self compara)
  my %config;
  my $q = q{
    select ml.type, gd.name, gd.name, count(*) as count
      from method_link_species_set as mls, 
        method_link as ml, species_set as ss, genome_db as gd 
      where mls.species_set_id = ss.species_set_id
        and ss.genome_db_id = gd.genome_db_id 
        and mls.method_link_id = ml.method_link_id
        and ml.type not like '%PARALOGUES'
      group by mls.method_link_species_set_id, mls.method_link_id
      having count = 1
  };
  
  my $sth       = $dbh->prepare($q);
  my $rv        = $sth->execute || die $sth->errstr;
  my $v_results = $sth->fetchall_arrayref;
  
  # if there are intraspecies alignments then get full details of all genomic alignments, ie start and stop
  # currently these are only needed for Vega where there are only strictly defined regions in compara
  # but this could be extended to e! if we needed to know this
  if (scalar @$v_results) {
    # get details of seq_regions in the database
    $q = '
      select df.dnafrag_id, df.name, df.coord_system_name, gdb.name
        from dnafrag df, genome_db gdb
        where df.genome_db_id = gdb.genome_db_id
    ';
    
    $sth = $dbh->prepare($q);
    $rv  = $sth->execute || die $sth->errstr;
    
    my %genomic_regions;
    
    while (my ($dnafrag_id, $sr, $coord_system, $species) = $sth->fetchrow_array) {
      $species =~ s/ /_/;
      
      $genomic_regions{$dnafrag_id} = {
        species      => $species,
        seq_region   => $sr,
        coord_system => $coord_system,
      };
    }
    
#    warn "genomic regions are ",Dumper(\%genomic_regions);

    # get details of methods in the database -
    $q = '
      select mlss.method_link_species_set_id, ml.type, mlss.name
        from method_link_species_set mlss, method_link ml
        where mlss.method_link_id = ml.method_link_id
    ';
    
    $sth = $dbh->prepare($q);
    $rv  = $sth->execute || die $sth->errstr;
    my (%methods, %names);
    
    while (my ($mlss, $type, $name) = $sth->fetchrow_array) {
      $methods{$mlss} = $type;
      $names{$mlss}   = $name;
    }
    
    # get details of alignments
    $q = '
      select genomic_align_block_id, method_link_species_set_id, dnafrag_start, dnafrag_end, dnafrag_id
        from genomic_align
        order by genomic_align_block_id, dnafrag_id
    ';
    
    $sth = $dbh->prepare($q);
    $rv  = $sth->execute || die $sth->errstr;
        
    # parse the data
    my (@seen_ids, $prev_id, $prev_df_id, $prev_comparison, $prev_method, $prev_start, $prev_end, $prev_sr, $prev_species, $prev_coord_sys);
    
    while (my ($gabid, $mlss_id, $start, $end, $df_id) = $sth->fetchrow_array) {
      my $id = $gabid . $mlss_id;
      
      if ($id eq $prev_id) {
        my $this_method    = $methods{$mlss_id};
        my $this_sr        = $genomic_regions{$df_id}->{'seq_region'};
        my $this_species   = $genomic_regions{$df_id}->{'species'};
        my $this_coord_sys = $genomic_regions{$df_id}->{'coord_system'};
        my $comparison     = "$this_sr:$prev_sr";
        my $coords         = "$this_coord_sys:$prev_coord_sys";
        
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'coord_systems'}  = "$coords";  # add a record of the coord systems used (might be needed for zebrafish ?)
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'source_name'}    = "$this_sr"; # add names of compared regions
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'source_species'} = "$this_species";
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'target_name'}    = "$prev_sr";
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'target_species'} = "$prev_species";
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'mlss_id'}        = "$mlss_id";
        
        $self->_get_vega_regions(\%config, $this_method, $comparison, $this_species, $prev_species, $start, $prev_start,'start'); # look for smallest start in this comparison
        $self->_get_vega_regions(\%config, $this_method, $comparison, $this_species, $prev_species, $end, $prev_end, 'end');      # look for largest ends in this comparison
      } else {
        $prev_id        = $id;
        $prev_df_id     = $df_id;
        $prev_start     = $start;
        $prev_end       = $end;
        $prev_sr        = $genomic_regions{$df_id}->{'seq_region'};
        $prev_species   = $genomic_regions{$df_id}->{'species'};
        $prev_coord_sys = $genomic_regions{$df_id}->{'coord_system'};
      }        
    }
    
    # add reciprocal entries for each comparison
    foreach my $method (keys %config) {
      foreach my $p_species (keys %{$config{$method}}) {
        foreach my $s_species (keys %{$config{$method}{$p_species}}) {                                                
          foreach my $comp (keys %{$config{$method}{$p_species}{$s_species}}) {
            my $revcomp = join ':', reverse(split ':', $comp);
            
            if (!exists $config{$method}{$s_species}{$p_species}{$revcomp}) {
              my $coords = $config{$method}{$p_species}{$s_species}{$comp}{'coord_systems'};
              my ($a,$b) = split ':', $coords;
              
              $coords = "$b:$a";
              
              my $record = {
                source_name    => $config{$method}{$p_species}{$s_species}{$comp}{'target_name'},
                source_species => $config{$method}{$p_species}{$s_species}{$comp}{'target_species'},
                source_start   => $config{$method}{$p_species}{$s_species}{$comp}{'target_start'},
                source_end     => $config{$method}{$p_species}{$s_species}{$comp}{'target_end'},
                target_name    => $config{$method}{$p_species}{$s_species}{$comp}{'source_name'},
                target_species => $config{$method}{$p_species}{$s_species}{$comp}{'source_species'},
                target_start   => $config{$method}{$p_species}{$s_species}{$comp}{'source_start'},
                target_end     => $config{$method}{$p_species}{$s_species}{$comp}{'source_end'},
                mlss_id        => $config{$method}{$p_species}{$s_species}{$comp}{'mlss_id'},
                coord_systems  => $coords,
              };
              
              $config{$method}{$s_species}{$p_species}{$revcomp} = $record;
            }
          }
        }
      }
    }

    # get a summary of the regions present (used for Vega 'availability' calls)
    my $region_summary;
    foreach my $method (keys %config) {
      foreach my $p_species (keys %{$config{$method}}) {
        foreach my $s_species (keys %{$config{$method}{$p_species}}) {                                                
          foreach my $comp (keys %{$config{$method}{$p_species}{$s_species}}) {
            my $target_name  = $config{$method}{$p_species}{$s_species}{$comp}{'target_name'};
            my $source_name  = $config{$method}{$p_species}{$s_species}{$comp}{'source_name'};
            my $source_start = $config{$method}{$p_species}{$s_species}{$comp}{'source_start'};
            my $source_end   = $config{$method}{$p_species}{$s_species}{$comp}{'source_end'};
            my $mlss_id      = $config{$method}{$p_species}{$s_species}{$comp}{'mlss_id'};
            my $name         = $names{$mlss_id};
            
            push @{$region_summary->{$p_species}{$source_name}}, {
              secondary_species => $s_species,
              target_name       => $target_name,
              start             => $source_start,
              end               => $source_end,
              mlss_id           => $mlss_id,
              alignment_name    => $name,
            };
          }
        }
      }
    }
    
    $self->db_tree->{$db_name}{'VEGA_COMPARA'} = \%config;
    $self->db_tree->{$db_name}{'VEGA_COMPARA'}{'REGION_SUMMARY'} = $region_summary;
  }
  
  ## That's the end of the compara region munging!

  my $res_aref_2 = $dbh->selectall_arrayref(qq{
    select ml.type, gd.name, gd.name, count(*) as count
      from method_link_species_set as mls, method_link as ml, species_set as ss, genome_db as gd 
      where mls.species_set_id = ss.species_set_id and
        ss.genome_db_id = gd.genome_db_id and
        mls.method_link_id = ml.method_link_id and
        ml.type not like '%PARALOGUES'
      group by mls.method_link_species_set_id, mls.method_link_id
      having count = 1
  });
  
  push @$res_aref, $_ for @$res_aref_2;
  
  foreach my $row (@$res_aref) {
    my ($species1, $species2) = (ucfirst $row->[1], ucfirst $row->[2]);
    
    $species1 =~ tr/ /_/;
    $species2 =~ tr/ /_/;
    
    my $key = $sections{uc $row->[0]} || uc $row->[0];
    
    $self->db_tree->{$db_name}{$key}{'merged'}{$species2}  = $valid_species{$species2};
    $self->db_tree->{$db_name}{$key}{$species1}{$species2} = $valid_species{$species2};
  }             
  
  ###################################################################
  ## Section for colouring and colapsing/hidding genes per species in the GeneTree View
  # 1. Only use the species_sets that have a genetree_display tag
  
  $res_aref = $dbh->selectall_arrayref(q{SELECT species_set_id FROM species_set_tag WHERE tag = 'genetree_display'});
  
  foreach my $row (@$res_aref) {
    # 2.1 For each set, get all the tags
    my ($species_set_id) = @$row;
    my $res_aref2 = $dbh->selectall_arrayref("SELECT tag, value FROM species_set_tag WHERE species_set_id = $species_set_id");
    my $res;
    
    foreach my $row2 (@$res_aref2) {
      my ($tag, $value) = @$row2;
      $res->{$tag} = $value;
    }
    
    my $name = $res->{'name'}; # 2.2 Get the name for this set (required)
    
    next unless $name; # Requires a name for the species_set
    
    # 2.3 Store the values
    while (my ($key, $value) = each %$res) {
      next if $key eq 'name';
      $self->db_tree->{$db_name}{'SPECIES_SET'}{$name}{$key} = $value;
    }

    # 3. Get the genome_db_ids for each set
    $res_aref2 = $dbh->selectall_arrayref("SELECT genome_db_id FROM species_set WHERE species_set_id = $species_set_id");
    
    push @{$self->db_tree->{$db_name}{'SPECIES_SET'}{$name}{'genome_db_ids'}}, $_->[0] for @$res_aref2;
  }
  
  ## End section about colouring and colapsing/hidding gene in the GeneTree View
  ###################################################################

  ###################################################################
  ## Section for storing the genome_db_ids <=> species_name
  $res_aref = $dbh->selectall_arrayref('SELECT genome_db_id, name, assembly FROM genome_db WHERE assembly_default = 1');
  
  foreach my $row (@$res_aref) {
    my ($genome_db_id, $species_name) = @$row;
    
    $species_name =~ tr/ /_/;
    
    $self->db_tree->{$db_name}{'GENOME_DB'}{$species_name} = $genome_db_id;
    $self->db_tree->{$db_name}{'GENOME_DB'}{$genome_db_id} = $species_name;
  }
  ###################################################################
  
  $dbh->disconnect;
}

sub _get_vega_regions {
  #compare regions to get the smallest start and largest end
  my $self = shift;
  my ($config,$method,$comparison,$species1,$species2,$location1,$location2,$condition) = @_;
  if ($config->{$method}{$species1}{$species2}{$comparison}{'source_'.$condition}) {
    if ($self->_comp_se( $condition,$location1,$config->{$method}{$species1}{$species2}{$comparison}{'source_'.$condition} )) {
      $config->{$method}{$species1}{$species2}{$comparison}{'source_'.$condition} = $location1;
    }
  }
  else {
    $config->{$method}{$species1}{$species2}{$comparison}{'source_'.$condition} = $location1;        
  }

  if ($config->{$method}{$species1}{$species2}{$comparison}{'target_'.$condition}) {
    if ($self->_comp_se( $condition,$location2,$config->{$method}{$species1}{$species2}{$comparison}{'target_'.$condition} )) {
      $config->{$method}{$species1}{$species2}{$comparison}{'target_'.$condition} = $location2;
    }
  }
  else {
    $config->{$method}{$species1}{$species2}{$comparison}{'target_'.$condition} = $location2;        
  }
}

sub _comp_se {
# compare start (less than) or end (greater than) regions depending on condition
  my $self = shift;
  my ($condition, $location1, $location2) = @_;
  if ($condition eq 'start') {
    return $location1 < $location2 ? 1 : 0;
  }
  if ($condition eq 'end') {
    return $location1 > $location2 ? 1 : 0;
  }
}


sub _summarise_ancestral_db {
  my($self,$code,$db_name) = @_;
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
  $dbh->disconnect();
}

sub _summarise_go_db {
  my $self = shift;
  my $db_name = 'DATABASE_GO';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  #$self->_summarise_generic( $db_name, $dbh );
  $dbh->disconnect();
}

sub _summarise_dasregistry {
  my $self = shift;
  
  # Registry parsing is lazy so re-use the parser between species'
  my $das_reg = $self->tree->{'DAS_REGISTRY_URL'} || ( warn "No DAS_REGISTRY_URL in config tree" && return );
  
  my @reg_sources = @{ $self->_parse_das_server($das_reg) };
  # Fetch the sources for the current species
  my %reg_logic = map { $_->logic_name => $_ } @reg_sources;
  my %reg_url   = map { $_->full_url   => $_ } @reg_sources;
  
  # The ENSEMBL_INTERNAL_DAS_SOURCES section is a list of enabled DAS sources
  # Then there is a section for each DAS source containing the config
  $self->tree->{'ENSEMBL_INTERNAL_DAS_SOURCES'}     ||= {};
  $self->das_tree->{'ENSEMBL_INTERNAL_DAS_CONFIGS'} ||= {};
  while (my ($key, $val) 
         = each %{ $self->tree->{'ENSEMBL_INTERNAL_DAS_SOURCES'} }) {

    # Skip disabled sources
    $val || next;
    # Start with an empty config
    my $cfg = $self->tree->{$key};
    if (!defined $cfg || !ref($cfg)) {
      $cfg = {};
    }
    
    $cfg->{'logic_name'}      = $key;
    $cfg->{'category'}        = $val;
    $cfg->{'homepage'}      ||= $cfg->{'authority'};

    # Make sure 'coords' is an array
    if( $cfg->{'coords'} && !ref $cfg->{'coords'} ) {
      $cfg->{'coords'} = [ $cfg->{'coords'} ];
    }
    
    # Check if the source is registered
    my $src = $reg_logic{$key};

    # Try the actual server URL if it's provided but the registry URI isn't
    if (!$src && $cfg->{'url'} && $cfg->{'dsn'}) {
      my $full_url = $cfg->{'url'} . '/' . $cfg->{'dsn'};
      $src = $reg_url{$full_url};
      # Try parsing from the server itself
      if (!$src) {
        eval {
          my %server_url = map {$_->full_url => $_} @{ $self->_parse_das_server($full_url) };
          $src = $server_url{$full_url};
        };
        if ($@) {
          warn "DAS source $key might not work - not in registry and server is down";
        }
      }
    }

    # Doesn't have to be in the registry... unfortunately
    # But if it is, fill in the blanks
    if ($src) {
      $cfg->{'label'}       ||= $src->label;
      $cfg->{'description'} ||= $src->description;
      $cfg->{'maintainer'}  ||= $src->maintainer;
      $cfg->{'homepage'}    ||= $src->homepage;
      $cfg->{'url'}         ||= $src->url;
      $cfg->{'dsn'}         ||= $src->dsn;
      $cfg->{'coords'}      ||= [map { $_->to_string } @{ $src->coord_systems }];
    }
    
    if (!$cfg->{'url'}) {
      warn "Skipping DAS source $key - unable to find 'url' property (tried looking in registry and INI)";
      next;
    }
    if (!$cfg->{'dsn'}) {
      warn "Skipping DAS source $key - unable to find 'dsn' property (tried looking in registry and INI)";
      next;
    }
    
    # Add the final config hash to the das packed tree
    $self->das_tree->{'ENSEMBL_INTERNAL_DAS_CONFIGS'}{$key} = $cfg;
  }
}

sub _parse_das_server {
  my ( $self, $location ) = @_;
  
  my $parser = $self->{'_das_parser'};
  if (!$parser) {
    $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
      -timeout  => $self->tree->{'ENSEMBL_DAS_TIMEOUT'},
      -proxy    => $self->tree->{'ENSEMBL_WWW_PROXY'},
      -noproxy  => $self->tree->{'ENSEMBL_NO_PROXY'},
    );
    $self->{'_das_parser'} = $parser;
  }
  
  my $sources = $parser->fetch_Sources( -location => $location,
                                        -species => $self->species );
  return $sources;
}

sub _munge_meta {
  my $self = shift;
  
  ##########################################
  # SPECIES_COMMON_NAME     = Human        #
  # SPECIES_PRODUCTION_NAME = homo_sapiens #
  # SPECIES_SCIENTIFIC_NAME = Homo sapiens #
  ##########################################
  
  my %keys = qw(
    species.taxonomy_id        TAXONOMY_ID
    species.ensembl_alias_name SPECIES_COMMON_NAME
    species.production_name    SPECIES_PRODUCTION_NAME
    species.scientific_name    SPECIES_SCIENTIFIC_NAME
    assembly.default           ASSEMBLY_NAME
    assembly.name              ASSEMBLY_DISPLAY_NAME
    liftover.mapping           ASSEMBLY_MAPPINGS
    genebuild.method           GENEBUILD_METHOD
    provider.name              PROVIDER_NAME
    provider.url               PROVIDER_URL
    provider.logo              PROVIDER_LOGO
    species.strain             SPECIES_STRAIN
    species.sql_name           SYSTEM_NAME
  );
  
  my @months    = qw(blank Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my $meta_info = $self->_meta_info('DATABASE_CORE') || {};
  my @sp_count  = grep { $_ > 0 } keys %$meta_info;

  if (scalar @sp_count > 1) {
    ## Database contains more than one species
    $self->tree->{'SPP_ARE_GROUPED'} = 1;
    
    if ($meta_info->{0}{'species.group'}) {
      $self->tree->{'DISPLAY_NAME'} = $meta_info->{0}{'species.group'};
    } else {
      (my $group_name = $self->{'_species'}) =~ s/_collection//;
      $self->tree->{'DISPLAY_NAME'} = $group_name;
    }
  } else {
    $self->tree->{'DISPLAY_NAME'} = $meta_info->{1}{'species.ensembl_alias_name'}[0];
  }

  while (my ($species_id, $meta_hash) = each (%$meta_info)) {
    next unless $species_id && $meta_hash && ref($meta_hash) eq 'HASH';
    
    ## Do species name and group
    my ($species, $bioname, $bioshort);
    my $taxonomy = $meta_hash->{'species.classification'};
    
    if ($taxonomy && scalar(@$taxonomy)) {
      $species  = "$taxonomy->[1]_$taxonomy->[0]";
      $bioname  = "$taxonomy->[1] $taxonomy->[0]";
      $bioshort = substr($taxonomy->[1], 0, 1) . '.' . $taxonomy->[0];
      
      my $order = $self->tree->{'TAXON_ORDER'};
      
      foreach my $taxon (@$taxonomy) {
        foreach my $group (@$order) {
          if ($taxon eq $group) {
            $self->tree->{$species}{'SPECIES_GROUP'} = $group;
            last;
          }
        }
        
        last if $self->tree->{$species}{'SPECIES_GROUP'};
      }
    } else {
      ## Default to same name as database 
      $species   = $self->{'_species'};
      ($bioname  = $species) =~ s/_/ /g;
      ($bioshort = $bioname) =~ s/^([A-Z])[a-z]+_([a-z]+)$/$1.$2/;
    }
    
    $self->tree->{$species}{'SPECIES_BIO_NAME'}  = $bioname;
    $self->tree->{$species}{'SPECIES_BIO_SHORT'} = $bioshort;
    
    if ($self->tree->{'ENSEMBL_SPECIES'}) {
      push @{$self->tree->{'DB_SPECIES'}}, $species;
    } else {
      $self->tree->{'DB_SPECIES'} = [ $species ];
    }

    ## Get assembly info 
    while (my ($meta_key, $key) = each (%keys)) {
      next unless $meta_hash->{$meta_key};
      
      my $value = scalar @{$meta_hash->{$meta_key}} > 1 ? $meta_hash->{$meta_key} : $meta_hash->{$meta_key}[0]; 
      $self->tree->{$species}{$key} = $value;
    }
    
    $self->tree->{$species}{'SPECIES_META_ID'} = $species_id;

    ## Munge genebuild info
    my @A = split '-', $meta_hash->{'genebuild.start_date'}[0];
    
    $self->tree->{$species}{'GENEBUILD_START'} = "$months[$A[1]] $A[0]";
    $self->tree->{$species}{'GENEBUILD_BY'}    = $A[2];

    @A = split '-', $meta_hash->{'genebuild.initial_release_date'}[0];
    
    $self->tree->{$species}{'GENEBUILD_RELEASE'} = "$months[$A[1]] $A[0]";
    
    @A = split '-', $meta_hash->{'genebuild.last_geneset_update'}[0];
    
    $self->tree->{$species}{'GENEBUILD_LATEST'} = "$months[$A[1]] $A[0]";
    
    @A = split '-', $meta_hash->{'assembly.date'}[0];
    
    $self->tree->{$species}{'ASSEMBLY_DATE'} = "$months[$A[1]] $A[0]";
    
    # check if there are sample search entries defined in meta table ( the case with Ensembl Genomes)
    # they can be overwritten at a later stage  via INI files
    my @ks = grep { /^sample\./ } keys %{$meta_hash || {}};
    my $shash;

    foreach my $k (@ks) {
      (my $k1 = $k) =~ s/^sample\.//;
      $shash->{uc $k1} = $meta_hash->{$k}->[0];
    }
    
    $self->tree->{$species}{'SAMPLE_DATA'} = $shash if $shash;

    # check if the karyotype/list of toplevel regions ( normally chroosomes) is defined in meta table
    @{$self->tree($species)->{'TOPLEVEL_REGIONS'}} = @{$meta_hash->{'regions.toplevel'}} if $meta_hash->{'regions.toplevel'};
  }
}

sub _munge_variation {
  my $self = shift;
  my $dbh     = $self->db_connect('DATABASE_VARIATION');
  return unless $dbh;
  return unless $self->db_details('DATABASE_VARIATION');
  my $total = 0;
  if ( $self->tree->{'databases'}{'DATABASE_VARIATION'}{'DISPLAY_STRAINS'} ) {
    $total +=  @{ $self->tree->{'databases'}{'DATABASE_VARIATION'}{'DISPLAY_STRAINS'} };
  }
  if ( $self->tree->{'databases'}{'DATABASE_VARIATION'}{'DEFAULT_STRAINS'} ) {
    $total +=  @{ $self->tree->{'databases'}{'DATABASE_VARIATION'}{'DEFAULT_STRAINS'} }; 
  }
  $self->tree->{'databases'}{'DATABASE_VARIATION'}{'#STRAINS'} = $total;
    $self->tree->{'databases'}{'DATABASE_VARIATION'}{'DEFAULT_LD_POP'}   = $self->_meta_info('DATABASE_VARIATION','pairwise_ld.default_population')->[0] if $self->_meta_info('DATABASE_VARIATION','pairwise_ld.default_population');
}

sub _munge_website {
  my $self = shift;

  ## Release info for ID history etc
  $self->tree->{'ASSEMBLIES'}       = $self->db_multi_tree->{'ASSEMBLIES'}{$self->{_species}};
  $self->tree->{'ENSEMBL_ARCHIVES'} = $self->db_multi_tree->{'ENSEMBL_ARCHIVES'}{$self->{_species}};
}

sub _munge_website_multi {
  my $self = shift;

  $self->tree->{'ENSEMBL_HELP'} = $self->db_tree->{'ENSEMBL_HELP'};
  $self->tree->{'ENSEMBL_GLOSSARY'} = $self->db_tree->{'ENSEMBL_GLOSSARY'};
}

sub _configure_blast {
  my $self = shift;
  my $tree = $self->tree;
  my $species = $self->species;
  $species =~ s/ /_/g;
  my $method = $self->full_tree->{'MULTI'}{'ENSEMBL_BLAST_METHODS'};
  foreach my $blast_type (keys %$method) { ## BLASTN, BLASTP, BLAT, etc
    next unless ref($method->{$blast_type}) eq 'ARRAY';
    my @method_info = @{$method->{$blast_type}};
    my $search_type = uc($method_info[0]); ## BLAST or BLAT at the moment
    my $sources = $self->full_tree->{'MULTI'}{$search_type.'_DATASOURCES'};
    $tree->{$blast_type.'_DATASOURCES'}{'DATASOURCE_TYPE'} = $method_info[1]; ## dna or peptide
    my $db_type = $method_info[2]; ## dna or peptide
    foreach my $source_type (keys %$sources) { ## CDNA_ALL, PEP_ALL, etc
      next if $source_type eq 'DEFAULT';
      next if ($db_type eq 'dna' && $source_type =~ /^PEP/);
      next if ($db_type eq 'peptide' && $source_type !~ /^PEP/);
      if ($source_type eq 'CDNA_ABINITIO') { ## Does this species have prediction transcripts?
        next unless 1;
      }
      elsif ($source_type eq 'RNA_NC') { ## Does this species have RNA data?
        next unless 1;
      }
      elsif ($source_type eq 'PEP_KNOWN') { ## Does this species have species-specific protein data?
        next unless 1;
      }
      my $assembly = $tree->{$species}{'ASSEMBLY_NAME'}; 
      (my $type = lc($source_type)) =~ s/_/\./ ;
      if ($type =~ /latestgp/) {
        if ($search_type ne 'BLAT') {
          $type =~ s/latestgp(.*)/dna$1\.toplevel/;
          $type =~ s/.masked/_rm/;
          my $repeat_date = $self->db_tree->{'REPEAT_MASK_DATE'} || $self->db_tree->{'DB_RELEASE_VERSION'};
          my $file = sprintf( '%s.%s.%s.%s', $species, $assembly, $repeat_date, $type ).".fa";
#          print "AUTOGENERATING $source_type......$file\n";
          $tree->{$blast_type.'_DATASOURCES'}{$source_type} = $file;
        }
      } 
      else {
        $type = "ncrna" if $type eq 'rna.nc';
        my $version = $self->db_tree->{'DB_RELEASE_VERSION'} || $SiteDefs::ENSEMBL_VERSION;
        my $file = sprintf( '%s.%s.%s.%s', $species, $assembly, $version, $type ).".fa";
#        print "AUTOGENERATING $source_type......$file\n";
        $tree->{$blast_type.'_DATASOURCES'}{$source_type} = $file;
      }
    }
#    warn "TREE $blast_type = ".Dumper($tree->{$blast_type.'_DATASOURCES'});
  }
}


1;
