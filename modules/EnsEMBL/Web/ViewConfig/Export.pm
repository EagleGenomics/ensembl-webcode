package EnsEMBL::Web::ViewConfig::Export;

use strict;

use base qw(Exporter);
our @EXPORT = our @EXPORT_OK = qw(init form);

use EnsEMBL::Web::Constants;

sub init {
  my $view_config = shift;
  
  my %defaults;
  
  $defaults{'output'} = 'fasta';
  $defaults{'strand'} = $ENV{'ENSEMBL_TYPE'} eq 'Location' ? 'forward' : 'feature';
  
  foreach (qw(flank5_display flank3_display)) {
    $defaults{$_} = 0;
  }
  
  foreach (qw(genomic cdna coding peptide utr5 utr3)) {
    $defaults{'fasta_' . $_} = 'yes';
  }
  
  foreach my $f(qw(csv gff tab)) {
    foreach (qw(similarity repeat genscan variation gene)) {
      $defaults{$f . '_' . $_} = 'yes';
    }
  }
  
  foreach my $f(qw(embl genbank)) {
    foreach (qw(similarity repeat genscan contig variation marker gene vegagene estgene)) {
      $defaults{$f . '_' . $_} = 'yes';
    }
  }
  
  $view_config->_set_defaults(%defaults);
  $view_config->storable = 1;
}

sub form {
  my ($view_config, $object) = @_;
  
  my $type = $object->type;
  
  my %gene_markup_options = EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS;
  
  my $config = $view_config->{'_temp'}->{'config'};
  my $options = $view_config->{'_temp'}->{'options'};
  
  return unless $config; # Gets called twice on an Export page itself - first time is from the wrong place
  
  $view_config->get_form->{'_attributes'}{'id'} = "export_configuration";
  $view_config->get_form->{'_attributes'}{'method'} = "get";
  $view_config->get_form->{'_attributes'}{'action'} = $object->_url({ 'action' => $type, 'type' => 'Export', 'function' => $object->action }); # How confusing!
  
  $view_config->add_fieldset;
    
  my @output_values;
  
  foreach my $c (sort keys %$config) {
    foreach (@{$config->{$c}->{'formats'}}) {
     push (@output_values, { group => $config->{$c}->{'label'}, value => $_->[0], name => $_->[1] });
    }
  }
  
  my @strand_values = (
    { value => '1', name => 'Forward strand' },
    { value => '-1', name => 'Reverse strand' }
  );
  
  unshift (@strand_values, { value => 'feature', name => 'Feature strand' }) unless $type eq 'Location';
  
  $view_config->add_form_element({
    'type'     => 'DropDown', 
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'output',
    'label'    => 'Output',
    'values'   => \@output_values
  });
  
  $view_config->add_form_element({
    'type'     => 'DropDown', 
    'select'   => 'select',
    'required' => 'yes',
    'name'     => 'strand',
    'label'    => 'Strand',
    'values'   => \@strand_values
  });
  
  $view_config->add_form_element({
    'type' => 'Submit',
    'class' => 'submit',
    'value' => 'Next >'
  });
  
  foreach my $c (sort keys %$config) {
    foreach my $f (@{$config->{$c}->{'formats'}}) {      
      $view_config->add_fieldset("Options for $f->[1]");
      
      if ($f->[0] eq 'fasta') { 
        $view_config->add_form_element($gene_markup_options{'flank5_display'});
        $view_config->add_form_element($gene_markup_options{'flank3_display'});
        
        # Does only genomic, so no configuration is necessary
        if ($type eq 'Location') {
          $view_config->add_form_element({
            'type' => 'Hidden',
            'name' => 'fasta_genomic',
            'value' => 'yes'
          });
          
          next;
        }
      }
      
      foreach (@{$config->{$c}->{'params'}}) {
        next if $_->[2] eq "0"; # Next if 0, but not if undef. Where is my === operator, perl?
        
        $view_config->add_form_element({
          'type' => 'CheckBox',
          'label' => $_->[1],
          'name' => "$f->[0]_$_->[0]",
          'value' => 'yes'
        });
      }
    }
  }
  
  $view_config->add_form_element({
    'type' => 'Submit',
    'class' => 'submit',
    'value' => 'Next >'
  });
  
  $view_config->add_form_element({
    'type' => 'Hidden',
    'name' => 'save',
    'value' => 'yes'
  });
}

1;
