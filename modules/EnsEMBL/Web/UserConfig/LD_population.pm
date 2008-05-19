package EnsEMBL::Web::UserConfig::LD_population;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 30;
  $self->{'_transcript_names_'} = 'yes';
  #$self->{'_no_label'} = 'true';
  $self->{'general'}->{'LD_population'} = {
    '_artefacts' => [qw(
			text
			tagged_snp
			ld_r2
			ld_d_prime 
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
                     [ 'tagged_snp' => "Tagged SNPs"],
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
      'width'     => 800,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background3',
      'bgcolour2' => 'background1',
     },

    'text'    => {
      'on'          => "on",
      'pos'         => '4500',
      'str'         => 'r',
      'dep'         => '10000',
      'col'         => 'blue',
      'track_height'=> 7,
      'compact'     => 0,
      'track_label' => "Population",
      'hi'          => 'black',
      'colours' => {$self->{'_colourmap'}->colourSet('variation')},
      'available'=> 'databases ENSEMBL_VARIATION',
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
  };
}



1;
