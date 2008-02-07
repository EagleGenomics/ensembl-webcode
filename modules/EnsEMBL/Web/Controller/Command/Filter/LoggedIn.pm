package EnsEMBL::Web::Controller::Command::Filter::LoggedIn;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Registry;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

sub allow {
  my $self = shift;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  return 1 if $user;
  #my $previous = $self->SUPER::allow(); 
  return 0;
}

sub message {
  my $self = shift;
  return "You must be logged in to view this page.";
}

sub inherit {
  my ($self, $parent) = @_;
  unshift @ISA, ref $parent;
  return 1;
}

}

1;
