package EnsEMBL::Web::Factory::Location;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Factory);

use EnsEMBL::Web::Proxy::Object;
use Bio::EnsEMBL::Feature;
use CGI qw(escapeHTML);
use POSIX qw(floor ceil);

use Data::Dumper;

sub createObjects {
  my $self      = shift; 
  if(   $self->core_objects->location
     && !$self->core_objects->location->isa('EnsEMBL::Web::Fake') 
     && !$self->core_objects->gene
  ) {
    $self->_create_object_from_core;
    my $obj = $self->DataObjects->[0];
    foreach my $param ($self->param) {
      #multicontigview
      if ($param =~ /^s\d+$/) {
	#first, check if we need to generate a url
	$self->generate_full_url($obj);
	#then go and create the objects
	if ($self->core_objects->location) {
	  $self->createObjectsLocation($obj);
	}
	elsif ($self->core_objects->gene) {
	  #$self->createObjectsGene($obj);
	}
      }
    }
    return $self;
  }
  $self->get_databases($self->__gene_databases, 'compara','blast');
  my $database  = $self->database('core');
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $database;
## First lets try and locate the slice....

## Gene
  my $location;
  my $temp_id;
  my $strand     = $self->param( 'strand' )    || $self->param( 'seq_region_strand' ) || 1;
  my $seq_region = $self->param( 'region' )    || $self->param( 'contig' )     ||
                   $self->param( 'clone'  )    || $self->param( 'seqregion' )  ||
                   $self->param( 'chr' )       || $self->param( 'seq_region_name' );
  my $start      = $self->param( 'vc_start'  ) || $self->param( 'chr_start' )  ||
                   $self->param( 'wvc_start' ) || $self->param( 'fpos_start' ) ||
                   $self->param( 'start' );
  my $end        = $self->param( 'vc_end'  )   || $self->param( 'chr_end' )    ||
                   $self->param( 'wvc_end' )   || $self->param( 'fpos_end' )   ||
                   $self->param( 'end' );
  if( defined $self->param('r') && ! $self->core_objects->gene && ! $self->core_objects->variation ) {
    ($seq_region,$start,$end) = $self->param('r') =~ /^([-\w\.]+):(-?[\.\w,]+)-([\.\w,]+)$/;
    $start = $self->evaluate_bp($start);
    $end   = $self->evaluate_bp($end);
  } 

  if( defined $self->param('l') ) { 
    ($seq_region,$start,$end) = $self->param('l') =~ /^([-\w\.]+):(-?[\.\w,]+)-([\.\w,]+)$/;
    $start = $self->evaluate_bp($start);
    $end   = $self->evaluate_bp($end);
  } 

  $start = $self->evaluate_bp( $start ) if defined $start;
  $end   = $self->evaluate_bp( $end )   if defined $end;
#  if( defined $self->param( 'data_URL' ) ) {
#    my $loc = $self->_location_from_URL( $self->param( 'data_URL' ) );
#    if($loc) {
#      $self->DataObjects( $loc );
#      return;
#    }
#    $self->clear_problems(); 
#  }
  if( defined $self->param('c') ) {
    my($cp,$t_strand);
    ($seq_region,$cp,$t_strand) = $self->param('c') =~ /^([-\w\.]+):(-?[.\w,]+)(:-?1)?$/;
    $cp = $self->evaluate_bp( $cp );
    my $w = $self->evaluate_bp( $self->param('w') );
    $start = $cp - ($w-1)/2;
    $end   = $cp + ($w-1)/2;
    if( $t_strand ) {
      $strand = $t_strand eq ':-1' ? -1 : 1;
    }
  }
  if( defined $self->param('centrepoint') ) {
    my $cp = $self->evaluate_bp( $self->param('centrepoint') );
    my $w  = $self->evaluate_bp( $self->param('width') );
    $start = $cp - ($w-1)/2;
    $end   = $cp + ($w-1)/2;
  }

  my $temp_1_id = $self->param('anchor1');
  my $ftype_1   = $self->param('type1');
  my $temp_2_id = $self->param('anchor2');
  my $ftype_2   = $self->param('type2');
  my @anchorview = ();

  push @anchorview, [ $self->param('type1'), $self->param('anchor1') ]
    if $self->param('anchor1') && $self->param('type1');
  push @anchorview, [ $self->param('type2'), $self->param('anchor2') ]
    if $self->param('anchor2') && $self->param('type2');
  if( @anchorview ) {
    foreach my $O ( @anchorview ) {
      $location = undef;
      my( $ftype, $temp_id ) = @$O;
      if( $ftype eq 'gene' || $ftype eq 'all' ) {
        $location = $self->_location_from_Gene( $temp_id );
      } 
      if(!$location && ($ftype eq 'transcript' || $ftype eq 'all') ) { 
        $location = $self->_location_from_Transcript( $temp_id );
      } 
      if(!$location && ($ftype eq 'peptide' || $ftype eq 'all') ) { 
        $location = $self->_location_from_Peptide( $temp_id );
      } 
      if(!$location && $ftype eq 'marker') {
        $location = $self->_location_from_Marker( $temp_id, $seq_region );
      } 
      if(!$location && $ftype eq 'band') {
        $location = $self->_location_from_Band( $temp_id, $seq_region );
      } 
      if (!$location && ($ftype eq 'misc_feature' || $ftype eq 'all') ) {
        $location = $self->_location_from_MiscFeature( $temp_id );
      } 
      if(!$location && ($ftype eq 'region' || $ftype eq 'all') ) {
        $location = $self->_location_from_SeqRegion( $temp_id );
      } 
      if(!$location && ($ftype eq 'region' ) ) {
        $location = $self->_location_from_MiscFeature( $temp_id );
      }
      if (!$location) {
        $location = $self->_location_from_SeqRegion( $seq_region, $temp_id, $temp_id );
      }
      $self->DataObjects( $location ) if $location;
    }
    if( $self->DataObjects ) {
      $self->merge;
    }
=pod 
    else {
      return $self->problem( 'Fatal',
        'Unknown region',
        'Could not locate the region you have specified.  You may not have specified enough information'
      );
    }
=cut
  } else {
    ## Gene (completed)
    if(!defined($start) && (
      $temp_id = $self->param('geneid') || $self->param('gene') 
#      || ( $self->core_objects->gene ? undef : $self->param('g') )
    )) {
      $location = $self->_location_from_Gene( $temp_id );
    ## Transcript (completed)
    } elsif( $temp_id = $self->param('transid') || $self->param('trans') || $self->param('transcript')
#      || ( $self->core_objects->transcript ? undef : $self->param('t' ) )
    ) {
      $location = $self->_location_from_Transcript( $temp_id );
    } elsif( $temp_id = $self->param('exonid') || $self->param('exon') ) {  
      $location = $self->_location_from_Exon( $temp_id );
    ## Translation (completed)
    } elsif( $temp_id = $self->param('peptide') || $self->param('pepid') || $self->param('peptideid') || $self->param('translation') ) {
      $location = $self->_location_from_Peptide( $temp_id );
    ## MiscFeature (completed)
    } elsif( $temp_id = $self->param('mapfrag') || $self->param('miscfeature') || $self->param('misc_feature') ) {
        $location = $self->_location_from_MiscFeature( $temp_id );
    ## Marker (completed)
    } elsif( $temp_id = $self->param('marker') ) { 
        $location = $self->_location_from_Marker( $temp_id, $seq_region );
    ## Band (completed)
    } elsif( $temp_id = $self->param('band') ) { 
        $location = $self->_location_from_Band( $temp_id, $seq_region );
    } elsif( !$start && ($temp_id = $self->param('snp')||$self->param('variation') 
      # || $self->param('v')
    ) ) { 
        $location = $self->_location_from_Variation( $temp_id, $seq_region );
    } else {
      if( $self->param( 'click_to_move_window.x' ) ) {
        $location = $self->_location_from_SeqRegion( $seq_region, $start, $end );
        if( $location ) {
          $location->setCentrePoint( floor(
            ( $self->param( 'click_to_move_window.x' ) - $self->param( 'vc_left' ) ) /
            ( $self->param( 'vc_pix' )||1 ) * $self->param( 'tvc_length' )
          ) );
        }
      ## Chromosome click...
      } elsif( $self->param( 'click_to_move_chr.x' ) ) { 
        $location = $self->_location_from_SeqRegion( $seq_region );
        if( $location ) { 
          $location->setCentrePoint( floor(
            ( $self->param( 'click_to_move_chr.x' ) - $self->param( 'chr_left' ) ) /
            ( $self->param( 'chr_pix' )||1) * $self->param( 'chr_len' )
          ) );
        }
      } elsif( $temp_id = $self->param( 'click.x' ) + $self->param( 'vclick.y' ) ) {
        $location = $self->_location_from_SeqRegion( $seq_region );
        if( $location ) { 
          $location->setCentrePoint( floor(
            $self->param( 'seq_region_left' ) +
            ( $temp_id - $self->param( 'click_left' ) + 0.5 ) /
            ( $self->param( 'click_right' ) - $self->param( 'click_left' ) + 1 ) *
            ( $self->param( 'seq_region_right' ) - $self->param( 'seq_region_left' ) + 1 )
          ), $self->param( 'seq_region_width' ) );
        }
## SeqRegion
      } elsif( $seq_region ) {
        $location = $self->_location_from_SeqRegion( $seq_region, $start, $end, $strand );
      }
    }
#    if( $self->param( 'data_URL' ) ) {
#      my $newloc   = $self->_location_from_URL();
#      $location = $newloc if $newloc;
#    }
    if( $location ) {
      $self->DataObjects( $location );
    } elsif( $self->core_objects->location ) {
      $self->_create_object_from_core;
    }
=pod 
    else {
      return $self->problem( 'Fatal', 'Unknown region', 'Could not locate the region you have specified.  You may not have specified enough information.' );
    }
=cut
  }
## Push location....
}

