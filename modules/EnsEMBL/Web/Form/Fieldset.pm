package EnsEMBL::Web::Form::Fieldset;

use strict;

## TODO - remove backward compatibility patches when ok to remove

## Structure of fieldset:
##  - Every child node is appended at the end of the fieldset as they are added except legend & hidden inputs
##  - Legend is always added at the top
##  - Hidden inputs always come after the legend

use base qw(EnsEMBL::Web::DOM::Node::Element::Fieldset);

use constant {
  CSS_CLASS_NOTES           => 'fnotes',
  FOOT_NOTE_REQUIRED        => 'Fields marked <b>*</b> are required',
  
  CSS_CLASS_TEXT_INPUT      => 'ftext',
  CSS_CLASS_FILE_INPUT      => 'ffile',
  CSS_CLASS_BUTTON          => 'fbutton',
  CSS_CLASS_SELECT          => 'fselect',
  CSS_CLASS_TEXTAREA        => 'ftextarea',
  
  CSS_ODD_ROW               => 'bg1',
  CSS_EVEN_ROW              => 'bg2',
  
  _FLAG_FIELD               => '_is_field',
  _FLAG_ELEMENT             => '_is_element',
  _FLAG_HONEYPOT            => '_is_honeypot',
  _FLAG_BUTTON              => '_is_button',
  _FLAG_STRIPED             => '_is_striped',
  _FLAG_REQUIRED            => '_is_required',
};

sub render {
  ## @overrides
  my $self = shift;
  $self->add_notes($self->FOOT_NOTE_REQUIRED) if $self->get_flag($self->_FLAG_REQUIRED);

  #css stuff
  my $css_class = {
    'inputtext'     => $self->CSS_CLASS_TEXT_INPUT,
    'inputpassword' => $self->CSS_CLASS_TEXT_INPUT,
    'inputfile'     => $self->CSS_CLASS_FILE_INPUT,
    'inputsubmit'   => $self->CSS_CLASS_BUTTON,
    'inputbutton'   => $self->CSS_CLASS_BUTTON,
    'inputreset'    => $self->CSS_CLASS_BUTTON,
    'select'        => $self->CSS_CLASS_SELECT,
    'textarea'      => $self->CSS_CLASS_TEXTAREA
  };
  for (@{$self->inputs}) {
    my $key = $_->node_name eq 'input' ? 'input'.$_->get_attribute('type') : $_->node_name;
    $_->set_attribute('class', $css_class->{$key}) if exists $css_class->{$key};
  }

  my $i = 0;
  if ($self->get_flag($self->_FLAG_STRIPED)) {
    for (@{$self->child_nodes}) {
      next if $_->node_name =~ /^(input|legend)$/ || $_->get_flag($self->_FLAG_HONEYPOT) || $_->get_flag($self->_FLAG_BUTTON);#ignore hidden inputs, legend, honeypot and buttons
      $_->set_attribute('class', $i % 2 == 0 ? $self->CSS_EVEN_ROW : $self->CSS_ODD_ROW);
      $i++ if $_->get_flag($self->_FLAG_FIELD) || $_->get_flag($self->_FLAG_ELEMENT);
    }
  }

  return $self->SUPER::render;
}

sub configure {
  ## Configures the fieldset with some extra flags and variables
  ## @return Configured fieldset
  my ($self, $params) = @_;
  $self->{'__id'}   = $params->{'form_name'}  if $params->{'form_name'};
  $self->{'__name'} = $params->{'name'}       if $params->{'name'};
  $self->legend($params->{'legend'})          if $params->{'legend'};
  $self->set_flag($self->_FLAG_STRIPED)       if $params->{'stripes'};
  return $self;
}

sub elements {
  ## Gets all the element child nodes (immediate only) in the fieldset
  ## @return ArrayRef of Form::Fields
  my $self = shift;
  return $self->get_child_nodes_by_flag($self->_FLAG_ELEMENT);
}

sub fields {
  ## Gets all the field child nodes (immediate only) in the fieldset
  ## @return ArrayRef of Form::Fields
  my $self = shift;
  return $self->get_child_nodes_by_flag($self->_FLAG_FIELD);
}

