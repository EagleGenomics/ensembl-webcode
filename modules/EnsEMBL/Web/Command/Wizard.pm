package EnsEMBL::Web::Command::Wizard;

## Generic module for redirecting wizard nodes 
## depending on which form button is clicked

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url;

  ## Work out where we want to go
  my $submit = $object->param('wizard_ajax_submit') || $object->param('wizard_submit');
  if( $submit && $submit =~ /Back/i ) {
    my $current_node = 'Summary'; ## Default value to stop Magic from barfing
    my $species = $object->type eq 'UserData' ? $object->data_species : $object->species;
    if ($species) {
      $url .= $object->species_path($species);
    }
    $url .= '/'.$object->type;

    my @steps = $object->param('_backtrack');
    pop(@steps);
    $current_node = pop(@steps);
    $url .= '/'.$current_node;
  }
  else {
    $url = $object->param('wizard_next');
  }

  ## Pass the "normal" parameters but munge the wizard ones
  my $param = {};
  foreach my $name ($object->param) {
    next if $name =~ /^wizard_/;
    my @value = $object->param($name);
    my $value = (@value) ? \@value : $value[0];

    if ($name eq '_backtrack') {
      my $submit = $object->param('wizard_submit');
      if ($submit && $submit =~ /Back/) {
        pop(@$value) if ref($value) eq 'ARRAY';
      }
    }
    $param->{$name} = $value;
  }

  $self->ajax_redirect($url, $param); 
}

1;
