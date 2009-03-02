package EnsEMBL::Web::ImageConfig::cytoview;

use strict;
use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;

  $self->set_parameters({
    'title'         => 'Overview panel',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'button_width'  => 8,     # width of red "+/-" buttons
    'show_labels'   => 'yes', # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing

## Now let us set some of the optional parameters....
    'opt_halfheight'    => 1, # glyphs are half-height [ probably removed when this becomes a track config ]
    'opt_empty_tracks'  => 0, # include empty tracks..
    'opt_lines'         => 1, # draw registry lines
    'opt_restrict_zoom' => 1, # when we get "zoom" working draw restriction enzyme info on it!!

## Finally some colours... background image colors;
## and alternating colours for tracks...
  });

  $self->create_menus(
    'sequence'      => 'Sequence',
    'marker'        => 'Markers',
    'transcript'    => 'Genes',
    'misc_feature'  => 'Misc. regions',
    'synteny'       => 'Synteny',
    'external_data' => 'External data',
    'user_data'     => 'User attached data',
    'decorations'   => 'Additional decorations',
    'information'   => 'Information',
    'options'       => 'Options'
  );

  $self->add_tracks( 'sequence',
    [ 'contig', 'Contigs', 'stranded_contig', { 'display' => 'off',  'strand' => 'r', 'description' => 'Track showing underlying assembly contigs' } ],
  );
  $self->add_tracks( 'information',
    [ 'missing',   '', 'text', { 'display' => 'normal', 'strand' => 'r', 'name' => 'Disabled track summary' } ],
    [ 'info',      '', 'text', { 'display' => 'normal', 'strand' => 'r', 'name' => 'Information'  } ],
  );
  if ($self->species_defs->ALTERNATIVE_ASSEMBLY) {
    $self->add_tracks( 'misc_feature',
    [ 'vega_assembly', 'Vega assembly', 'alternative_assembly', { 'display' => 'off',  'strand' => 'f',  'colourset' => 'alternative_assembly' ,  'description' => 'Track indicating Vega assembly'  } ]);
  }
  $self->load_tracks();
  $self->load_configured_das( 'strand' => 'r' );

  $self->modify_configs(
    ['transcript'],
    {qw(render gene_label strand r)}
  );

  $self->modify_configs(
    ['marker'],
    {qw(labels off)}
  );

  $self->add_tracks( 'decorations',
    [ 'scalebar',  '',            'scalebar',        { 'display' => 'normal',  'strand' => 'b', 'name' => 'Scale bar'  } ],
    [ 'ruler',     '',            'ruler',           { 'display' => 'normal',  'strand' => 'b', 'name' => 'Ruler'      } ],
    [ 'draggable', '',            'draggable',       { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'         } ],
  );
  
  $self->add_options(
    ['opt_halfheight',     'Half height glyphs',  {qw(1 Yes 0 No)} ],
    ['opt_register_lines', 'Show register lines', {qw(1 Yes 0 No)} ]
  );
}

1;