#do redirects for mcv
sub generate_full_url {
  my $self = shift;
  my $obj = shift;

  #show input parameters
#   foreach ($self->param) {	  
#     warn "$_ = ",$self->param($_),"\n";
#   }

  #study input params to see if there are any extra species, or species to be removed
  my ($ids,$sp_dets);
  my $max_s = 0;
  foreach my $par ( $self->param ) {
    if ($par =~ /^([sgr])(\d+)$/ ) {
      $ids->{$2}{$1} = 1;
    }
    if ($par =~ /^(s)(\d+)$/ ) {
      push @{$sp_dets->{$self->param($par)}}, $2;
      $max_s = $2 > $max_s ? $2 : $max_s;
    }
  }

  #are there any to be removed ?
  foreach my $sp (keys %$sp_dets) {
    if (scalar @{$sp_dets->{$sp}} > 1 ) {
      $self->remove_species_and_generate_url($sp);
    }
  }

  #could identify missing numbers by specifically pushing into an array rather than usig $max_s


  #are there any species that don't have an r param ?
  my $complete = 1;
  foreach my $no (keys %$ids) {
    $complete = 0 unless exists($ids->{$no}{'r'});
  }

  $self->find_missing_locations($obj,$ids) if (! $complete);

  return;
}

sub find_missing_locations {
  my $self = shift;
  my $obj = shift;
  my $ids = shift;
  my $slice = $obj->slice;
 PAR:
  foreach my $par ( $self->param ) {
    #given a s param, get locations...
    # - might need modif. if we can go in on a gene only ?

    if( $par =~ /^s(\d+)$/ ) {
      my $ID = $1;
      next PAR if $ids->{$ID}{'r'}; #don't attempt to do anything if we already have an r param
      my $species = $self->map_alias_to_species( $self->param($par) );
      my $width = $slice->end - $slice->start + 1;

      #get chr argument for self compara
      my $chrom = '';
      #	  if ($self->param("sr$ID")) {
      #	    $chrom = $self->param("sr$ID");
      #	  } elsif ($sc) {
      #	    ($chrom) =  $self->param("c$ID") =~ /^([-\w\.]+):?/;
      #	  }
      $self->_best_guess( $slice, $species, $width, $chrom, $ID ); #...and do a redirct
    }
  }
}

