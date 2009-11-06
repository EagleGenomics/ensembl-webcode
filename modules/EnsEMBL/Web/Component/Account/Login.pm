# $Id$

package EnsEMBL::Web::Component::Account::Login;

### Module to create user login form 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Login';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  ## Control panel fixes
  my $dir = $object->species_path;
  
  my $referer = '_referer=' . $object->param('_referer');
  my $form = EnsEMBL::Web::Form->new( 'login', "$dir/Account/SetCookie", 'post' );
  my $reg_url = $self->url("$dir/Account/User/Add?$referer");
  my $pwd_url = $self->url("$dir/Account/LostPassword?$referer");
  
  $form->add_element('type'  => 'Email',    'name'  => 'email', 'label' => 'Email', 'required' => 'yes');
  $form->add_element('type'  => 'Password', 'name'  => 'password', 'label' => 'Password', 'required' => 'yes');
  $form->add_element('type'  => 'Hidden',   'name'  => 'url', 'value' => $object->param('url'));
  $form->add_element('type'  => 'Hidden',   'name'  => 'popup', 'value' => $object->param('popup'));
  $form->add_element('type'  => 'Hidden',   'name'  => '_referer', 'value' => $object->param('_referer'));
  $form->add_element('type'  => 'Hidden',   'name'  => 'x_requested_with', 'value' => $object->param('x_requested_with'));
  $form->add_element('type'  => 'Submit',   'name'  => 'submit', 'value' => 'Log in', 'class'=>'cp-refresh');
  $form->add_element('type'  => 'Information',
                     'value' => qq(<p><a href="$reg_url" class="modal_link">Register</a>
                                  | <a href="$pwd_url" class="modal_link">Lost password</a></p>));

  return $form->render;
}

1;
