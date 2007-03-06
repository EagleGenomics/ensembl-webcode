package EnsEMBL::Web::Controller::Command::User::SaveDas;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Object::Data::DAS;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::LoggedIn->new);
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::DataUser->new);
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->render_page;
  } else {
    print "Content-type:text/html\n\n";
    print $self->filters->message;
  }
}

sub render_page {
  my $self = shift;
  my $user = $self->filters->user($ENSEMBL_WEB_REGISTRY->get_user->id);
  print "Content-type:text/html\n\n";
  print "Saving DAS for " . $user->id . "<br />";
  my @sources = @{ $ENSEMBL_WEB_REGISTRY->get_das_filtered_and_sorted };
  foreach my $das (@sources) {
    my $user_das = EnsEMBL::Web::Object::Data::DAS->new;
    $user_das->user_id($user->id);
    $user_das->name($das->get_name);
    $user_das->url($das->get_data->{'url'});
    $user_das->config($das->get_data);
    print $user_das->name . "<br />";
    $user_das->save;
    warn "DAS: " . $das->get_name . " (" . $das->get_data->{'url'} . ")";
  }
}

}

1;
