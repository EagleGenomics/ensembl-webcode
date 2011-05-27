# $Id$

package EnsEMBL::Web::Component::Location::ChangeChromosome;

### Module to replace part of the former MapView, in this case 
### the form to navigate to a different chromosome

use strict;

use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
}

sub content {
  my $self     = shift;
  my $hub      = $self->hub;
  my $object   = $self->object;
  my $form     = new EnsEMBL::Web::Form( 'change_chr', $hub->url({ __clear => 1 }), 'get', 'nonstd check');
  my @chrs     = $self->chr_list($object);
  my $chr_name = $object->seq_region_name;
  my $label     = 'Jump to Chromosome';

  if ($hub->action eq 'Synteny') {
    $form->add_element(
      'type'  => 'Hidden',
      'name'  => 'otherspecies',
      'value' => $hub->param('otherspecies') || $self->default_otherspecies,
    );
    $label = 'Jump to ' . $hub->species_defs->DISPLAY_NAME.' chromosome';
  }

  $form->add_element(
    type         => 'DropDownAndSubmit',
    select       => 'select',
    style        => 'narrow',
    on_change     => 'submit',
    name         => 'r',
    label        => $label,
    values       => \@chrs,
    value        => $chr_name,
    button_value => 'Go'
  );
  
  return '<div class="center">' . $form->render($self->format) . '</div>';
}

1;
