package EnsEMBL::Web::ImageConfig::genesnpview_snps;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 38;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'general'}->{'genesnpview_snps'} = {
    '_artefacts' => [qw( snp_fake  snp_fake_haplotype variation_legend  TSV_haplotype_legend TSV_missing)],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'show_labels' => 'no',
      'width'   => 800,
      'opt_zclick'     => 1,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background3',
      'bgcolour2' => 'background1',
    },
    'spacer' => { 'on'=>'on','pos'=>0, 'height' => 50, 'str' => 'r' },

    'snp_fake' => {
      'str' => 'f',
      'tag' => 3,
      'on'=>'on',
      'pos'=>50,
      'available'=> 'databases ENSEMBL_VARIATION', 
      'colours'=>{$self->{'_colourmap'}->colourSet('variation')}, 
    },

    'snp_fake_haplotype' => {
      'str' => 'r',
      'on'=>'off',
      'pos'=>10001,
      'available'=> 'databases ENSEMBL_VARIATION',
    },
   'TSV_missing' => {
      'on'  => "on",
      'bump_width' => 0,
      'dep' => 0.1,
      'pos' => '5523',
      'str' => 'r',
      'col' => 'blue',
    },

    'variation_legend' => {
      'on'          => "on",
      'str'         => 'r',
      'pos'         => '9999',
    },

    'TSV_haplotype_legend' => {
      'on'          => "off",
      'str'         => 'r',
      'pos'         => '10004',
     'available'    => 'databases ENSEMBL_VARIATION',
     'colours'      => {$self->{'_colourmap'}->colourSet('haplotype')}, 
				   },
  };
}
1;
