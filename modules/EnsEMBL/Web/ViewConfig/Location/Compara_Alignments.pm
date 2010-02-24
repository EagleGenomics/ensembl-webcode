package EnsEMBL::Web::ViewConfig::Location::Compara_Alignments;

use strict;

use EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments;

sub init { 
  my $view_config = shift;
  
  EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments::init($view_config);
  
  $view_config->{'no_flanking'} = 1;
  $view_config->{'strand_option'} = 1;
  
  $view_config->_set_defaults(qw(
    flank5_display 0 
    flank3_display 0
    panel_top      yes
    strand         1
  ));
  
  $view_config->add_image_configs({qw(
    contigviewtop        nodas
    alignsliceviewbottom nodas
  )}); 
}

sub form {
  my ($view_config, $object) = @_;
  
  if ($object->function eq 'Image') { 
    $view_config->default_config = 'alignsliceviewbottom';
    $view_config->add_form_element({ type => 'YesNo', name => 'panel_top', select => 'select', label => 'Show overview panel' });
    $view_config->{'species_only'} = 1;
  } elsif (!$view_config->is_custom) {
    $view_config->{'_image_config_names'} = {}; # Removes the image config tabs
    $view_config->has_images = 0;
  }
  
  EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments::form($view_config, $object);
}

1;

