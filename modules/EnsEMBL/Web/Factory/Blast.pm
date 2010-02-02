package EnsEMBL::Web::Factory::Blast;

use strict;
use warnings;
no warnings 'uninitialized';
use base qw(EnsEMBL::Web::Factory);

sub blast_adaptor {
  my $self = shift;
  my $sp = shift || $self->species_defs->ENSEMBL_PRIMARY_SPECIES;
  my $blast_adaptor; 

  eval {
    $blast_adaptor = $self->DBConnection->get_databases_species( $sp, 'blast' )->{'blast'};
  };

  $blast_adaptor && return $blast_adaptor;

  # Still here? Something gone wrong!
  my $err = "Can not connect to blast database...";
  warn( "$err: $@" );

}

sub createObjects {   
  my $self = shift;    

  ## Create a very lightweight object, as the data required for a blast page is very variable
  $self->DataObjects($self->new_object(
    'Blast', {
      'tickets'    => undef,
      'adaptor'   => $self->blast_adaptor,
    }, $self->__data));

}

1;
