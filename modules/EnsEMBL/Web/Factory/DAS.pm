package EnsEMBL::Web::Factory::DAS;

use strict;
use warnings;

use EnsEMBL::Web::Factory::Location;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(  EnsEMBL::Web::Factory::Location );
use POSIX qw(floor ceil);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );
  return $self; 
}

#----------------- Create objects ----------------------------------------------
## Create objects looks for a series of parameters passed to the script:
## (1) Primary slice: c = sr:start:ori; w = width
##                     srr = ?; cr = ?; cl = ?; srs = ?; srn = ?; srl = ?; srw = ?; c.x = ?
## (2) Alternate slices:
##                     s{n} = species; [c{n} = sr:start:ori; w{n};] 
##               -or-  s{n} = species; [sr{n} = sr;]
## OR
##
## (1) Primary slice: gene = gene;
## (2) Alternate slices:
##                     s{n} = species; g{n} = gene; 

sub featureTypes {
  my $self = shift;
  push @{$self->{'data'}{'_feature_types'}}, @_ if @_;
  return $self->{'data'}{'_feature_types'};
}

sub createObjects { 
  my $self      = shift;    
  $self->get_databases('core');
  my $database  = $self->database('core');
  return $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ) unless $database;

  my @locations;

  if( my @segments = $self->param('segment')) {
      foreach my $segment (grep { $_ } @segments) {
	  if ($segment =~ /^([-\w\.]+):(-?[\.\w]+),([\.\w]+)$/ ) {
	      my($sr,$start,$end) = ($1,$2,$3);
	      $start = $self->evaluate_bp($start);
	      $end   = $self->evaluate_bp($end);
	      if (my $loc = $self->_location_from_SeqRegion( $sr,$start,$end,1,1)) {
#		  warn(Data::Dumper::Dumper($loc));

		  push @locations, $loc;
	      } else {
		  push @locations, {
		      'REGION' => $sr,
		      'START' => $start,
		      'STOP' => $end,
		      'TYPE' => 'ERROR'
		      };

	      }
	  } else {
	      if (my $loc = $self->_location_from_SeqRegion( $segment,undef,undef,1,1)) {
		  push @locations, $loc;
	      } else {
		  push @locations, {
		      'REGION' => $segment,
		      'START' => '',
		      'STOP' => '',
		      'TYPE' => 'ERROR'
		      };
	      }
	  }
      }
  }
  $self->clear_problems();

  my @feature_types = $self->param('type');

  $self->featureTypes(@feature_types);
  my $source = $ENV{ENSEMBL_DAS_TYPE};

  
  my $T = EnsEMBL::Web::Proxy::Object->new( "DAS::$source", \@locations, $self->__data );
  if ($self->has_a_problem) {
      $self->clear_problems();
      return $self->problem( 'Fatal', 'Unknown Source', "Could not locate source <b>$source</b>." );
  }

  $self->DataObjects( $T );

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
	    next;
        }
        return $self->_create_from_slice( $system->name, "$chr\:$start,$end", $slice, undef, undef, $keep_slice );
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
    if ($chr) {
      $self->problem( "fatal", "Locate error","Cannot locate region $chr on the current assembly." );
    }
    else {
    $self->problem( "fatal", "Please enter a location","A location is required to build this page." );
  }
    return undef;
  }
}

1;
