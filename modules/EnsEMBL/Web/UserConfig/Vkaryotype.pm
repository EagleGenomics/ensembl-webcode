package EnsEMBL::Web::UserConfig::Vkaryotype;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_label'}             = 'below',
  $self->{'_band_labels'}       = 'off',
  $self->{'_image_height'}      = 200,
  $self->{'_top_margin'}        = 5,
  $self->{'_rows'}              = 2,
  $self->{'_userdatatype_ID'}   = 255;
  $self->{'_all_chromosomes'}   = 'yes';
  $self->{'general'}->{'Vkaryotype'} = {
    '_artefacts'    => [qw(Videogram Vgenes)],
    '_options'      => [],
    '_settings'     => {
      'opt_zclick'  => 1,
      'bgcolor'     => 'background1',
      'width'       => 225 # really height <g>
    },
    'Videogram'     => {
      'on'          => 'on',
      'totalwidth'  => 18,
      'pos'         => '1',
      'width'       => 12,
      'padding'     => 6,
    },
  };
}
1;
