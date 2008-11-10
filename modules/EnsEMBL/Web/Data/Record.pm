package EnsEMBL::Web::Data::Record;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::UserDBConnection (__PACKAGE__->species_defs);


###################################################################################################
##
## Record is always owned by someone (user or group so far)
## Below is some functions related to this matter
##
###################################################################################################

sub owner {
  my $class = shift;
  my $owner = lc(shift);
    no strict 'refs';
    
    if ($owner eq 'user') {
      $class->table($class->species_defs->ENSEMBL_USER_DATA_TABLE);
      $class->set_primary_key($class->species_defs->ENSEMBL_USER_DATA_TABLE.'_id');
      $class->has_a(user => 'EnsEMBL::Web::Data::User');
      *{ "$class\::owner_type" } = sub { return 'user' };
    } elsif ($owner eq 'group') {
      $class->table($class->species_defs->ENSEMBL_GROUP_DATA_TABLE);
      $class->set_primary_key($class->species_defs->ENSEMBL_GROUP_DATA_TABLE.'_id');
      $class->has_a(webgroup => 'EnsEMBL::Web::Data::Group');
      *{ "$class\::owner_type" } = sub { return 'group' };
      *{ "$class\::group" }      = sub { return shift->webgroup(@_) };
    }

}

sub add_owner {
  my $class = shift;
  my $owner = shift;
  my $relation_class = $class .'::'. ucfirst($owner);
  
  my $package = "package $relation_class;
                use base qw($class);
                $relation_class->owner('$owner');
                1;";
  eval $package;
  die "Compilation error: $@" if $@;
  
  return $relation_class;
}

## used for making shared records between users and groups
sub clone {
  my $self = shift;
  my %hash = map { $_ => $self->$_ } keys %{ $self->get_all_fields };
  delete $hash{user_id};
  return \%hash;
}


###################################################################################################
##
## Cache related stuff
##
###################################################################################################

sub propagate_cache_tags {
  my $proto = shift;

  $proto->SUPER::propagate_cache_tags($proto->__type);
}


sub invalidate_cache {
  my $self  = shift;
  my $cache = shift;

  my $owner_type = $self->owner_type;
  my $owner = $self->$owner_type;

  $self->SUPER::invalidate_cache($cache, "${owner_type}[$owner]", $self->type);
}

1;