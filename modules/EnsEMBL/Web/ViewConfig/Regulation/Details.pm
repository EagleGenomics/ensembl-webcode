package EnsEMBL::Web::ViewConfig::Regulation::Details;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    image_width         800
    context             200
    das_sources),       []
  );

  $view_config->add_image_configs({ reg_detail => 'das' });

  $view_config->_set_defaults('opt_focus' => 'yes'); # Add config for focus feature track 
  $view_config->_set_defaults('opt_highlight' => 'yes');
  $view_config->_set_defaults('opt_ft_' . $_ => 'on') for keys %{$view_config->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'feature_type'}{'analyses'}}; # Add config for different feature types
  
  $view_config->has_images(1);
  $view_config->storable = 1;
  $view_config->nav_tree = 1;
}

sub form {
  my ($view_config, $object) = @_;  

  # Add context selection
  $view_config->add_fieldset('Context');
  $view_config->add_form_element({
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

  my $reg_object = $object->Obj;
  return unless $reg_object;
  
  $view_config->add_form_element({ type => 'YesNo', name => 'opt_focus', select => 'select', label => 'Show Core Evidence track' }) if $reg_object->get_focus_attributes;

  $view_config->add_form_element({ type => 'YesNo', name => 'opt_highlight', select => 'select', label => 'Highlight core region' }) if $reg_object->get_focus_attributes;

  # First group displayable feature sets by histone modification 
  my %sets_by_type;
  
  foreach my $set (@{$reg_object->get_nonfocus_attributes}) {
    my $feature_type = $set->feature_set->feature_type->name . ':' . $set->feature_set->cell_type->name;
    my $histone_mod = substr $feature_type, 0, 2;

    $histone_mod = 'H1'    if $histone_mod =~ /H\D/;
    $histone_mod = 'Other' if $histone_mod !~ /H\d/;

    $sets_by_type{$histone_mod} = {} unless exists $sets_by_type{$histone_mod};
    $sets_by_type{$histone_mod}{$feature_type} = $set; 
  }

  # Add each feature set to page config according to histone modification
  foreach (sort keys %sets_by_type) {
    $view_config->add_fieldset(ucfirst "$_ feature sets");
    
    foreach (sort {$a->feature_set->feature_type->name cmp $b->feature_set->feature_type->name} values %{$sets_by_type{$_}}) {
      $view_config->add_form_element({
        type  => 'CheckBox', 
        label => $_->feature_set->feature_type->name . ' (' . $_->feature_set->cell_type->name . ')',
        name  => 'opt_ft_' . $_->feature_set->feature_type->name . ':' . $_->feature_set->cell_type->name,
        value => 'on', 
        raw   => 1
      });
    } 
  }
}
1;