sub remove_species_and_generate_url {
  my $self = shift;
  my $sp = shift;
  warn "need to remove $sp and also rejig url";
  return;
}

sub _best_guess {
  my( $self, $slice, $species, $width, $chrom, $ID ) = @_;
  ( my $S2 = $species ) =~ s/_/ /g;
  ## foreach my $method ( @{$self->species_defs->COMPARATIVE_METHODS} ) {
  foreach my $method ( qw(BLASTZ_NET TRANSLATED_BLAT BLASTZ_RAW BLASTZ_CHAIN) ) {
    my( $seq_region, $cp, $strand );
    eval {
      ( $seq_region, $cp, $strand ) = $self->_dna_align_feature_adaptor->interpolate_best_location( $slice, $S2, $method, $chrom );
    };
    if( $seq_region ) {
#      warn "found another location -  $seq_region, $cp, $strand, $species, $ID";
      my $start = floor($cp - ($width-1)/2);
      my $end   = floor($cp + ($width-1)/2);
      $self->__set_species( $species );
      if ($ID) {
	$self->param('r'.$ID,"$seq_region:$start-$end:$strand");
      }
#      warn "ID is $ID";
      $self->_check_slice_exists_and_redirect( $species, $seq_region, $start, $end, $strand, 1 );
    }
  }
  return ();
}

sub map_alias_to_species {
  my( $self, $name ) = @_;
  my $ESA = $self->species_defs->ENSEMBL_SPECIES_ALIASES;
  my %map = map { lc($_), $ESA->{$_} } keys %$ESA;
  return $map{lc($name)};
}

sub _dna_align_feature_adaptor {
  my $self = shift;
  return $self->__data->{'compara_adaptors'}{'dna_align_feature'} ||=
    $self->database('compara')->get_DnaAlignFeatureAdaptor();
}

sub _check_slice_exists_and_redirect {
  my( $self, $species, $chr, $start, $end, $strand, $keep_slice ) = @_;
  if( defined $start ) {
    $start = floor( $start );
    $end   = $start unless defined $end;
    $end   = floor( $end );
    $end   = 1 if $end < 1;
    $strand ||= 1;
    $start = 1 if $start < 1;     ## Truncate slice to start of seq region
    ($start,$end) = ($end, $start) if $start > $end;
    my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Slice");

    foreach my $system ( @{$self->__coord_systems} ) {
      my $slice;
      eval { $slice = $self->_slice_adaptor->fetch_by_region( $system->name, $chr, $start, $end, $strand ); };

      warn $@ if $@;
      next if $@;
      if( $slice ) {
        if( $start >  $slice->seq_region_length || $end >  $slice->seq_region_length ) {
          $start = $slice->seq_region_length if $start > $slice->seq_region_length;
          $end   = $slice->seq_region_length if $end   > $slice->seq_region_length;
          $slice = $self->_slice_adaptor->fetch_by_region( $system->name, $chr, $start, $end, $strand );
        }
	my $pars;
	foreach my $par ($self->param) {
	  if ($par =~ /^[sgr]\d+|align/) {
	    $pars->{$par} = $self->param($par);
	  }
	}
	return $self->problem( 'redirect', $self->_url($pars));
      }
    }
    $self->problem( "fatal", "Locate error", $self->_help( "Cannot locate region $chr: $start - $end on the current assembly." ));
    return undef;
  } else {
    $self->problem( "fatal", "Locate error", $self->_help( "Cannot locate region $chr: $start - $end on the current assembly." ));
    return undef;
  }
}

