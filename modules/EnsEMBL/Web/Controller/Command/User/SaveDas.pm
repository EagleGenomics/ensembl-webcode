package EnsEMBL::Web::Controller::Command::User::SaveDas;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data::Record::User::DAS;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::DataUser');
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->render_page;
  } else {
    $self->render_message;
  }
}

sub render_page {
  my $self = shift;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  print "Content-type:text/html\n\n";
  print "Saving DAS for " . $user->id . "<br />"; 
  my @sources = @{ $ENSEMBL_WEB_REGISTRY->get_das_filtered_and_sorted };
    
  foreach my $das (@sources) {
    $user->add_to_dases({
      name    => $das->get_name,
      url     => $das->get_data->{'url'},
      config  => $das->get_data,
    });

    print $user_das->name . "<br />";
    warn "DAS: " . $das->get_name . " (" . $das->get_data->{'url'} . ")";
  } 
}

}

1;
