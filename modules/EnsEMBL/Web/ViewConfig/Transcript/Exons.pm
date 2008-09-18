package EnsEMBL::Web::ViewConfig::exonview;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_exons      on
    panel_supporting on
    sscon            25
    flanking         50
    fullseq          no
    oexon            no
  ));
  $view_config->storable = 1;
}
1;