sub createObjectsLocation {
  my $self = shift;
  my %SHORT = qw(chromosome Chr.
	       supercontig S'ctg
	       );

  my $ids;
  foreach my $par ( $self->param ) {
    if ($par =~ /^([sgr])(\d+)$/ ) {
      $ids->{$2}{$1} = $self->param($par);
    }
  }
  my $sec_slices;
  while (my ($no,$dets) = each (%$ids)) {
    my $species = $dets->{'s'};
    my $r =  $dets->{'r'};
    my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Slice");
    my $slice;
    my ($chr,$start,$end,$strand) = $r =~ /^([^:]+):(-?\w+\.?\w*)-(-?\w+\.?\w*)(?::(-\d+))?/;
    eval { $slice = $slice_adaptor->fetch_by_region( undef, $chr, $start, $end, $strand ); };
    warn $@ if $@;

    #generate short caption name
    my $type = $slice->coord_system_name();
    my $chr_name = $slice->seq_region_name();
    my $chr_raw = $chr_name;
    unless( $chr_name =~ /^$type/i ) {
      $type = $SHORT{lc($type)} || ucfirst( $type );
      $chr_name = "$type $chr_name";
    }
    if( length($chr_name) > 9 ) {
      $chr_name = $chr_raw;
    }
    (my $abbrev = $species ) =~ s/^(\w)\w+_(\w{3})\w+$/$1$2/g;
    my $chr_short = "$abbrev $chr_name";
    my $data = {
      'type' => 'Location',
      'real_species'       => $species,
      'name'               => $slice->seq_region_name,
      'seq_region_name'    => $slice->seq_region_name,
      'seq_region_start'   => $slice->start,
      'seq_region_end'     => $slice->end,
      'seq_region_strand'  => $strand,
      'seq_region_type'    => $slice->coord_system->name,
      'raw_feature_strand' => 1,
      'seq_region_length'  => $slice->seq_region_length,
      'short_name'         => $chr_short,
      'slice'              => $slice,
    };
    push @$sec_slices, $data;
  }
  $self->{'data'}{'_dataObjects'}[0][1]{'_other_locations'} = $sec_slices;
  return;
}


sub _help {
  my( $self, $string ) = @_;
  my %sample = %{$self->species_defs->SAMPLE_DATA ||{}};
  my $assembly_level = scalar(@{$self->species_defs->ENSEMBL_CHROMOSOMES ||[]}) ? 'chromosomal' : 'scaffold';
  my $help_text = $string ? sprintf( '
  <p>
    %s
  </p>', CGI::escapeHTML( $string ) ) : '';
  my $url = $self->_url({ '__clear' => 1, 'action' => 'View', 'r' => $sample{'LOCATION_PARAM'} });
  $help_text .= sprintf( '
  <p>
    A location is required to build this page. For example, %s coordinates:
  </p>
  <blockquote class="space-below">
    <a href="%s">%s</a>
  </blockquote>',
    $assembly_level,
    CGI::escapeHTML( $url ),
    CGI::escapeHTML( $self->species_defs->ENSEMBL_BASE_URL. $url )
  );
  if( scalar(@{$self->species_defs->ENSEMBL_CHROMOSOMES}) ) {
    my $url = $self->_url({ '__clear' => 1, 'action' => 'Genome' });
    $help_text .= sprintf( '
  <p class="space-below">
    You can also browse this genome via its <a href="%s">karyotype</a>
  </p>', CGI::escapeHTML($url) )
  }
  return $help_text;
}

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );
  $self->__set_species();
  return $self; 
}

sub __set_species {
  my( $self, $species, $golden_path, $level ) = @_;
  $species         ||= $self->species;
  $golden_path     ||= $self->species_defs->get_config( $species, 'ENSEMBL_GOLDEN_PATH' );
  $golden_path     ||= $self->species_defs->get_config( $species, 'ASSEMBLY_NAME' );
  $self->__species = $species; ## to store co-ordinate system information
  $self->__species_hash ||= {};

  unless( exists( $self->__species_hash->{'golden_path'} ) && $self->__golden_path eq $golden_path ) {
    $self->__golden_path = $golden_path;
    $self->__coord_systems = [
      grep { !$_->version || $_->version eq $self->__golden_path }
      @{$self->_coord_system_adaptor()->fetch_all()}
    ];
    $self->__level = undef; ## clear current level if changing golden path!!
  }
  return if $self->__level;
  my %T = map { $_,1 } @{$self->__coord_systems||[]};
  $level         = undef unless $T{ $level };
  $level         ||= 'toplevel';
  $self->__level ||= $level;
}

sub __set_default_otherspecies {
  my $self = shift;
  my %synteny = $self->species_defs->multi('SYNTENY');
  my @has_synteny = sort keys %synteny;
  my $other;
  foreach my $sp (@has_synteny) {
    ## Set default as primary or secondary species, if available
    if ($sp eq $self->species_defs->ENSEMBL_PRIMARY_SPECIES
          || $sp eq $self->species_defs->ENSEMBL_SECONDARY_SPECIES) {
      $other = $sp;
      last;
    }
  }
  ## otherwise choose first in list
  if (!$other) {
    $other = $has_synteny[0];
  }
  $self->__data->{'__location'}{'otherspecies'} = $other;
}

sub __species       :lvalue { $_[0]->__data->{'__location'}{'species'}; }
sub __species_hash  :lvalue { $_[0]->__data->{'__location'}{$_[0]->__data->{'__location'}{'species'}}; }
sub __level         :lvalue { $_[0]->__species_hash->{'level'};         }
sub __golden_path   :lvalue { $_[0]->__species_hash->{'golden_path'};   }
sub __coord_systems :lvalue { $_[0]->__species_hash->{'coord_systems'}; }

#------------------- Location by feature type ------------------------------

