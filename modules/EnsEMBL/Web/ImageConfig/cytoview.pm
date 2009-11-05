package EnsEMBL::Web::ImageConfig::cytoview;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    title             => 'Overview panel',
    show_buttons      => 'no',  # do not show +/- buttons
    button_width      => 8,     # width of red "+/-" buttons
    show_labels       => 'yes', # show track names on left-hand side
    label_width       => 113,   # width of labels on left-hand side
    margin            => 5,     # margin
    spacing           => 2,     # spacing
    opt_halfheight    => 1,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks  => 0,     # include empty tracks..
    opt_lines         => 1,     # draw registry lines
    opt_restrict_zoom => 1,     # when we get "zoom" working draw restriction enzyme info on it!!
  });
  
  $self->create_menus(
    sequence      => 'Sequence',
    marker        => 'Markers',
    transcript    => 'Genes',
    misc_feature  => 'Misc. regions',
    synteny       => 'Synteny',
    variation     => 'Variations', 
    external_data => 'External data',
    user_data     => 'User attached data',
    decorations   => 'Additional decorations',
    information   => 'Information'
  );
  
  $self->add_track('sequence', 'contig', 'Contigs', 'stranded_contig', { display => 'off', strand => 'r', description => 'Track showing underlying assembly contigs' });
  
  $self->add_tracks('information',
    [ 'missing', '', 'text', { display => 'normal', strand => 'r', name => 'Disabled track summary' }],
    [ 'info',    '', 'text', { display => 'normal', strand => 'r', name => 'Information' }]
  );
  
  if ($self->species_defs->ALTERNATIVE_ASSEMBLIES) {
    foreach my $alt_assembly (@{$self->species_defs->ALTERNATIVE_ASSEMBLIES}) {
      $self->add_track('misc_feature', "${alt_assembly}_assembly", "$alt_assembly assembly", 'alternative_assembly', { 
        display       => 'off',  
        strand        => 'r',  
        colourset     => 'alternative_assembly' ,  
        description   => "Track indicating $alt_assembly assembly", 
        assembly_name => $alt_assembly
      });
    }
  }

  $self->load_tracks;
  $self->load_configured_das('strand' => 'r');

  $self->modify_configs(
    [ 'transcript' ],
    { qw(render gene_label strand r) }
  );

  $self->modify_configs(
    [ 'marker' ],
    { qw(labels off) }
  );

  $self->modify_configs(
    [ 'variation' ],
    { qw(display off menu no) }
  );
  $self->modify_configs(
    [ 'variation_feature_structural' ],
    { qw(display normal menu yes) }
  );

  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );
}

1;
