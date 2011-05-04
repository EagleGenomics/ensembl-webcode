# $Id$

package EnsEMBL::Web::ImageConfig::transview;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    title       => 'Transcript panel',
    show_labels => 'yes', # show track names on left-hand side
    label_width => 113,   # width of labels on left-hand side
  });

  $self->create_menus(
    other      => 'Decorations',
    transcript => 'Genes',
    prediction => 'Prediction transcripts'
  );

  $self->add_tracks('other',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'f', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'r', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );
  
  $self->load_tracks;
}

1;