sub __gene_databases {
  my $self = shift;
  return map { lc(substr($_,9)) }  @{$self->species_defs->core_like_databases||[]}
}

sub _location_from_RegFeature {
  my( $self, $ID ) = @_;
  $self->problem( "fatal", "Unknown regulatory", $self->_help( "Could not find regulatory feature $ID" ) );
  return undef; 
}
sub _location_from_Gene {
  my( $self, $ID ) = @_;
  my $TS;
  my @dbs = $self->__gene_databases;
  foreach my $db ( @dbs ) {
    eval {
      my $TF = $self->_gene_adaptor( $db )->fetch_by_stable_id( $ID );
      $TS = $self->_slice_adaptor->fetch_by_Feature( $TF ) if $TF;
    };
    if( $TS ) {
      $self->param('db', $db );
      return $self->_create_from_slice( 'Gene', $ID, $self->expand($TS), $ID );
    }
  }
  foreach my $db ( @dbs ) {
    my $genes = $self->_gene_adaptor( $db )->fetch_all_by_external_name( $ID );
    if(@$genes) {
      $TS = $self->_slice_adaptor->fetch_by_Feature( $genes->[0] );
      if( $TS ) {
        $self->param('db', $db );
        return $self->_create_from_slice( 'Gene', $genes->[0]->stable_id, $self->expand($TS), $ID );
      }
    }
  }
  $self->problem( "fatal", "Unknown gene", $self->_help( "Could not find gene $ID") );
  return undef;
}

sub _location_from_Transcript {
  my( $self, $ID ) = @_;
  my $TS;
  my @dbs = $self->__gene_databases;
  foreach my $db ( @dbs ) {
    eval {
      my $TF = $self->_transcript_adaptor( $db )->fetch_by_stable_id( $ID );
      $TS = $self->_slice_adaptor->fetch_by_Feature( $TF ) if $TF;
    };
    if( $TS ) {
      $self->input_param('db', $db );
      return $self->_create_from_slice( 'Transcript', $ID, $self->expand($TS), $ID );
    }
  }
  foreach my $db ( @dbs ) {
    my $features = $self->_transcript_adaptor( $db )->fetch_all_by_external_name( $ID );
    if(@$features) {
      $TS = $self->_slice_adaptor->fetch_by_Feature( $features->[0] );
      if( $TS ) {
        $self->param('db', $db );
        return $self->_create_from_slice( 'Transcript', $features->[0]->stable_id, $self->expand($TS), $ID );
      }
    }
  }
  foreach my $db ( @dbs ) {
    eval {
      my $TF = $self->_predtranscript_adaptor( $db )->fetch_by_stable_id( $ID );
      $TS = $self->_slice_adaptor->fetch_by_Feature( $TF );
    };
    if( $TS ) {
      $self->param('db', $db );
      return $self->_create_from_slice( 'Transcript', $ID, $self->expand($TS), $ID );
    }
  }

  $self->problem( "fatal", "Unknown transcript", $self->_help( "Could not find transcript $ID" ) );
  return undef;
}

sub _location_from_Exon {
  my( $self, $ID ) = @_;
  my $TS;
  my @dbs = $self->__gene_databases;
  foreach my $db ( @dbs ) {
    eval {
      my $TF = $self->_exon_adaptor( $db )->fetch_by_stable_id( $ID );
      $TS = $self->_slice_adaptor->fetch_by_Feature( $TF ) if $TF;
    };
    if( $TS ) {
      $self->param('db', $db );
      return $self->_create_from_slice( 'Exon', $ID, $self->expand($TS), $ID );
    }
  }
  $self->problem( "fatal", "Unknown exon", $self->_help( "Could not find exon $ID" ) );
  return undef;
}

sub _location_from_Peptide {
  my( $self, $ID ) = @_;
  my $TS;
## Lets get the transcript....
  my @dbs = $self->__gene_databases;
  foreach my $db ( @dbs ) {
    my $TF;
    eval {
      $TF = $self->_transcript_adaptor( $db )->fetch_by_translation_stable_id( $ID );
      $TS = $self->_slice_adaptor->fetch_by_Feature( $TF ) if $TF;
    };
    if( $TS ) {
      $self->param('db', $db );
      return $self->_create_from_slice( 'Transcript', $TF->stable_id, $self->expand($TS), $ID );
    }
  }
  foreach my $db ( @dbs ) {
    my @features = grep { $_->translation } @{$self->_transcript_adaptor( $db )->fetch_all_by_external_name( $ID )};
    if(@features) {
      $TS = $self->_slice_adaptor->fetch_by_Feature( $features[0] );
      if( $TS ) {
        $self->param('db', $db );
        return $self->_create_from_slice( 'Transcript', $features[0]->stable_id, $self->expand($TS), $ID );
      }
    }
  }
  $self->problem( "fatal", "Unknown peptide", $self->_help( "Could not find peptide $ID" ) );
  return undef;
}

sub _location_from_MiscFeature {
  my( $self, $ID ) = @_;
  my $TS;
  foreach my $type ( qw(name embl_acc synonym clone_name sanger_project well_name clonename) ) {
    eval { $TS = $self->_slice_adaptor->fetch_by_misc_feature_attribute( $type, $ID ); };
    return $self->_create_from_slice( "MiscFeature", $ID, $self->expand($TS) ) if $TS;
  }
  $self->problem( "fatal", "Unknown misc feature", $self->_help( "Could not find misc feature $ID" ) );
  return undef;

}

