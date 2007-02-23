package EnsEMBL::Web::ScriptConfig::alignsliceview;

=head1 NAME

EnsEMBL::Web::ScriptConfig::alignsliceview;

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
  my( $script_config ) = @_;

  $script_config->_set_defaults(qw(
    panel_ideogram on
    panel_top      on
    panel_bottom   on
    panel_zoom     off
    zoom_width     100
    image_width    700
    context    100000

    opt_align_238 off
opt_238_Homo_sapiens on
opt_238_Pan_troglodytes on
opt_238_Macaca_mulatta on
opt_238_Bos_taurus on
opt_238_Canis_familiaris on
opt_238_Mus_musculus on
opt_238_Rattus_norvegicus on

    opt_align_240 off
opt_240_Homo_sapiens on
opt_240_Pan_troglodytes on
opt_240_Macaca_mulatta on
opt_240_Bos_taurus on
opt_240_Canis_familiaris on
opt_240_Gallus_gallus on
opt_240_Mus_musculus on
opt_240_Monodelphis_domestica on
opt_240_Rattus_norvegicus on
opt_240_constrained_elem on
opt_240_conservation_score on

    opt_align_4 off
  ),
  map {( "opt_align_$_" => "off")} (3,93,154..400)
  );

  $script_config->storable = 1;
  $script_config->add_image_configs({qw(
    alignsliceviewbottom nodas
  )});
}

1;