sub inputs {
  ## Gets all input, select or textarea nodes present in the fieldset
  ## @return ArrayRef of DOM::Node::Element::Select|TextArea and DOM::Node::Element::Input::*
  return shift->get_elements_by_tag_name([qw(input select textarea)]);
}

sub legend {
  ## Modifies or adds a legend to the fieldset
  ## @params Inner html string
  ## @return DOM::Node::Element::Legend object
  my $self = shift;
  my $legend = $self->get_legend;
  unless ($legend) {
    $legend = $self->dom->create_element('legend');
    $self->prepend_child($legend);
  }
  $legend->inner_HTML(shift) if @_;
  return $legend;
}

sub get_legend {
  ## Gets the legend of the fieldset
  ## @return DOM::Node::Element::Legend object or undef
  my $self = shift;
  return $self->first_child && $self->first_child->node_name eq 'legend' ? $self->first_child : undef;
}

sub add_field {
  ## Adds a field to the form
  ## Each field is a combination of one label on the left column of the layout and one (or more) elements (input, select, textarea) on the right column. 
  ## @params HashRef with following keys. (or ArrayRef of similar HashRefs in case of multiple fields)
  ##  - field_class       Extra CSS className for the field div
  ##  - label             innerHTML for <label>
  ##  - notes             innerHTML for foot notes
  ##  - head_notes        innerHTML for head notes
  ##  - elements          HashRef with keys as accepted by Form::Element::configure() OR ArrayRef of similar HashRefs in case of multiple elements
  ##                      In case of only one element, 'elements' key can be missed giving all child keys of 'elements' hashref to parent hashref.
  ##  - inline            Flag to tell whether all elements are to be displayed in a horizontal line
  ##  - Other keys can also be considered - see elements key.
  my ($self, $params) = @_;

  if (ref($params) eq 'ARRAY') { #call recursively for multiple addition
    my $return = [];
    push @$return, $self->add_field($_) for @$params;
    return $return;
  }

  my $field = $self->dom->create_element('form-field');
  $field->set_attribute('class', $params->{'field_class'}) if exists $params->{'field_class'};
  $field->label($params->{'label'}) if exists $params->{'label'};

  # add notes
  $field->head_notes($params->{'head_notes'}) if (exists $params->{'head_notes'});
  $field->foot_notes($params->{'notes'})      if (exists $params->{'notes'});

  # find out which elements are to be added
  my $elements = [];
  if (exists $params->{'elements'}) {
    $elements = ref($params->{'elements'}) eq 'HASH' ? [ $params->{'elements'} ] : $params->{'elements'};
  }
  else {
    exists $params->{$_} and delete $params->{$_} for qw(field_class label head_notes notes);
    $elements = [ $params ];
  }
  
  # add elements
  for (@{$elements}) {
  
    # if honeypot element
    if (lc $_->{'type'} eq 'honeypot') {
      $_->{'type'} = 'text';
      $field->set_attribute('class', 'hidden');
      $field->set_flag($self->_FLAG_HONEYPOT);
    }

    $_->{'id'} ||= $self->_next_id;
    $field->add_element($_, $params->{'inline'} || 0);
    $self->set_flag($self->_FLAG_REQUIRED) if exists $_->{'required'};
  }

  $field->set_flag($self->_FLAG_FIELD);
  return $self->append_child($field);
}

sub add_matrix {
  ## Adds a new matrix to the fieldset
  ## @return Form::Matrix object
  my $self = shift;
  return $self->append_child($self->dom->create_element('form-matrix'));
}

