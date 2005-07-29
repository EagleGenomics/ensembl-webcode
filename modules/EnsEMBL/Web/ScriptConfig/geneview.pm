package EnsEMBL::Web::ScriptConfig::geneview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    image_width             600
    panel_gene              on
    panel_das               on
    panel_transcript        on
    status_gene_stable_id   on
    status_gene_transcripts on
    status_das_sources      on
    status_gene_orthologues on
    context                 0
  ));
}
1;
