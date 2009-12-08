package EnsEMBL::Web::Command::Account::ResetFavourites;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $user   = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  $user->specieslists->destroy;

  $self->ajax_redirect($ENV{'ENSEMBL_BASE_URL'});
}

1;