sub _add_element {## TODO - remove prefixed underscore once compatibile 
  ## Adds an element to the fieldset
  ## Use add_field if label is needed (Element does not contain a label itself)
  ## @params HashRef of keys as accepted by Form::Element::configure()
  ## @return Form::Element's child class object OR DOM::Node::Element::Div object if Element is not inherited from Div
  my ($self, $params) = @_;
  
  if (ref($params) eq 'ARRAY') { #call recursively for multiple addition
    my $elements = [];
    push @$elements, $self->add_element($_) for @$params;
    return $elements;
  }
  
  my $element = $self->dom->create_element('form-element-'.$params->{'type'});

  #error handling
  if (!$element) {
    warn qq(DOM Could not create element "$params->{'type'}". Perhaps there's no corresponding class in Form::Element, or has not been mapped in Form::Element::map_element_class);
    return undef;
  }

  $params->{'id'} ||= $self->_next_id;
  $element->configure($params);
  if ($element->node_name ne 'div') {
    my $div = $self->dom->create_element('div');
    $div->append_child($element);
    return $self->append_child($div);
  }
  $element->set_flag($self->_FLAG_ELEMENT);
  return $self->append_child($element);
}

sub _add_button {## TODO - remove prefixed underscore once compatibile
  ## Adds buttons in the fieldset
  ## This is only an alias to add_field but 'elements' key is replaced with 'buttons' key along with addition of a new 'inline' key
  ## @params HashRef with following keys
  ##  - label             innerHTML for <label> if any needed for left column to the bottons (optional)
  ##  - align             [cetre(or center)|left|right|default]
  ##  - notes             innerHTML for foor notes
  ##  - head_notes        innerHTML for head notes
  ##  - buttons           HashRef with keys as accepted by Form::Element::Button::configure() OR ArrayRef of similar HashRefs if multiple buttons
  ##                      In case of only one button, 'buttons' key can be missed giving all child keys of 'buttons' hashref to parent hashref.
  ## @return Form::Field object with embedded buttons
  my ($self, $params) = @_;
  $params->{'elements'} = $params->{'buttons'} if $params->{'buttons'};
  $params->{'inline'} = 1;
  $params->{'field_class'} = $self->CSS_CLASS_BUTTON.'-'.$params->{'align'} if $params->{'align'} =~ /^(centre|center|left|right)$/;
  delete $params->{'buttons'};
  my $field = $self->add_field($params);
  $field->set_flag($self->_FLAG_BUTTON);
  return $field;
}

sub add_hidden {
  ## Adds hidden input(s) inside the fieldset
  ## @params HashRef with the following keys OR ArrayRef of the similar Hashes if muliple addition needed
  ##  - id            Id attribuite
  ##  - name          Name attribute
  ##  - value         Value attribute
  ##  - class         Class attribute
  ##  - is_encoded    Flag kept on, is value does not need any HTML encoding
  ## @return Input object added OR ArrayRef of all Input objects in case of multiple addition
  my ($self, $params) = @_;
  
  if (ref($params) eq 'ARRAY') { #call recursively for multiple addition
    my $return = [];
    push @$return, $self->add_hidden($_) for @$params;
    return $return;
  }

  warn 'Hidden element needs to have a name.' and return undef unless exists $params->{'name'};
  $params->{'value'} = '' unless exists $params->{'value'};
  $params->{'value'} = $self->encode_htmlentities($params->{'value'}) unless $params->{'is_encoded'};

  my $hidden = $self->dom->create_element('inputhidden', {
    'name'  => $params->{'name'},
    'value' => $params->{'value'}
  });

  $hidden->set_attribute('id',    $params->{'id'})    if $params->{'id'};
  $hidden->set_attribute('class', $params->{'class'}) if $params->{'class'};
  my $reference = $self->first_child;
  $reference = $reference->next_sibling while $reference && $reference->node_name =~ /^(input|legend)$/;
  return $reference ? $self->insert_before($hidden, $reference) : $self->append_child($hidden);
}

sub add_notes {
  ## Appends a div to the fieldset with notes HTML inside
  ## @params String text or HashRef {'text' =>? , 'class' => ?, 'list' => ?, 'serialise' => 1/0} or ArrayRef of either of these for multiple addition
  ##  - text      Text to go inside the notes
  ##  - list      ArrayRef of Strings that need to go inside the notes as a list
  ##  - serialise Flag if on, uses <ol> for the list, otherwise <ul>.
  ## @return DOM::Node::Element::Div object
  my ($self, $params) = @_;
  
  if (ref $params eq 'ARRAY') { # call recursively for multiple addition
    my $return = [];
    push @$return, $self->add_notes($_) for @$params;
    return $return;
  }
  
  my $notes = $self->dom->create_element('div');
  $params = { 'text' => $params, 'class' => $self->CSS_CLASS_NOTES } if ref $params ne 'HASH';
  
  if (exists $params->{'text'}) {
    $notes->inner_HTML($params->{'text'});
  }
  
  if (exists $params->{'list'}) {
    my $list = $self->dom->create_element($params->{'serialise'} ? 'ol' : 'ul');
    $list->append_child($self->dom->create_element('li', { inner_HTML => $_ })) for @{$params->{'list'}};
    $notes->append_child($list);
  }
  
  $notes->set_attribute('class', exists $params->{'class'} ? $params->{'class'} : $self->CSS_CLASS_NOTES);
  $self->append_child($notes);
  
  return $notes;
}


## Other helper methods
sub _next_id {
  my $self = shift;
  $self->{'__set_id'} ||= 1;
  $self->{'__id'} ||= $self->form->id;
  $self->{'__name'} ||= $self->unique_id;
  return $self->{'__id'}.'_'.$self->{'__name'}.'_'.($self->{'__set_id'}++);
}


##################################
##                              ##
## BACKWARD COMPATIBILITY PATCH ##
##                              ##
##################################
my $do_warn = 0;

sub add_element {
  my $self = shift;
  
  ## Call new add_element method if argument is HashRef or ArrayRef
  return $self->_add_element($_[0]) if ref($_[0]) =~ /^(HASH|ARRAY)$/;
  
  warn "Method add_element is deprecated. Please use an appropriate method." if $do_warn;

  my %params = @_;

  $params{'class'} ||= '';
  $params{'class'} .= ref($params{'classes'}) eq 'ARRAY' ? join(' ', @{$params{'classes'}}) : $params{'classes'};

  ## Hidden
  if ($params{'type'} eq 'Hidden') {
    return $self->add_hidden({
      'name'  => $params{'name'},
      'value' => $params{'value'}, 
      'class' => $params{'class'},
      'id'    => $params{'id'},
    });
  }
  
  ## Remove extra hidden input for NoEdit fields
  $params{'no_input'} = 1;

  ## SubHeader is now new fieldset's legend
  return $self->form->add_fieldset($params{'value'}) if $params{'type'} eq 'SubHeader';

  ## Information is now fieldset's notes
  return $self->add_notes($params{'value'}) if $params{'type'} eq 'Information';
  
  ## ForceReload
  return $self->form->force_reload_on_submit if $params{'type'} eq 'ForceReload';

  ## 'name' key for options is changed to 'caption' key - name key corresponds to name attribute only
  foreach my $option (@{$params{'values'}}) { 
    $option = {'value' => $option, 'caption' => $option} if ref($option) ne 'HASH';
    if (exists $option->{'name'}) {
      $option->{'caption'} = $option->{'name'};
      delete $option->{'name'};
    }
  }

  # DropDown, RadioGroup, RadioButton, CheckBox, MultiSelect
  $params{'type'}     = exists $params{'select'} && $params{'select'} ? 'dropdown' : 'radiolist' if $params{'type'} eq 'DropDown';
  $params{'type'}     = 'radiolist' if $params{'type'} =~ /^(radiogroup|radiobutton)$/i;
  $params{'type'}     = 'dropdown' and $params{'multiple'} = 1 if $params{'type'} eq 'MultiSelect';
  $params{'checked'}  = $params{'selected'} if $params{'type'} =~ /checkbox/i;

  ## DropDownAndSubmit
  if ($params{'type'} eq 'DropDownAndSubmit') {
    $params{'type'} = exists $params{'select'} && $params{'select'} ? 'dropdown' : 'radiolist';
    return $self->add_field({
      'label'       => $params{'label'},
      'field_class'  => $params{'style'},
      'inline'      => 1,
      'elements'    => [\%params, {'type' => 'submit', 'value' => $params{'button_value'}}]
    });
  }
  
  ## DASCheckBox
  if ($params{'type'} eq 'DASCheckBox') {
    return $self->add_element(\%params);
  }
  
  ## Element is now Field.
  my $field = $self->add_field(\%params);

  return $field;
}

sub add_button {
  my $self = shift;
  return $self->_add_button($_[0]) if (ref($_[0]) =~ /^(ARRAY|HASH)$/);

  my %params = @_;
  $params{'class'} ||= '';
  $params{'class'} .= ref($params{'classes'}) eq 'ARRAY' ? join(' ', @{$params{'classes'}}) : $params{'classes'};
  return $self->_add_button(\%params);
}

1;