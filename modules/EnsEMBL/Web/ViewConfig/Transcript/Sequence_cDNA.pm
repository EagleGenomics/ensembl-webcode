package EnsEMBL::Web::ViewConfig::Transcript::Sequence_cDNA;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    exons         yes
    codons        yes
    coding_seq    no
    display_width 60
    translation   no
    rna           no
    variation     no
    number        no
  ));
  
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;

  $view_config->add_form_element({
    type   => 'DropDown', 
    select => 'select',
    name   => 'display_width',
    label  => 'Number of base pairs per row',
    values => [
      map {{ value => $_, name => "$_ bps" }} map $_*15, 2..12
    ] 
  });

  $view_config->add_form_element({ type => 'YesNo', name => 'exons',       select => 'select', label => 'Show exons' });
  $view_config->add_form_element({ type => 'YesNo', name => 'codons',      select => 'select', label => 'Show codons' });
  $view_config->add_form_element({ type => 'YesNo', name => 'coding_seq',  select => 'select', label => 'Show coding sequence' });
  $view_config->add_form_element({ type => 'YesNo', name => 'translation', select => 'select', label => 'Show protein sequence' });
  $view_config->add_form_element({ type => 'YesNo', name => 'rna',         select => 'select', label => 'Show RNA features' });
  $view_config->add_form_element({ type => 'YesNo', name => 'variation',   select => 'select', label => 'Show variation features' });
  $view_config->add_form_element({ type => 'YesNo', name => 'number',      select => 'select', label => 'Number residues' });
}

1;
