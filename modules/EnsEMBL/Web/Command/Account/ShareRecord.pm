package EnsEMBL::Web::Command::Account::ShareRecord;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Group;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;

  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;

  my ($records_accessor) = grep { $_ eq $accessor } keys %{ $user->relations };
  ## TODO: this should use abstraction limiting facility rather then grep

  my ($user_record) = $user->records($object->param('id'));
  my $group = EnsEMBL::Web::Data::Group->new($object->param('webgroup_id'));

  if ($user_record && $group) {
    my $clone = $user_record->clone;
    $clone->owner($group);
    $clone->save;
  }
  #else {
  #  ## TODO: error exception
  #}

  my $url;
  my $param = {
    'id' => $group->id,
    '_referer' => $object->param('_referer'),
    'x_requested_with' => $object->param('x_requested_with'),
  };
  if ($user->is_administrator_of($group)) {
    $url = '/Account/Group/List';
  }
  else {
    $url = '/Account/MemberGroups';
  } 
 
  if ($object->param('x_requested_with')) {
    $self->ajax_redirect($url, $param);
  }
  else {
    $object->redirect($url, $param);
  }
}

}

1;
