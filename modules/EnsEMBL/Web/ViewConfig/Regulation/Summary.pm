# $Id$

package EnsEMBL::Web::ViewConfig::Regulation::Summary;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    image_width   800
    context       200
    das_sources), []
  );

  $self->add_image_configs({ reg_detail => 'das' });

  $self->_set_defaults('opt_focus' => 'yes'); # Add config for focus feature track 
  $self->_set_defaults("opt_ft_$_" => 'on') for keys %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'feature_type'}{'analyses'}}; # Add config for different feature types
  
  $self->storable = 1;
  $self->nav_tree = 1;
}

sub form {
  my ($self, $object) = @_;  
  my $reg_object = $object->Obj;
  
  # Add context selection
  $self->add_fieldset('Context');
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Context',
    values => [
      { value => '20',   name => '20bp' },
      { value => '50',   name => '50bp' },
      { value => '100',  name => '100bp' },
      { value => '200',  name => '200bp' },
      { value => '500',  name => '500bp' },
      { value => '1000', name => '1000bp' },
      { value => '2000', name => '2000bp' },
      { value => '5000', name => '5000bp' }
    ]
  });
  
  $self->add_form_element({ type => 'YesNo', name => 'opt_focus', select => 'select', label => 'Show Core Evidence track' }) if $reg_object && $reg_object->get_focus_attributes;
}

1;
