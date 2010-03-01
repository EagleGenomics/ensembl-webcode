package EnsEMBL::Web::ImageConfig::gene_summary;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    title         => 'Transcript panel',
    show_buttons  => 'no',  # do not show +/- buttons
    show_labels   => 'yes', # show track names on left-hand side
    label_width   => 113,   # width of labels on left-hand side
    opt_lines     => 1,     # draw registry lines
    margin        => 5,     # margin
    spacing       => 2,     # spacing
  });

  $self->create_menus(
    sequence      => 'Sequence',
    transcript    => 'Genes',
    prediction    => 'Prediction transcripts',
    variation     => 'Variation features',
    functional    => 'Functional genomics',
    external_data => 'External data',
    user_data     => 'User attached data', # DAS/URL tracks/uploaded data/blast responses
    other         => 'Decorations',
  );

  $self->add_tracks('other',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }],
  );
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs',  'stranded_contig', { display => 'normal', strand => 'r' }]
  );

  $self->load_tracks;
  $self->load_configured_das;

  $self->modify_configs(
    [qw(fg_regulatory_features_funcgen)],
    {qw(display off)}
  );
  $self->modify_configs(
    [qw(transcript prediction variation)],
    {qw(display off)} 
  );

  $self->modify_configs(
    [qw(transcript_core_ensembl transcript_core_sg)],
    {qw(display transcript_label)}
  );
}

1;
