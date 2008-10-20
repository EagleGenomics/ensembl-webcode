package EnsEMBL::Web::ViewConfig::Location::SequenceAlignment;

use strict;
use warnings;
no warnings 'uninitialized';
use EnsEMBL::Web::Constants;

use Data::Dumper;


sub init {
  my ($view_config) = @_;
  $view_config->title = 'Resequencing Alignments';
  $view_config->_set_defaults(qw(
    display_width   120
    exon_ori        all
    match_display   dot
    snp_display     snp
    line_numbering  sequence
    codons_display  off
    title_display   off
  ));
  my $sp = $view_config->species;
  my $var_hash = $view_config->species_defs->databases->{'DATABASE_VARIATION'}||{};
  foreach( @{ $var_hash->{'DEFAULT_STRAINS'}||[] } ) {
    $view_config->_set_defaults( $_, 'yes' );
  }
  foreach( @{ $var_hash->{'DISPLAY_STRAINS'}||[] } ) {
    $view_config->_set_defaults( $_, 'no' );
  }
  $view_config->storable = 1;
}

sub form {
  my( $view_config, $object ) = @_;

  #shared with compara_markup and marked-up sequence
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  #shared with compara_markup
  my %other_markup_options = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;

  $view_config->add_form_element($other_markup_options{'display_width'});

  push @{$general_markup_options{'exon_ori'}{'values'}}, { 'value' =>'off' , 'name' => 'None' };

  $general_markup_options{'exon_ori'}{'label'} = 'Exons to highlight';

  $view_config->add_form_element($general_markup_options{'exon_ori'});

  $view_config->add_form_element({
    'type'   => 'DropDown', 'select'   => 'select',
    'required' => 'yes',    'name'   => 'match_display',
    'label'  => 'Matching basepairs',
    'values'   => [
      { 'value' =>'off' , 'name' => 'Show all' },
      { 'value' =>'dot' , 'name' => 'Replace matching bp with dots' },
    ],
  });

  if( $object->species_defs->databases->{'DATABASE_VARIATION'} ) {
    $view_config->add_form_element($general_markup_options{'snp_display'} );
  }
  $view_config->add_form_element($general_markup_options{'line_numbering'} );
  $view_config->add_form_element($other_markup_options{'codons_display'});
  $view_config->add_form_element($other_markup_options{'title_display'});

  my $sp        = $view_config->species;
  my $var_hash  = $view_config->species_defs->databases->{'DATABASE_VARIATION'}||{};

  my $strains   = $object->species_defs->translate( 'strain' );
  my $ref       = $var_hash->{'REFERENCE_STRAIN'};
  $view_config->add_form_element({
    'type'   => 'NoEdit',
    'name'   => 'reference_individual',
    'label'  => "Reference $strains",
    'value'  => "$ref"
  });

  $strains .= 's';

  $view_config->add_fieldset( "Options for resequenced $sp $strains" );

  foreach( @{ $var_hash->{'DEFAULT_STRAINS'}||[] },
           @{ $var_hash->{'DISPLAY_STRAINS'}||[] } ) {
    $view_config->add_form_element({
      'type'   => 'CheckBox', 'label' => $_,
      'name'   => $_,
      'value'  => 'yes', 'raw' => 1
    });
  }
}

1;
