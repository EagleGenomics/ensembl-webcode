package EnsEMBL::Web::ScriptConfig::transview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    show                    plain
    number                   off   
  ));
}
1;
