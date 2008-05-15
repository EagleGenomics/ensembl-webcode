package EnsEMBL::Web::Component::Location::ChangeChromosome;

### Module to replace part of the former MapView, in this case 
### the form to navigate to a different chromosome

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $html = '<div class="twocol-left">';
  my $form = EnsEMBL::Web::Form->new( 'change_chr', '/'.$object->species.'/jump_to_location_view', 'get' );

  my @chrs = $self->chr_list($object);
  my $chr_name = $object->seq_region_name;

  if ($object->action eq 'Synteny') {
    $form->add_element(
      'type'  => 'Hidden',
      'name'  => 'otherspecies',
      'value' => $object->param('otherspecies'),
    );
  }

  $form->add_element(
    'type'     => 'DropDownAndSubmit',
    'select'   => 'select',
    'style'    => 'narrow',
    'on_change' => 'submit',
    'name'     => 'chr',
    'label'    => 'Jump to Chromosome',
    'values'   => \@chrs,
    'value'    => $chr_name,
    'button_value' => 'Go'
  );

  $html .= $form->render;
  $html .= '</div>';
}

1;
