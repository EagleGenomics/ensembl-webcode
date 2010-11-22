package EnsEMBL::Web::ViewConfig::Location::Chromosome;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
### Used by Constructor
### init function called to set defaults for the passed
### {{EnsEMBL::Web::ViewConfig}} object

  my( $view_config ) = @_;

  $view_config->_set_defaults(qw(
    panel_top      yes
    panel_zoom      no
    zoom_width    100
    context       1000
  ));
  $view_config->add_image_configs({qw(
    Vmapview      nodas
  )});
  $view_config->default_config = 'Vmapview';
  $view_config->storable       = 1;
  $view_config->can_upload = 1;
}

1;
