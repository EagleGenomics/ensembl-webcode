package EnsEMBL::Web::UserConfig::genesnpview_1;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 32;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'general'}->{'genesnpview_1'} = {
    '_artefacts' => [qw(snp_lite transcript_lite geneexon_bgtrack spacer snp_join)],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'show_labels' => 'no',
      'width'   => 900,
      'opt_zclick'     => 1,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',
    },
    'spacer' => { 'on'=>'on','pos'=>1e6, 'height' => 50, 'str' => 'r' },

    'snp_join' => {
      'tag' => 1,
      'on'=>'on','pos'=>4600,
      'available'=> 'database_tables ENSEMBL_LITE.snp',
      'colours'=>{$self->{'_colourmap'}->colourSet('snp')}, 'str' => 'b'
    },
    'ruler' => {
      'on'          => "on",
      'pos'         => '10000',
      'col'         => 'black',
    },
    'stranded_contig' => {
      'on'          => "on",
      'pos'         => '0',
      'navigation'  => 'off'
    },
    'scalebar' => {
      'on'          => "on",
      'nav'         => "off",
      'pos'         => '8000',
      'col'         => 'black',
      'str'         => 'r',
      'abbrev'      => 'on',
      'navigation'  => 'off'
    },
    'geneexon_bgtrack' => {
      'on'          => "on",
      'pos'         => '5000',
      'str'         => 'b',
      'src'         => 'all', # 'ens' or 'all'
      'col'         => 'bisque',
      'tag'         => 1
    }, 
    'transcript_lite' => {
      'on'          => "on",
      'pos'         => '21',
      'str'         => 'b',
      'src'         => 'all', # 'ens' or 'all'
      'colours' => {$self->{'_colourmap'}->colourSet( 'core_gene' )},
    },
    'snp_triangle_lite' => {
      'on'          => "on",
      'pos'         => '4520',
      'str'         => 'r',
      'dep'         => '10',
      'col'         => 'blue',
      'track_height'=> 7,
      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('snp')},
      'available'=> 'database_tables ENSEMBL_LITE.snp', 
    },
    'haplotype' => {
      'on'          => "on",
      'pos'         => '4525',
      'str'         => 'r',
      'dep'         => 6,
      'col'         => 'darkgreen',
      'lab'         => 'black',
      'available'=> 'databases ENSEMBL_HAPLOTYPE',
    },

    'snp_legend' => {
      'on'          => "on",
      'str'         => 'r',
      'pos'         => '9999',
    },
  };
}
1;