sub _location_from_Band {
  my( $self, $ID, $chr ) = @_;
  my $TS;
  eval { $TS= $self->_slice_adaptor->fetch_by_chr_band( $chr, $ID ); };
  $self->problem( "fatal", "Unknown band", $self->_help( "Could not find karyotype band $ID on chromosome $chr" ) ) if $@;
  return $self->_create_from_slice( 'Band', $ID, $self->expand($TS), "$chr $ID" );

}

sub _location_from_Variation {
  my( $self, $ID ) = @_;
  my $v;
  eval {
    $v = $self->_variation_adaptor->fetch_by_name( $ID );
  };
  if($@ || !$v ) {
    $self->problem( "fatal", "Invalid SNP ID", $self->_help( "SNP $ID cannot be located within Ensembl" ) );
    return;
  }
  foreach my $vf (@{$self->_variation_feature_adaptor->fetch_all_by_Variation( $v )}) {
    if( $vf->seq_region_name ) {
      my $TS;
      eval { $TS = $self->_slice_adaptor->fetch_by_region( undef, $vf->seq_region_name, $vf->seq_region_start, $vf->seq_region_end ); };
      return $self->_create_from_slice( 'SNP', $ID, $self->expand($TS) ) if $TS;
    }
  }
  $self->problem( "fatal", "Non-mapped SNP", $self->_help( "SNP $ID is in Ensembl, but not mapped to the current assembly" ) );
}

sub _location_from_Marker {
  my( $self, $ID, $chr  ) = @_;
  my $mr;
  eval {
    $mr = $self->_marker_adaptor->fetch_all_by_synonym($ID);
  };
  if($@){
    $self->problem( "fatal", "Invalid Marker ID", $self->_help( "Marker $ID cannot be located within Ensembl" ) );
    return;
  }
  my $region;
  foreach my $marker_obj (@{$self->_marker_adaptor->fetch_all_by_synonym($ID)}) {
    my $mfeats = $marker_obj->get_all_MarkerFeatures;
    if(@$mfeats) {
      foreach my $mf (@$mfeats){
        my $TS = $self->_slice_adaptor->fetch_by_Feature( $mf );
        my $projection = $TS->project( $self->__level );
        next unless @$projection;
        my $projslice = shift @$projection;  # take first element of projection...
        $region    = $projslice->to_Slice->seq_region_name;
        if( $region eq $chr || !$chr ) {
          return $self->_create_from_slice("Marker", $mf->display_id, $self->expand($TS));
        }
      }
    }
  }
  if( $region ) {
    $self->problem( "fatal", "Marker not found on Chromosome", $self->_help( "Marker $ID is not mapped to chromosome $chr" ) );
    return undef;
  } else {
    $self->problem(  "fatal", "Marker not found on assembly", $self->_help( "Marker $ID is not mapped to the current assembly" ) );
    return undef;
  }
}

sub _location_from_SeqRegion {
  my( $self, $chr, $start, $end, $strand, $keep_slice ) = @_;

  if( defined $start ) {
    $start = floor( $start );
    $end   = $start unless defined $end;
    $end   = floor( $end );
    $end   = 1 if $end < 1;
    $strand ||= 1;
    $start = 1 if $start < 1;     ## Truncate slice to start of seq region
    ($start,$end) = ($end, $start) if $start > $end;

    foreach my $system ( @{$self->__coord_systems} ) {
      my $slice;
      eval { $slice = $self->_slice_adaptor->fetch_by_region( $system->name, $chr, $start, $end, $strand ); };

      warn $@ if $@;
      next if $@;
#      warn "found a slice";
      if( $slice ) {
        if( $start >  $slice->seq_region_length || $end >  $slice->seq_region_length ) {
          $start = $slice->seq_region_length if $start > $slice->seq_region_length;
          $end   = $slice->seq_region_length if $end   > $slice->seq_region_length;
          $slice = $self->_slice_adaptor->fetch_by_region( $system->name, $chr, $start, $end, $strand );
        }
        return $self->_create_from_slice( $system->name, "$chr $start-$end ($strand)", $slice, undef, undef, $keep_slice );
      }
    }
    $self->problem( "fatal", "Locate error", $self->_help( "Cannot locate region $chr: $start - $end on the current assembly." ));
    return undef;
  } else {
    foreach my $system ( @{$self->__coord_systems} ) {
      my $TS;
      eval { $TS = $self->_slice_adaptor->fetch_by_region( $system->name, $chr ); };
      next if $@;
      if( $TS ) {
        return $self->_create_from_slice( $system->name , $chr, $self->expand($TS), '', $chr, $keep_slice );
      }
    }
    my $action = $ENV{'ENSEMBL_ACTION'};
    if( $chr ) {
      $self->problem( "fatal", "Locate error", $self->_help( "Cannot locate region $chr on the current assembly." ) );
    } elsif ($action && $action eq 'Genome' && $self->species_defs->ENSEMBL_CHROMOSOMES) {
      ## Create a slice of the first chromosome to force this page to work!
      my @chrs = @{$self->species_defs->ENSEMBL_CHROMOSOMES};
      my $TS;
      if (scalar(@chrs)) {
        $TS = $self->_slice_adaptor->fetch_by_region( 'chromosome', $chrs[0] );
      }
      if ($TS) {
        return $self->_create_from_slice( 'chromosome', $chrs[0], $self->expand($TS), '', $chrs[0], $keep_slice );
      }
    } else {
      ## Might need factoring out if we use other methods to get a location (e.g. marker)
      $self->problem( "fatal", "Please enter a location", $self->_help('A location is required to build this page') );
    }
    return undef;
  }
}

