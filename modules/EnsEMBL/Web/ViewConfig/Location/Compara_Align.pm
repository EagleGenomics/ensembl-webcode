package EnsEMBL::Web::ViewConfig::Compara::Compara_Align;

=head1 NAME

EnsEMBL::Web::ViewConfig::alignsliceview;

=head1 SYNOPSIS

The object handles the config of alignsliceview script

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

use strict;
no strict 'refs';

sub init {
  my( $view_config ) = @_;

  $view_config->_set_defaults(qw(
    panel_ideogram  on
    panel_top       on
    panel_bottom    on
    panel_zoom     off
    zoom_width     100
    context     100000
  ));
  $view_config->storable = 1;
  $view_config->add_image_configs({qw(
    alignsliceviewbottom nodas
  )});
}

1;
