package EnsEMBL::Web::Factory::Location;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use Bio::EnsEMBL::Feature;

our @ISA = qw(  EnsEMBL::Web::Factory );
use POSIX qw(floor ceil);
  
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

sub __species       :lvalue { $_[0]->__data->{'__location'}{'species'}; }
sub __species_hash  :lvalue { $_[0]->__data->{'__location'}{$_[0]->__data->{'__location'}{'species'}}; }
sub __level         :lvalue { $_[0]->__species_hash->{'level'};         }
sub __golden_path   :lvalue { $_[0]->__species_hash->{'golden_path'};   }
sub __coord_systems :lvalue { $_[0]->__species_hash->{'coord_systems'}; }

#------------------- Location by feature type ------------------------------

sub __gene_databases {
  my $self = shift;
  my @return = ('core');
  push @return, 'vega' if $self->species_defs->databases->{ 'ENSEMBL_VEGA' };
  push @return, 'est' if $self->species_defs->databases->{ 'ENSEMBL_EST' };
  return @return;
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
  $self->problem( "fatal", "Unknown gene", "Could not find gene $ID" );
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

  $self->problem( "fatal", "Unknown transcript", "Could not find transcript $ID" );
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
  $self->problem( "fatal", "Unknown exon", "Could not find exon $ID" );
  return undef;
}

sub _location_from_Peptide {
  my( $self, $ID ) = @_;
  my $TS;
## Lets get the transcript....
  my @dbs = $self->__gene_databases;
  foreach my $db ( @dbs ) {
    eval {
      my $TF = $self->_transcript_adaptor( $db )->fetch_by_translation_stable_id( $ID );
      $TS = $self->_slice_adaptor->fetch_by_Feature( $TF ) if $TF;
    };
    if( $TS ) {
      $self->param('db', $db );
      return $self->_create_from_slice( 'Translation', $ID, $self->expand($TS), $ID );
    }
  }
  foreach my $db ( @dbs ) {
    my @features = grep { $_->translation } @{$self->_transcript_adaptor( $db )->fetch_all_by_external_name( $ID )};
    if(@features) {
      $TS = $self->_slice_adaptor->fetch_by_Feature( $features[0] );
      if( $TS ) {
        $self->param('db', $db );
        return $self->_create_from_slice( 'Translation', $features[0]->translation->stable_id, $self->expand($TS), $ID );
      }
    }
  }
  $self->problem( "fatal", "Unknown peptide", "Could not find peptide $ID" );
  return undef;
}

sub _location_from_MiscFeature {
  my( $self, $ID ) = @_;
  my $TS;
  foreach my $type ( qw(name embl_acc synonym clone_name sanger_project) ) {
    eval { $TS = $self->_slice_adaptor->fetch_by_misc_feature_attribute( $type, $ID ); };
    return $self->_create_from_slice( "MiscFeature", $ID, $self->expand($TS) ) if $TS;
  }
  $self->problem( "fatal", "Unknown misc feature", "Could not find misc feature $ID" );
  return undef;

}

sub _location_from_Band {
  my( $self, $ID, $chr ) = @_;
  my $TS;
  eval { $TS= $self->_slice_adaptor->fetch_by_chr_band( $chr, $ID ); };
  $self->problem( "fatal", "Unknown band", "Could not find karyotype band $ID on chromosome $chr" ) if $@;
  return $self->_create_from_slice( 'Band', $ID, $self->expand($TS), "$chr $ID" );

}

