package EnsEMBL::Web::Controller::Command::User;

use strict;
use warnings;

use base 'EnsEMBL::Web::Controller::Command';

sub user_or_admin {
  ### Chooses correct filter for shareable records, based on whether user or group record
  my ($self, $class, $id, $owner) = @_;
    if ($owner eq 'group') {
      $class =~ s/^(.+)::(\w+)$/$1::Group::$2/;
      my $record = $class->new($id);
      $self->add_filter(
        'EnsEMBL::Web::Controller::Command::Filter::Admin',
        {'group_id' => $record->webgroup_id}
      ) if $record;

    } else {

      $class =~ s/^(.+)::(\w+)$/$1::User::$2/;
      my $record = $class->new($id);
      $self->add_filter(
        'EnsEMBL::Web::Controller::Command::Filter::Owner',
        {'user_id' => $record->user->id}
      ) if $record;

    }
}

sub add_member_from_invitation {
  my ($self, $user, $invitation) = @_;

  return EnsEMBL::Web::Data::Group->new($invitation->webgroup_id)->add_user($user);
}


1;
