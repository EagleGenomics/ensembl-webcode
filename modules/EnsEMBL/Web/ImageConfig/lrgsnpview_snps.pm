package EnsEMBL::Web::ImageConfig::lrgsnpview_snps;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;  

  $self->set_parameters({
    'title'         => 'SNPs',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'show_labels'   => 'no',   # show track names on left-hand side
    'label_width'   => 100,     # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing
    'bgcolor'       => 'background1',
    'bgcolour1'     => 'background3',
    'bgcolour2'     => 'background1',
  });
  $self->create_menus(
    'other'           => 'Decorations',
  );

  $self->add_tracks( 'other',
     [ 'snp_fake',              '',   'snp_fake',             { 'display' => 'on', 'colours' => $self->species_defs->colour('variation'),  'strand' => 'f', 'tag'  => 2 }],
     [ 'variation_legend',      '',   'variation_legend',     { 'display' => 'on', 'strand' => 'r',  'caption' => 'Variation legend'         } ],
     [ 'snp_fake_haplotype',    '',   'snp_fake_haplotype',   { 'display' => 'off', 'strand' => 'r', 'colours' => $self->species_defs->colour('haplotype'), }],
     [ 'tsv_haplotype_legend',  '',   'tsv_haplotype_legend', { 'display' => 'off', 'strand' => 'r', 'caption' => 'Haplotype legend', 'src' => 'all', 'colours' => $self->species_defs->colour('haplotype'), }],      
 );

  $self->load_tracks();


}
1;

