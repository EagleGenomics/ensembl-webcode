package EnsEMBL::Web::Component::Account::Password;

### Module to create user login form 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return '';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $form = EnsEMBL::Web::Form->new( 'enter_password', "/Account/SavePassword", 'post' );

  $form->add_element('type' => 'Information',
    'value' => 'Passwords should be at least 6 characters long and include both letters and numbers.');

  if (my $user = $ENSEMBL_WEB_REGISTRY->get_user) {
    ## Logged-in user, changing own password
    my $email = $user->email;
    $form->add_element('type'  => 'Hidden', 'name'  => 'email', 'value' => $email);
    $form->add_element('type'  => 'Password', 'name'  => 'password', 'label' => 'Old password',
                      'required' => 'yes');
  } else {
    ## Setting new/forgotten password
    $form->add_element('type' => 'Hidden', 'name' => 'user_id', 'value' => $object->param('user_id'));
    $form->add_element('type' => 'Hidden', 'name' => 'email', 'value' => $object->param('email'));
    $form->add_element('type' => 'Hidden', 'name' => 'code', 'value' => $object->param('code'));
  }

  if ($object->param('record_id')) {
    $form->add_element(
      'type'  => 'Hidden',
      'name'  => 'record_id',
      'value' => $object->param('record_id')
    );
  }

  $form->add_element('type'  => 'Password', 'name'  => 'new_password_1', 'label' => 'New password',
                      'required' => 'yes');
  $form->add_element('type'  => 'Password', 'name'  => 'new_password_2', 'label' => 'Confirm new password',
                      'required' => 'yes');
  $form->add_element('type'  => 'Hidden', 'name'  => '_referer', 'value' => CGI::escape($self->object->param('_referer')));
  $form->add_element('type'  => 'Submit', 'name'  => 'submit', 'value' => 'Save', 'class' => 'cp-internal');

  my $html = $form->render;
  warn $html;
  return $html;
}

1;
