package EnsEMBL::Web::UserConfig::ldview;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 30;
  $self->{'_transcript_names_'} = 'yes';
  #$self->{'_no_label'} = 'true';
  $self->{'general'}->{'ldview'} = {
    '_artefacts' => [qw( 
			scalebar
			ruler
			snp_triangle_glovar
			variation
			genotyped_variation
			tagged_snp
			ld_r2
			ld_d_prime 
			variation_legend

                    )],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => { 

       'zoom_gifs'     => {
       'zoom1'   =>  1000,   zoom2   =>  5000,  
       'zoom3'   =>  10000,  zoom4   =>  20000,
       'zoom5'   =>  50000,  zoom6   =>  100000 
      },
      'navigation_options' => [ '500k', '200k', '100k', 
				'window', 'half', 'zoom' ],

     'features' => [
                     [ 'variation'             => "SNPs"          ],
                     [ 'variation_legend'      => "SNP legend"    ],
                     [ 'genotyped_variation'   => "Genotyped SNPs"],
                     [ 'tagged_snp'            => "Tagged SNPs"],
                     [ 'ld_r2'      => "LD (r2)"],
                     [ 'ld_d_prime' => "LD (d')"],
                    ],
      'options' => [
                 [ 'opt_empty_tracks' => 'Show empty tracks' ],
                 [ 'opt_zmenus'      => 'Show popup menus'  ],
                 [ 'opt_zclick'      => '... popup on click'  ],
                   ],
       'snphelp' => [
        [ 'ldview'  => 'LDView' ],
      ],
      'opt_empty_tracks' => 1,
      'opt_zmenus'     => 1,
      'opt_zclick'     => 1,
      'show_labels'      => 'yes',
      'width'     => 900,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background3',
      'bgcolour2' => 'background1',
     },
    'ruler' => {
      'on'          => "on",
      'pos'         => '9999',
      'col'         => 'black',
      'str'         => 'f',
    },

    'scalebar' => {
      'on'          => "on",
      'nav'         => "off",
      'pos'         => '4500',
      'col'         => 'black',
      'str'         => 'r',
      'abbrev'      => 'on',
      'navigation'  => 'off'
    },

    'genotyped_variation' => {
      'on'          => "on",
      'pos'         => '4504',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_height'=> 7,
      'compact'     => 0,
      'track_label' => "Genotyped SNPs",
      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases ENSEMBL_VARIATION',
    },
    'snp_triangle_glovar' => {
      'on'          => "off",
      'pos'         => '4505',
      'str'         => 'r',
      'dep'         => '10',
      'col'         => 'blue',
      'track_height'=> 7,

      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('snp')},
      'available'=> 'database ENSEMBL_GLOVAR', 
    },

    'tagged_snp'    => {
      'on'          => "on",
      'pos'         => '4508',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_height'=> 7,
      'compact'     => 0,
      'track_label' => "Tagged SNPs",
      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases ENSEMBL_VARIATION',
    },

   'variation' => {
      'on'          => "on",
      'pos'         => '4509',
      'str'         => 'r',
      'dep'         => '0.1',
      'col'         => 'blue',
      'track_label' => "Variations",
      'track_height'=> 7,
      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases ENSEMBL_VARIATION', 
    },


    'ld_r2' => {
      'on'          => "on",
      'pos'         => '4611',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_height'=> 7,
      'compact'     => 0,
      'track_label' => "Linkage disequilibrium (r2)",
      'hi'          => 'black',
      'key'         => 'r2',
      'glyphset'    => 'ld',
      'colours'     => {$self->{'_colourmap'}->colourSet('variation')},
      'available'   => 'databases ENSEMBL_VARIATION',
    },
    'ld_d_prime' => {
      'on'          => "on",
      'pos'         => '4712',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_height'=> 7,
      'compact'     => 0,
      'key'         => 'd_prime',
      'track_label' => "Linkage disequilibrium (d')" ,
      'hi'          => 'black',
      'glyphset'    => 'ld',
      'colours'     => {$self->{'_colourmap'}->colourSet('variation')},
      'available'   => 'databases ENSEMBL_VARIATION',
    },

    'variation_legend' => {
      'on'          => "on",
      'str'         => 'r',
      'pos'         => '4566',
    },
  };
  $self->ADD_ALL_TRANSCRIPTS(2000, "compact" =>'1');  #first is position
}



1;