sub expand {
  my( $self, $slice ) = @_;
  return $slice->expand( $self->param('context'), $self->param('context') );
}

# use EnsEMBL::Web::URLfeatureParser;
# sub _location_from_URL {
#  my( $self, $URL ) = @_;
#  return unless $URL;
#  my $P = new EnsEMBL::Web::URLfeatureParser( $self->species_defs, $self->param( 'data_URL' ) );
#  $P->parse_URL;
#  ( my $T = $P->{'browser_switches'}->{'position'} ) =~ s/^chr//;
#  my($chr,$start,$sep,$end) = $T =~/^(.*?):(.*?)(-|\.\.|,)(.*)/;
#  return unless $chr || $start || $end;
#  $self->_location_from_SeqRegion( $chr, $start, $end );
#}

#----------------- Create objects ----------------------------------------------

sub fastCreateObjects {
  my $self = shift;
## Only takes one set of parameters... and this has additional 
## useful information included...
## /Homo_sapiens/fragment/contigviewbottom?l=chr:st-end;strand=1;type=chromosome
  $self->get_databases($self->__gene_databases, 'compara', 'blast');
 warn "\n\n\n\nFCO: (", $self->param('l'),')';
  if( $self->param('l') =~ /^([-\w\.]+):(-?\d+)-(\d+)$/) {
eval {
    my $seq_region         = $1;
    my $start              = $2;
    my $end                = $3;
    my $strand             = $self->param('strand') || 1;
    my $seq_region_type    = $self->param('type');
    my $slice = $self->_slice_adaptor()->fetch_by_region( undef, $seq_region, $start, $end, $strand );
    my $seq_region_length  = $self->param('srlen');
    my $data = EnsEMBL::Web::Proxy::Object->new( 'Location', {
      'type'               => "Location",
      'real_species'       => $self->__species,
      'name'               => $seq_region,
      'seq_region_name'    => $seq_region,
      'seq_region_type'    => $slice->coord_system->name,
      'seq_region_start'   => $start,
      'seq_region_end'     => $end,
      'seq_region_strand'  => $strand,
      'raw_feature_strand' => $strand,
      'seq_region_length'  => $slice->seq_region_length
    },$self->__data);
    $data->attach_slice( $slice );
warn "ATTACHING DATA OBJECT........";
    $self->DataObjects( $data );
}; warn "FCO eval $@";
  }
}

sub _create_object_from_core {
  my $self = shift;
  my $l = $self->core_objects->location;
  my $data = undef;
  if( $l->isa( 'EnsEMBL::Web::Fake' ) ) {
    $data = EnsEMBL::Web::Proxy::Object->new( 'Location', {
        'type' => 'Genome',
        'real_species' => $self->__species
      },
      $self->__data
    );
  } else {
    $data = EnsEMBL::Web::Proxy::Object->new( 'Location', {
      'type' => 'Location',
      'real_species'     => $self->__species,
      'name'             => $l->seq_region_name,
      'seq_region_name'  => $l->seq_region_name,
      'seq_region_start' => $l->start,
      'seq_region_end'    => $l->end,
      'seq_region_strand' => 1,
      'seq_region_type'   => $l->coord_system->name,
      'raw_feature_strand' => 1,
      'seq_region_length' => $l->seq_region_length,
      }, $self->__data
    );
    $data->attach_slice( $l );
  }
    ## Add a slice consisting of the whole chromosome
#    my $chr = $self->_slice_adaptor()->fetch_by_region( undef, $l->seq_region_name);

  $self->DataObjects($data);
  return 'from core';
}

sub createObjectsGene {
  my $self = shift;
  my @locations = ( $self->_location_from_Gene( $self->param('gene') ) ); ## Assume these are core genes at the moment

  foreach my $par ( $self->param ) {
    if( $par =~ /^s(\d+)$/ ) {
      my $ID = $1;
      my $species = $self->map_alias_to_species( $self->param($par) );
      $self->__set_species( $species );
      $self->databases_species( $species, 'core', 'compara' );
      $locations[$ID] = $self->_location_from_Gene( $self->param("g$ID") );
    }
  }
  my $TO = $self->new_MultipleLocation( grep {$_} @locations );
  foreach my $par ( $self->param ) { 
    $TO->highlights( $self->param($par) ) if $par =~ /^g(\d+|ene)$/;
  }
  $self->DataObjects( $TO );
}


