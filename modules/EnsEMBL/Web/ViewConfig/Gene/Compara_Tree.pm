package EnsEMBL::Web::ViewConfig::Gene::Compara_Tree;

use strict;

use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;
  
  $view_config->_set_defaults(qw(
    image_width    800
    width          800
    collapsability gene
    text_format    msf
    tree_format    newick_mode
    newick_mode    full_web
    nhx_mode       full
    scale          150
  ));

  $view_config->storable = 1;
  $view_config->nav_tree = 1;
}

sub form {
  my ($view_config, $object) = @_;
  
  my $function = $object->function;
  
  if ($function eq 'Align') {
    my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;
    
    $view_config->add_fieldset('Aligment output');
    
    $view_config->add_form_element({
      type   => 'DropDown', 
      select => 'select',
      name   => 'text_format',
      label  => 'Output format for sequence alignment',
      values => [ map {{ value => $_, name => $formats{$_} }} sort keys %formats ]
    });
  } elsif ($function eq 'Text') {
    my %formats = EnsEMBL::Web::Constants::TREE_FORMATS;
    
    $view_config->add_fieldset('Text tree output');
    
    $view_config->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'tree_format',
      label  => 'Output format for tree',
      values => [ map {{ value => $_, name => $formats{$_}{'caption'} }} sort keys %formats ]
    });

    $view_config->add_form_element({
      type     => 'PosInt',
      required => 'yes',
      name     => 'scale',
      label    => 'Scale size for Tree text dump'
    });

    %formats = EnsEMBL::Web::Constants::NEWICK_OPTIONS;
    
    $view_config->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'newick_mode',
      label  => 'Mode for Newick tree dumping',
      values => [ map {{ value => $_, name => $formats{$_} }} sort keys %formats ]
    });

    %formats = EnsEMBL::Web::Constants::NHX_OPTIONS;
    
    $view_config->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'nhx_mode',
      label  => 'Mode for NHX tree dumping',
      values => [ map {{ value => $_, name => $formats{$_} }} sort keys %formats ]
    });
  } else {
    $view_config->add_fieldset('Image options');
    
    $view_config->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'collapsability',
      label  => 'Viewing options for tree image',
      values => [ 
        { value => 'gene',         name => 'View current gene only' },
        { value => 'paralogs',     name => 'View paralogs of current gene' },
        { value => 'duplications', name => 'View all duplication nodes' },
        { value => 'all',          name => 'View fully expanded tree' }
      ]
    });
  }
}

1;
