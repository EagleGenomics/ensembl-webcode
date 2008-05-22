package EnsEMBL::Web::Data::Group;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::UserDBConnection (__PACKAGE__->species_defs);


__PACKAGE__->table('webgroup');
__PACKAGE__->set_primary_key('webgroup_id');

__PACKAGE__->add_queriable_fields(
  name   => 'text',
  blurb  => 'text',
  type   => "enum('open','restricted','private')",
  status => "enum('active','inactive')",
);

__PACKAGE__->add_has_many(
  bookmarks      => 'EnsEMBL::Web::Data::Record::Bookmark',
  configurations => 'EnsEMBL::Web::Data::Record::Configuration',
  annotations    => 'EnsEMBL::Web::Data::Record::Annotation',
  dases          => 'EnsEMBL::Web::Data::Record::DAS',
  invites        => 'EnsEMBL::Web::Data::Record::Invite',
);

__PACKAGE__->has_many(members => 'EnsEMBL::Web::Data::Membership');


sub find_user_by_user_id {
  my ($self, $user_id) = @_;
  my ($user) = $self->members(user_id => $user_id);
  return $user;
}

sub assign_status_to_user {
  my ($self, $user_id, $status) = @_;
  ## TODO: Error exception!
  if (my $user = $self->find_user_by_user_id($user_id)) {
    $user->member_status($status);
    $user->save;
  }
}

sub assign_level_to_user {
  my ($self, $user_id, $level) = @_;
  ## TODO: Error exception!
  if (my $user = $self->find_user_by_user_id($user_id)) {
    $user->level($level);
    $user->save;
  }
}

sub add_user {
  my $self   = shift;
  my %args = (
    level  => 'member',
    status => 'active',
    ref($_[0])
      ? (user => $_[0])
      : @_,
  );

  return $self->add_to_members({
    user_id       => $args{user}->id,
    level         => $args{level},
    member_status => $args{member_status} || $args{status},
  });
}



###################################################################################################
##
## Cache related stuff
##
###################################################################################################

sub invalidate_cache {
  my $self = shift;
  $self->SUPER::invalidate_cache('group['.$self->id.']');
}

sub propagate_cache_tags {
  my $self = shift;
  $self->SUPER::propagate_cache_tags('group['.$self->id.']')
    if ref $self;
}

1;