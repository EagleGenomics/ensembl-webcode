package EnsEMBL::Web::ViewConfig::Gene::Variation_Gene;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    panel_image          on 
    context              100
    panel_transcript     on
    image_width          800

    opt_freq        on
    opt_cluster     on
    opt_doublehit   on
    opt_submitter   on
    opt_hapmap      on 
    opt_noinfo      on
      
    opt_in-del    on
    opt_snp       on
    opt_mixed     on
    opt_microsat  on
    opt_named     on
    opt_mnp       on
    opt_het       on
    opt_          on

    opt_stop_gained            on
    opt_stop_lost              on
    opt_frameshift_coding      on
    opt_non_synonymous_coding  on
    opt_essential_splice_site  on
    opt_splice_site            on
    opt_regulatory_region      on
    opt_synonymous_coding      on
    opt_5prime_utr             on
    opt_3prime_utr             on
    opt_downstream             on
    opt_upstream               on
    opt_intronic               on
    opt_intergenic             on
  ));
  $view_config->add_image_configs({qw(
    genesnpview_transcript nodas
    genesnpview_gene       nodas
    genesnpview_context    nodas
  )});
  $view_config->storable = 1;
}
1;