sub _location_from_Variation {
  my( $self, $ID ) = @_;
  my $v;
  eval {
    $v = $self->_variation_adaptor->fetch_by_name( $ID );
  };
  if($@ || !$v ) {
    $self->problem( "fatal", "Invalid SNP ID", "SNP $ID cannot be located within Ensembl" );
    return;
  }
  foreach my $vf (@{$self->_variation_feature_adaptor->fetch_all_by_Variation( $v )}) {
    if( $vf->seq_region_name ) {
      my $TS;
      eval { $TS = $self->_slice_adaptor->fetch_by_region( undef, $vf->seq_region_name, $vf->seq_region_start, $vf->seq_region_end ); };
      return $self->_create_from_slice( 'SNP', $ID, $self->expand($TS) ) if $TS;
    }
  }
  $self->problem( "fatal", "Non-mapped SNP", "SNP $ID is in Ensembl, but not mapped to the current assembly" );
}

sub _location_from_Marker {
  my( $self, $ID, $chr  ) = @_;
  my $mr;
  eval {
    $mr = $self->_marker_adaptor->fetch_all_by_synonym($ID);
  };
  if($@){
    $self->problem( "fatal", "Invalid Marker ID", "Marker $ID cannot be located within Ensembl" );
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
    $self->problem( "fatal", "Marker not found on Chromosome", "Marker $ID is not mapped to chromosome $chr" );
    return undef;
  } else {
    $self->problem(  "fatal", "Marker not found on assembly", "Marker $ID is not mapped to the current assembly" );
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
      if( $slice ) {
        if( $start >  $slice->seq_region_length || $end >  $slice->seq_region_length ) {
          $start = $slice->seq_region_length if $start > $slice->seq_region_length;
          $end   = $slice->seq_region_length if $end   > $slice->seq_region_length;
          $slice = $self->_slice_adaptor->fetch_by_region( $system->name, $chr, $start, $end, $strand );
        }
        return $self->_create_from_slice( $system->name, "$chr $start-$end ($strand)", $slice, undef, undef, $keep_slice );
      }
    }
    $self->problem( "fatal", "Locate error","Cannot locate region $chr: $start - $end on the current assembly." );
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
    $self->problem( "fatal", "Locate error","Cannot locate region $chr on the current assembly." );
    return undef;
  }
}

sub expand {
  my( $self, $slice ) = @_;
  return $slice->expand( $self->param('context'), $self->param('context') );
}

use EnsEMBL::Web::URLfeatureParser;
sub _location_from_URL {
  my( $self, $URL ) = @_;
  return unless $URL;
  my $P = new EnsEMBL::Web::URLfeatureParser( $self->species_defs, $self->param( 'data_URL' ) );
  $P->parse_URL;
  ( my $T = $P->{'browser_switches'}->{'position'} ) =~ s/^chr//;
  my($chr,$start,$end) = $T =~/^(.*?):(.*?)-(.*)/;
  return unless $chr || $start || $end;
  $self->_location_from_SeqRegion( $chr, $start, $end );
}

#----------------- Create objects ----------------------------------------------