sub _create_from_slice {
  my( $self, $type, $ID, $slice, $synonym, $real_chr, $keep_slice ) = @_;
#  warn "Finally, creating the slice - $type, $ID, $slice, $synonym, $real_chr, $keep_slice";
  return $self->problem( 
    "fatal",
    "Ensembl Error",
    "Cannot create slice - $type $ID does not exist"
  ) unless $slice;
  my $projection = $slice->project( $self->__level );
  return $self->problem(
    "fatal",
    "Cannot map slice",
    "must all be in gaps"
  ) unless @$projection;
  my $projslice = shift @$projection; # take first element!!
  my $start  = $projslice->[2]->start;
  my $end    = $projslice->[2]->end;
  my $region = $projslice->[2]->seq_region_name;
  foreach( @$projection ) {    # take all other elements in case something has gone wrong....
    return $self->problem(
      'fatal',
      "Slice does not map to single ".$self->__level,
      "end and start on different seq regions"
    ) unless $_->[2]->seq_region_name eq $region;
    $start = $_->[2]->start if $_->[2]->start < $start;
    $end   = $_->[2]->end   if $_->[2]->end   > $end;
  }
  my $TS = $projslice->[2];
  if( $TS->seq_region_name ne $real_chr ) {
    my $feat = new Bio::EnsEMBL::Feature(-start   => 1, -end => $TS->length, -strand  => 1, -slice   => $TS );
    my $altlocs = $feat->get_all_alt_locations( 1 );
    foreach my $f (@{$altlocs||[]}) {
      if( $f->seq_region_name eq $real_chr ) {
        $TS =  $f->{'slice'} if $f->seq_region_name;
        last;
      }
    }
  }
  my $transcript = $self->core_objects->transcript;
  my $gene       = $self->core_objects->gene;
  my $db         = $self->core_objects->{'parameters'}{'db'};
  my $tid        = $transcript ? $transcript->stable_id : undef;
  my $gid        = $gene       ? $gene->stable_id : undef;
  if( $type eq 'Transcript' ) {
    $tid = $ID;
    $gid = undef;
    $db  = $self->param('db');
  } elsif( $type eq 'Gene' ) {
    $tid = undef;
    $gid = $ID;
    $db  = $self->param('db');
  } else {
    if( $gene && $gene->seq_region_name ne $TS->seq_region_name ) {
      $tid = undef;
      $gid = undef;
    }
  }

  my $pars = {
    'r' => $TS->seq_region_name.':'.$start.'-'.$end,
    't' => $tid, 'g' => $gid, 'db' => $db
  };
  return $self->problem( 'redirect', $self->_url($pars));
}

sub merge {
  my $self = shift;
  my( $chr, $start, $end, $species, $type, $strand, $srlen );
  foreach my $o ( @{$self->DataObjects||[]} ) {
    next unless $o;
    $species ||= $o->real_species;
    $chr     ||= $o->seq_region_name;
    $type    ||= $o->seq_region_type;
    $strand  ||= $o->seq_region_strand;
    $start   ||= $o->seq_region_start;
    $end     ||= $o->seq_region_end;
    $srlen   ||= $o->seq_region_length;
    if( $chr ne $o->seq_region_name || $species ne $o->species ) {
      return $self->problem( 'multi_chromosome', 'Not on same seq region', 'Not all features on same seq region' );
    }
    $start = $o->seq_region_start if $o->seq_region_start < $start;
    $end   = $o->seq_region_end   if $o->seq_region_end   > $end;
  }
  $start -= $self->param('upstream') || 0;
  $end   += $self->param('downstream') || 0;
  $self->clearDataObjects();
  $self->DataObjects( EnsEMBL::Web::Proxy::Object->new( 'Location', {
    'type'              => 'merge',
    'name'              => 'merge',
    'real_species'      => $species,
    'seq_region_name'   => $chr,
    'seq_region_type'   => $type,
    'seq_region_start'  => floor( $start ),
    'seq_region_end'    => ceil(  $end   ),
    'seq_region_strand' => $strand,
    'highlights'         => join( '|', $self->param('h'), $self->param('highlights') ),
    'seq_region_length' => $srlen}, 
    $self->__data ));
}


#------------------------------------------------------------------------------

sub _variation_adaptor {
  my $self = shift;
  return $self->__species_hash->{'adaptors'}{'variation'} ||=
    $self->database('variation',$self->__species)->get_VariationAdaptor();
}
sub _variation_feature_adaptor {
  my $self = shift;
  return $self->__species_hash->{'adaptors'}{'variation_feature'} ||=
    $self->database('variation',$self->__species)->get_VariationFeatureAdaptor();
}
sub _coord_system_adaptor {
  my $self = shift;
  return $self->__species_hash->{'adaptors'}{'coord_system'} ||=
    $self->database('core',$self->__species)->get_CoordSystemAdaptor();
}
sub _slice_adaptor {
  my $self = shift;
  return $self->__species_hash->{'adaptors'}{'slice'} ||=
    $self->database('core',$self->__species)->get_SliceAdaptor();
}
sub _gene_adaptor {
  my $self = shift;
  my $db   = shift || 'core';
  return $self->__species_hash->{'adaptors'}{"gene_$db"} ||=
    $self->database($db,$self->__species)->get_GeneAdaptor();
}
sub _predtranscript_adaptor {
  my $self = shift;
  my $db   = shift || 'core';
  return $self->__species_hash->{'adaptors'}{"predtranscript_$db"} ||=
    $self->database($db,$self->__species)->get_PredictionTranscriptAdaptor();
}
sub _transcript_adaptor {
  my $self = shift;
  my $db   = shift || 'core';
  return $self->__species_hash->{'adaptors'}{"transcript_$db"} ||=
    $self->database($db,$self->__species)->get_TranscriptAdaptor();
}
sub _exon_adaptor {
  my $self = shift;
  my $db   = shift || 'core';
  return $self->__species_hash->{'adaptors'}{"exon_$db"} ||=
    $self->database($db,$self->__species)->get_ExonAdaptor();
}
sub _marker_adaptor {
  my $self = shift;
  return $self->__species_hash->{'adaptors'}{'marker'} ||=
    $self->database('core',$self->__species)->get_MarkerAdaptor();
}

1;
  
