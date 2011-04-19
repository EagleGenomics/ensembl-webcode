package EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $view_config = shift;
  
  $view_config->_set_defaults(qw(
    flank5_display        600
    flank3_display        600
    exon_display          core
    exon_ori              all
    snp_display           off
    line_numbering        off
    display_width         120
    conservation_display  off
    region_change_display off
    codons_display        off
    title_display         off
  ));
  
  $view_config->storable = 1;
  $view_config->nav_tree = 1;
  
  my $hash = $view_config->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}||{};
  
  foreach my $row_key (grep { $hash->{$_}{'class'} !~ /pairwise/ } keys %$hash) {
    $view_config->_set_defaults(map {( lc("species_${row_key}_$_"), /Ancestral/ ? 'off' : 'yes' )} keys %{$hash->{$row_key}{'species'}});
  }
}

sub form {
  my ($view_config, $object) = @_;
  
  if (!$view_config->{'species_only'}) {
    my %gene_markup_options    = EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS;    # options shared with marked-up sequence
    my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS; # options shared with resequencing and marked-up sequence
    my %other_markup_options   = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;   # options shared with resequencing
    
    push @{$gene_markup_options{'exon_display'}{'values'}}, { value => 'vega', name => 'Vega exons' } if $view_config->species_defs->databases->{'DATABASE_VEGA'};
    push @{$gene_markup_options{'exon_display'}{'values'}}, { value => 'otherfeatures', name => 'EST gene exons' } if $view_config->species_defs->databases->{'DATABASE_OTHERFEATURES'};
    
    if (!$view_config->{'no_flanking'}) {
      $view_config->add_form_element($gene_markup_options{'flank5_display'});
      $view_config->add_form_element($gene_markup_options{'flank3_display'});
    }
    
    $view_config->add_form_element($other_markup_options{'display_width'});
    $view_config->add_form_element($other_markup_options{'strand'}) if $view_config->{'strand_option'};
    $view_config->add_form_element($gene_markup_options{'exon_display'});
    $view_config->add_form_element($general_markup_options{'exon_ori'});
    $view_config->add_form_element($general_markup_options{'snp_display'}) if $view_config->species_defs->databases->{'DATABASE_VARIATION'};
    $view_config->add_form_element($general_markup_options{'line_numbering'});
    $view_config->add_form_element($other_markup_options{'codons_display'});

    $view_config->add_form_element({
      name     => 'conservation_display',
      label    => 'Conservation regions',
      type     => 'DropDown',
      select   => 'select',
      values   => [{
        value => 'all',
        name  => 'All conserved regions'
      }, {
        value => 'off',
        name  => 'None'
      }]
    });
    $view_config->add_form_element({
      name   => 'region_change_display',
      label  => 'Mark alignment start/end',
      type   => 'DropDown',
      select => 'select',
      values => [{
        value => 'yes',
        name  => 'Yes'
      }, {
        value => 'off',
        name  => 'No'
      }]
    });
    
    $view_config->add_form_element($other_markup_options{'title_display'});
  }
    
  my $species      = $view_config->species;
  my $species_defs = $view_config->species_defs;
  my $alignments   = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'} || {};
  
  # Order by number of species (name is in the form "6 primates EPO"
  foreach my $row (sort { $a->{'name'} <=> $b->{'name'} } grep { $_->{'class'} !~ /pairwise/ && $_->{'species'}->{$species} } values %$alignments) {
    my $sp = $row->{'species'};
    
    $sp->{$_} = $species_defs->species_label($_) for keys %$sp;
    
    $view_config->add_fieldset($row->{'name'});
    
    foreach (sort { ($sp->{$a} =~ /^<.*?>(.+)/ ? $1 : $sp->{$a}) cmp ($sp->{$b} =~ /^<.*?>(.+)/ ? $1 : $sp->{$b}) } keys %$sp) {
      my $name = sprintf 'species_%s_%s', $row->{'id'}, lc;
      
      if ($_ eq $species) {
        $view_config->add_form_element({
          type => 'Hidden',
          name => $name
        });
      } else {
        $view_config->add_form_element({
          type  => 'CheckBox', 
          label => $sp->{$_},
          name  => $name,
          value => 'yes',
          raw   => 1
        });
      }
    }
  }
}

1;