sub createObjects { 
  my $self      = shift;    
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
  if( defined $self->param('l') ) {
    ($seq_region,$start,$end) = $self->param('l') =~ /^([-\w\.]+):(-?[\.\w]+)-([\.\w]+)$/;
    $start = $self->evaluate_bp($start);
    $end   = $self->evaluate_bp($end);
  } 
  $start = $self->evaluate_bp( $start ) if defined $start;
  $end   = $self->evaluate_bp( $end )   if defined $end;
  if( defined $self->param( 'data_URL' ) ) {
    my $loc = $self->_location_from_URL( $self->param( 'data_URL' ) );
    if($loc) {
      $self->DataObjects( $loc );
      return;
    }
    $self->clear_problems(); 
  }
  if( defined $self->param('c') ) {
    my($cp,$t_strand);
    ($seq_region,$cp,$t_strand) = $self->param('c') =~ /^([-\w\.]+):(-?[.\w]+)(:-?1)?$/;
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
      my( $ftype, $temp_id ) = @$O;
      if( $ftype eq 'gene' ) {
        $location = $self->_location_from_Gene( $temp_id );
      } elsif( $ftype eq 'transcript' ) { 
        $location = $self->_location_from_Transcript( $temp_id );
      } elsif( $ftype eq 'peptide' ) { 
        $location = $self->_location_from_Peptide( $temp_id );
      } elsif( $ftype eq 'marker' ) {
        $location = $self->_location_from_Marker( $temp_id, $seq_region );
      } elsif( $ftype eq 'band' ) {
        $location = $self->_location_from_Band( $temp_id, $seq_region );
      } elsif( $ftype eq 'region' ) {
        $location = $self->_location_from_SeqRegion( $temp_id );
      } else {
        $location = $self->_location_from_SeqRegion( $seq_region, $temp_id, $temp_id );
      }
      $self->DataObjects( $location ) if $location;
    }
    if( $self->DataObjects ) {
      $self->merge;
    } else {
      return $self->problem( 'Fatal',
        'Unknown region',
        'Could not location the region you have specified -OR- you have not specified enough information'
      );
    }
  } else {
    ## Gene (completed)
    if($temp_id = $self->param('geneid') || $self->param('gene')) {
      $location = $self->_location_from_Gene( $temp_id );
    ## Transcript (completed)
    } elsif( $temp_id = $self->param('transid') || $self->param('trans') || $self->param('transcript') ) {
      $location = $self->_location_from_Transcript( $temp_id );
    } elsif( $temp_id = $self->param('exonid') || $self->param('exon') ) {  
      $location = $self->_location_from_Exon( $temp_id );
    ## Translation (completed)
    } elsif( $temp_id = $self->param('peptide') || $self->param('pepid') || $self->param('peptideid') || $self->param('translation') ) {
      $location = $self->_location_from_Peptide( $temp_id );
    ## MiscFeature (completed)
    } elsif( $temp_id = $self->param('mapfrag') || $self->param('miscfeature') ) {
        $location = $self->_location_from_MiscFeature( $temp_id );
    ## Marker (completed)
    } elsif( $temp_id = $self->param('marker') ) { 
        $location = $self->_location_from_Marker( $temp_id, $seq_region );
    ## Band (completed)
    } elsif( $temp_id = $self->param('band') ) { 
        $location = $self->_location_from_Band( $temp_id, $seq_region );
    } elsif( !$start && ($temp_id = $self->param('snp')||$self->param('variation')) ) { 
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
      } else {
        $location = $self->_location_from_SeqRegion( $seq_region, $start, $end, $strand );
      }
    }
    if( $self->param( 'data_URL' ) ) {
      my $newloc   = $self->_location_from_URL();
      $location = $newloc if $newloc;
    }
    if( $location ) {
      $self->DataObjects( $location );
    } else {
      return $self->problem( 'Fatal', 'Unknown region', 'Could not location the region you have specified -OR- you have not specified enough information' );
    }
  }
## Push location....
}

sub _create_from_slice {
  my( $self, $type, $ID, $slice, $synonym, $real_chr, $keep_slice ) = @_;
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
  my $data = EnsEMBL::Web::Proxy::Object->new( 
    'Location',
    {
      'type'               => $type,
      'real_species'       => $self->__species,
      'name'               => $ID,
      'seq_region_name'    => $TS->seq_region_name,
      'seq_region_type'    => $TS->coord_system->name(),
      'seq_region_start'   => $start,
      'seq_region_end'     => $end,
      'seq_region_strand'  => $TS->strand,
      'raw_feature_strand' => $slice->{'_raw_feature_strand'} * $TS->strand * $slice->strand,
      'seq_region_length'  => $TS->seq_region_length,
      'synonym'            => $synonym,
    },
    $self->__data
  );
  $data->highlights( $ID, $synonym ) if defined $synonym;
  $data->attach_slice( $TS ) if $keep_slice;
  return $data;
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

sub _predtranscript_adaptor {
  my $self = shift;
  my $db   = shift || 'core';
  return $self->__species_hash->{'adaptors'}{"predtranscript_$db"} ||=
    $self->database($db,$self->__species)->get_PredictionTranscriptAdaptor();
}

1;
  
