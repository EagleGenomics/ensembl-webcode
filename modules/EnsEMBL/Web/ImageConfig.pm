package EnsEMBL::Web::ImageConfig;

use strict;
use Data::Dumper;
use Storable qw( nfreeze freeze thaw);
use Sanger::Graphics::TextHelper;
use Bio::EnsEMBL::Registry;
use EnsEMBL::Web::OrderedTree;

my $reg = "Bio::EnsEMBL::Registry";

#########
# 'general' settings contain defaults.
# 'user' settings are restored from cookie if available
# 'general' settings are overridden by 'user' settings
#

sub new {
  my $class   = shift;
  my $adaptor = shift;
  my $type    = $class =~/([^:]+)$/ ? $1 : $class;
  my $style   = $adaptor->get_species_defs->ENSEMBL_STYLE || {};
  my $self = {
    '_colourmap'        => $adaptor->colourmap,
    '_font_face'        => $style->{GRAPHIC_FONT}                                   || 'Arial',
    '_font_size'        => ( $style->{GRAPHIC_FONTSIZE} * $style->{GRAPHIC_LABEL} ) || 20,
    '_texthelper'       => new Sanger::Graphics::TextHelper,
    '_db'               => $adaptor->get_adaptor,
    'type'              => $type,
    'species'           => $ENV{'ENSEMBL_SPECIES'} || '',
    'species_defs'      => $adaptor->get_species_defs,
    'exturl'            => $adaptor->exturl,
    'general'           => {},
    'user'              => {},
    '_useradded'        => {}, # contains list of added features....
    '_r'                => undef, # $adaptor->{'r'} || undef,
    'no_load'           => undef,
    'storable'          => 1,
    'altered'           => 0,

## Core objects...       { for setting URLs .... }
    '_core'             => undef,
## Glyphset tree...      { Tree of glyphsets to render.... }
    '_tree'             => EnsEMBL::Web::OrderedTree->new(),
## Generic parameters... { Generic parameters for glyphsets.... }
    '_parameters'       => {},
## Better way to store cache { 
    '_cache'            => {}

  };

  bless($self, $class);

  ########## init sets up defaults in $self->{'general'}
  $self->init( ) if($self->can('init'));
  $self->{'no_image_frame'}=1;
  $self->das_sources( @_ ) if(@_); # we have das sources!!
  ########## load sets up user prefs in $self->{'user'}
#  $self->load() unless(defined $self->{'no_load'});
  return $self;
}

#=============================================================================
# General setting/getting cache values...
#=============================================================================

sub cache {
  my $self = shift;
  my $key  = shift;
  $self->{'_cache'}{$key} = shift if @_;
  return $self->{'_cache'}{$key}
}

#=============================================================================
# General setting/getting parameters...
#=============================================================================

sub set_parameters {
  my( $self, $params ) = @_;

  foreach (keys %$params) {
    $self->{'_parameters'}{$_} = $params->{$_};
  } 
}

sub get_parameters {
  my $self = shift;
  return $self->{'_parameters'};
}

sub get_parameter {
  my($self,$key) = @_;
  return $self->{'_parameters'}{$key};
}

sub set_parameter {
  my($self,$key,$value) = @_;
  $self->{'_parameters'}{$key} = $value;
}

#-----------------------------------------------------------------------------
# Specific parameter setting - image width/container width
#-----------------------------------------------------------------------------
sub title {
  my $self = shift;
  $self->set_parameter( 'title', shift ) if @_;
  return $self->get_parameter( 'title' );
}

sub container_width {
  my $self = shift;
  $self->set_parameter( 'container_width', shift ) if @_;
  return $self->get_parameter( 'container_width' );
}

sub image_width {
  my $self = shift;
  $self->set_parameter( 'image_width', shift ) if @_;
  return $self->get_parameter( 'image_width' );
}

sub slice_number {
  my $self = shift;
  $self->set_parameter( 'slice_number', shift ) if @_;
  return $self->get_parameter( 'slice_number' );
}

#=============================================================================
# General setting tree stuff...
#=============================================================================


sub tree {
  return $_[0]{_tree};
}

### create_menus - takes an "associate array" i.e. ordered key value pairs
### to configure the menus to be seen on the display..
### key and value pairs are the code and the text of the menu...

sub create_menus {
  my( $self, @list ) = @_;
  while( my( $key, $caption ) = splice(@list,0,2) ) {
    $self->create_submenu( $key, $caption );
  }
}

### load_tracks - loads in various database derived tracks; 
###   loop through core like dbs, compara like dbs, funcgen like dbs;
###                variation like dbs

sub load_tracks() { 
  my $self       = shift;
  my $species    = $ENV{'ENSEMBL_SPECIES'};
  my $dbs_hash   = $self->species_defs->databases;
  my $multi_hash = $self->species_defs->multi_hash;
  foreach my $db ( @{$self->species_defs->core_like_databases} ) {
    next unless exists $dbs_hash->{$db};
    my $key = $db eq 'ENSEMBL_DB' ? 'core' : lc(substr($db,8));
    warn "   ### adding core like tracks ($key)";
## Look through tables in databases and add data from each one...
    $self->add_dna_align_feature(     $key,$dbs_hash->{$db}{'tables'} ); # To cDNA/mRNA, est, RNA, other_alignment trees ##DONE
    $self->add_ditag_feature(         $key,$dbs_hash->{$db}{'tables'} ); # To ditag_feature tree                         ##DONE
    $self->add_gene(                  $key,$dbs_hash->{$db}{'tables'} ); # To gene, transcript, align_slice_transcript, tsv_transcript trees
    $self->add_marker_feature(        $key,$dbs_hash->{$db}{'tables'} ); # To marker tree                                ##DONE
    $self->add_qtl_feature(           $key,$dbs_hash->{$db}{'tables'} ); # To marker tree                                ##DONE
    $self->add_misc_feature(          $key,$dbs_hash->{$db}{'tables'} ); # To misc_feature tree                          ##DONE
    $self->add_oligo_probe(           $key,$dbs_hash->{$db}{'tables'} ); # To oligo tree                                 ##DONE
    $self->add_prediction_transcript( $key,$dbs_hash->{$db}{'tables'} ); # To prediction_transcript tree                 ##DONE
    $self->add_protein_align_feature( $key,$dbs_hash->{$db}{'tables'} ); # To protein_align_feature_tree                 ##DONE
    $self->add_protein_feature(       $key,$dbs_hash->{$db}{'tables'} ); # To protein_feature_tree                       ## 2 do ##
    $self->add_repeat_feature(        $key,$dbs_hash->{$db}{'tables'} ); # To repeat_feature tree                        ##DONE
    $self->add_simple_feature(        $key,$dbs_hash->{$db}{'tables'} ); # To simple_feature tree                        ##DONE
    $self->add_assemblies(            $key,$dbs_hash->{$db}{'tables'} ); # To sequence tree!                             ## 2 do ##
  }
  foreach my $db ( 'ENSEMBL_COMPARA') {   # @{$self->species_defs->get_config('compara_databases')} ) {
    next unless exists $multi_hash->{$db};
    my $key = lc(substr($db,8));
    warn "   ### adding compara like tracks ($key)";
    ## Configure dna_dna_align features and synteny tracks
    $self->add_synteny(               $key,$multi_hash->{$db}, $species ); # Add to synteny tree                         ##DONE
    $self->add_alignments(            $key,$multi_hash->{$db}, $species ); # Add to compara_align tree                   ##DONE
  }
  foreach my $db ( 'ENSEMBL_FUNCGEN' ) {  # @{$self->species_defs->get_config('funcgen_databases')} ) {
    next unless exists $dbs_hash->{$db};
    my $key = lc(substr($db,8));
    warn "   ### adding func gen like tracks ($key)";
    ## Configure 
    $self->add_regulation_feature(    $key,$dbs_hash->{$db}{'tables'} ); # Add to regulation_feature tree
  }
  foreach my $db ( 'ENSEMBL_VARIATION' ) { # @{$self->species_defs->get_config('variation_databases')} ) {
    next unless exists $dbs_hash->{$db};
    my $key = lc(substr($db,8));
    warn "   ### adding variation like tracks ($key)";
    ## Configure variation features
    $self->add_variation_feature(     $key,$dbs_hash->{$db}{'tables'} ); # To variation_feature tree
  }
  ## Now we do the das stuff - to append to menus (if the menu exists!!)
  foreach my $das( qw(das_sources) ) { ## Add to approriate menu if it exists!!
    next;
    $self->add_source( $das );
  }
}

#-----------------------------------------------------------------------------
# Functions to add tracks from core like databases....
#-----------------------------------------------------------------------------

sub _check_menus {
  my $self = shift;
  foreach( @_ ) {
    return 1 if $self->tree->get_node( $_ );
  }
  return 0;
}

sub _merge {
  my( $self, $_sub_tree, $sub_type ) = @_;
  my $data = {};
  my $tree = $_sub_tree->{'analyses'};
  foreach my $analysis (keys %$tree) {
    my $sub_tree = $tree->{$analysis};
    next unless $sub_tree->{'disp'}; ## Don't include non-displayable tracks
    next if exists $sub_tree->{'web'}{ $sub_type }{'do_not_display'};
    my $key = $sub_tree->{'web'}{'key'} || $analysis;
    $data->{$key}{'name'}    ||= $sub_tree->{'web'}{'name'};     # Longer form for help and configuration!
    $data->{$key}{'type'}    ||= $sub_tree->{'web'}{'type'};
    $data->{$key}{'caption'} ||= $sub_tree->{'web'}{'caption'};  # Short form for LHS
    $data->{$key}{'on'}      ||= $sub_tree->{'web'}{'on'};       # Weather to display the track!!
    if( $sub_tree->{'web'}{'key'} ) {
      if( $sub_tree->{'desc'} ) {
        $data->{$key}{'html_desc'} ||= "<dl>\n";
	$data->{$key}{'description'}      ||= '';
        $data->{$key}{'html_desc'} .= sprintf(
          "  <dt>%s</dt>\n  <dd>%s</dd>\n",
          CGI::escapeHTML( $sub_tree->{'web'}{'name'}       ),     # Description for pop-help - merged of all descriptions!!
          CGI::escapeHTML( $sub_tree->{'desc'})
        );
	$data->{$key}{'description'}.= ($data->{$key}{'description'}?'; ':'').$sub_tree->{'desc'};
      }
    } else {
      $data->{$key}{'description'} = $sub_tree->{'desc'};
      $data->{$key}{'html_desc'} .= sprintf(
        '<p>%s</p>',
        CGI::escapeHTML( $sub_tree->{'desc'})
      );
    }
    push @{$data->{$key}{'logic_names'}}, $analysis;
  }
  foreach my $key (keys %$data) {
    $data->{$key}{'name'} ||= $tree->{$key}{'name'};
    $data->{$key}{'caption'} ||= $data->{$key}{'name'} || $tree->{$key}{'name'};
    $data->{$key}{'description'} .= '</dl>' if $data->{$key}{'description'} =~ '<dl>';
  }
  return ( [sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data], $data );
}

sub add_assemblies {
  my( $self, $key, $hashref ) = @_;
  return unless $self->_check_menus( 'sequence' );
}

### add_dna_align_feature...
### loop through all core databases - and attach the dna align
### features from the dna_align_feature tables...
### these are added to one of four menus: cdna/mrna, est, rna, other
### depending whats in the web_data column in the database

sub add_dna_align_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->_check_menus( 'dna_align_cdna' );
  my( $keys, $data ) = $self->_merge( $hashref->{'dna_align_feature'} , 'dna_align' );
  
  foreach my $key_2 ( @$keys ) {
    my $K = $data->{$key_2}{'type'}||'other';
    my $menu = $self->tree->get_node( "dna_align_$K" );
    if( $menu ) {
      $menu->append( $self->create_track( 'dna_align_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
        'db'          => $key,
        'glyphset'    => '_alignment',
        'sub_type'    => lc($K),
        'colourset'   => 'feature',
        'logicnames'  => $data->{$key_2}{'logic_names'},
        'caption'     => $data->{$key_2}{'caption'},
        'description' => $data->{$key_2}{'description'},
        'on'          => $data->{$key_2}{'on'}||'on', ## Default to on at the moment - change to off by default!
	'strand'      => 'b'
      }));
    }
  }
}

### add_protein_align_feature...
### loop through all core databases - and attach the protein align
### features from the protein_align_feature tables...

sub add_protein_align_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->_check_menus( 'protein_align' );
  my( $keys, $data ) = $self->_merge( $hashref->{'protein_align_feature'} );
  
  my $menu = $self->tree->get_node( "protein_align" );
  foreach my $key_2 ( @$keys ) {
    $menu->append( $self->create_track( 'protein_'.$key.'_'.$key_2, $data->{$key_2}{'name'},{
      'db'          => $key,
      'glyphset'    => '_alignment',
      'sub_type'    => 'protein',
      'object_type' => 'ProteinAlignFeature',
      'colourset'   => 'feature',
      'logicnames'  => $data->{$key_2}{'logic_names'},
      'caption'     => $data->{$key_2}{'caption'},
      'description' => $data->{$key_2}{'description'},
      'on'          => $data->{$key_2}{'on'}||'on', ## Default to on at the moment - change to off by default!
      'strand'      => 'b'
    }));
  }
}

sub add_simple_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'simple' );
  my( $keys, $data ) = $self->_merge( $hashref->{'simple_feature'} );
  
  my $menu = $self->tree->get_node( "simple" );
  foreach my $key_2 ( @$keys ) {
    $menu->append( $self->create_track( 'simple_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
      'db'          => $key,
      'glyphset'    => '_simple',
      'logicnames'  => $data->{$key_2}{'logic_names'},
      'colourset'   => 'simple',
      'caption'     => $data->{$key_2}{'caption'},
      'description' => $data->{$key_2}{'description'},
      'on'          => $data->{$key_2}{'on'}||'on', ## Default to on at the moment - change to off by default!
      'strand'      => 'r'
    }));
  }
}

sub add_prediction_transcript {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'prediction' );
  my( $keys, $data ) = $self->_merge( $hashref->{'prediction_transcript'} );
  
  my $menu = $self->tree->get_node( "prediction" );
  foreach my $key_2 ( @$keys ) {
    $menu->append( $self->create_track( 'prediction_transcript_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
      'db'          => $key,
      'glyphset'    => '_prediction_transcript',
      'logicnames'  => $data->{$key_2}{'logic_names'},
      'caption'     => $data->{$key_2}{'caption'},
      'colourset'   => 'prediction',
      'description' => $data->{$key_2}{'description'},
      'on'          => $data->{$key_2}{'on'}||'on', ## Default to on at the moment - change to off by default!
      'strand'      => 'b'
    }));
  }
}

sub add_ditag_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->_check_menus( 'ditag' );
  my( $keys, $data ) = $self->_merge( $hashref->{'ditag_feature'} );
  my $menu = $self->tree->get_node( 'ditag' );
  foreach my $key_2 ( @$keys ) {
    if( $menu ) {
      $menu->append( $self->create_track( 'ditag_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
        'db'          => $key,
        'glyphset'    => '_ditag',
        'logicnames'  => $data->{$key_2}{'logic_names'},
        'caption'     => $data->{$key_2}{'caption'},
        'description' => $data->{$key_2}{'description'},
        'on'          => $data->{$key_2}{'on'}||'on', ## Default to on at the moment - change to off by default!
	'strand'      => 'b'
      }));
    }
  }
}

### add_gene...
### loop through all core databases - and attach the gene
### features from the gene tables...
### there are a number of menus sub-types these are added to:
### * gene                    # genes
### * transcript              # ordinary transcripts
### * alignslice_transcript   # transcripts in align slice co-ordinates
### * tse_transcript          # transcripts in collapsed intro co-ords
### * tsv_transcript          # transcripts in collapsed intro co-ords
### * gsv_transcript          # transcripts in collapsed gene co-ords
### depending on which menus are configured

sub add_gene {
  my( $self, $key, $hashref ) = @_;
## Gene features end up in each of these menus..

  my @types = qw(transcript alignslice_transcript tsv_transcript gsv_transcript tse_transcript gene);

  return unless $self->_check_menus( @types );

  my( $keys, $data )   = $self->_merge( $hashref->{'gene'}, 'gene' );

  my $flag = 0;
  foreach my $type ( @types ) {
    my $menu = $self->get_node( $type );
    next unless $menu;
    foreach my $key_2 ( @$keys ) {
      $menu->append( $self->create_track( $type.'_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
        'db'          => $key,
        'glyphset'    => ($type=~/_/?'':'_').$type, ## QUICK HACK..
        'logicnames'  => $data->{$key_2}{'logic_names'},
	'colours'     => $self->species_defs->colour( 'gene' ),
        'caption'     => $data->{$key_2}{'caption'},
        'description' => $data->{$key_2}{'description'},
        'on'          => $data->{$key_2}{'on'}||'on', ## Default to on at the moment - change to off by default!
	'strand'      => $type eq 'gene' ? 'r' : 'b'
      }));
      $flag=1;
    }
  }
  ## Need to add the gene menu track here....
  if( $flag ) {
    $self->add_track( 'information', 'gene_legend', 'Gene Legend', 'gene_legend', { 'strand' => 'r' } );
  }
}

sub add_marker_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'marker' );
  my( $keys, $data ) = $self->_merge( $hashref->{'marker_feature'} );
  my $menu      = $self->get_node( 'marker' );
  foreach my $key_2 (@$keys) {
    $menu->append( $self->create_track( 'marker_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
      'db'          => $key,
      'glyphset'    => '_marker',
      'labels'      => 'on',
      'logicnames'  => $data->{$key_2}{'logic_names'},
      'caption'     => $data->{$key_2}{'caption'},
      'colours'     => $self->species_defs->colour( 'marker' ),
      'description' => $data->{$key_2}{'description'},
      'on'          => 'on',
      'strand'      => 'r'
    }));
  }
}

sub add_qtl_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'marker' );
  my( $keys, $data ) = $self->_merge( $hashref->{'qtl'} );
  my $menu      = $self->get_node( 'marker' );
  foreach my $key_2 (@$keys) {
    $menu->append( $self->create_track( 'qtl_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
      'db'          => $key,
      'glyphset'    => '_qtl',
      'logicnames'  => $data->{$key_2}{'logic_names'},
      'caption'     => $data->{$key_2}{'caption'},
      'colourset'   => 'qtl',
      'description' => $data->{$key_2}{'description'},
      'on'          => 'on',
      'strand'      => 'r'
    }));
  }
}

sub add_misc_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'misc_feature' );
  my $menu = $self->get_node('misc_feature');
  ## Different loop - no analyses - just misc_sets... 
  my $data = $hashref->{'misc_feature'}{'sets'};
  foreach my $key_2 ( sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data ) {
    $menu->append( $self->create_track( 'misc_feature_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
      'glyphset'    => '_clone',
      'db'          => $key,
      'set'         => $key_2,
      'colourset'   => 'clone',
      'caption'     => $data->{$key_2}{'name'},
      'description' => $data->{$key_2}{'desc'},
      'max_length'  => $data->{$key_2}{'max_length'},
      'strand'      => 'r',
      'on'          => 'on'
    }));
  }

}

sub add_oligo_probe {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'oligo' );

  my $menu = $self->get_node('oligo');
  my $data = $hashref->{'oligo_feature'}{'arrays'};
  my $description = $hashref->{'oligo_feature'}{'analyses'}{'AlignAffy'}{'desc'};
  ## Different loop - no analyses - base on probeset query results... = $hashref->{'oligo_feaature'}{'arrays'};
  foreach my $key_2 ( sort keys %$data ) {
    $menu->append( $self->create_track( 'oligo_'.$key.'_'.$key_2, $key_2, {
      'glyphset'    => '_oligo',
      'db'          => $key,
      'sub_type'    => 'oligo',
      'array'       => $key_2,
      'object_type' => 'OligoProbe',
      'colourset'   => 'feature',
      'description' => $description,
      'caption'     => $key_2,
      'strand'      => 'b',
      'on'          => 'on'
    }));
  }
}


sub add_protein_feature {
  my( $self, $key, $hashref ) = @_;

  my %menus = (
    'domain'     => [ 'domain',  'P_domain' ],
    'feature'    => [ 'feature', 'P_feature' ],
    'gsv_domain' => [ 'domain',  'GSV_domain']
  );
  ## We have two separate glyphsets in this in this case
  ## P_feature and P_domain - plus domains get copied onto GSV_generic_domain as well...

  return unless $self->_check_menus( keys %menus );

  my( $keys, $data )   = $self->_merge( $hashref->{'gene'} );

  foreach my $menu_code ( keys %menus ) {
    my $menu = $self->get_node( $menu_code );
    next unless $menu;
    my $type = $menus{$menu_code}[0];
    my $gset = $menus{$menu_code}[1];
    foreach my $key_2 ( @$keys ) {
      next if $type ne $data->{$key_2}{'type'};
      $menu->append( $self->create_track( $type.'_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
        'db'          => $key,
        'glyphset'    => $gset,
        'logicnames'  => $data->{$key_2}{'logic_names'},
        'name'        => $data->{$key_2}{'name'},
        'caption'     => $data->{$key_2}{'caption'},
	'colours'     => $self->species_defs->colour( 'protein' ),
        'description' => $data->{$key_2}{'description'},
        'on'          => $data->{$key_2}{'on'}||'on', ## Default to on at the moment - change to off by default!
      }));
    }
  }
}

sub add_repeat_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'repeat' );
## Add generic feature track...
  return unless $hashref->{'repeat_feature'}{'rows'}>0; ## We have repeats...
  my $data = $hashref->{'repeat_feature'}{'analyses'};
  my $menu = $self->get_node( 'repeat' );
  $menu->append( $self->create_track( 'repeat_'.$key, "All repeats", {
    'db'          => $key,
    'glyphset'    => '_repeat',
    'logicnames'  => [undef],                ## All logic names...
    'types'       => [undef],                ## All repeat types...
    'name'        => 'All repeats',
    'description' => 'All repeats',
    'colours'     => $self->species_defs->colour( 'repeat' ),
    'on'          => 'on',
    'optimizable' => 1,
    'depth'       => 0.5,
    'bump_width'  => 0,
    'strand'      => 'r'
  }));
  my $flag = keys %$data > 1;
  foreach my $key_2 ( sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data ) {
## Add track for each analysis ()... break down 1
    if( $flag ) {
      $menu->append( $self->create_track( 'repeat_'.$key.'_'.$key_2, $data->{$key_2}{'name'}, {
        'db'          => $key,
        'glyphset'    => '_repeat',
        'logicnames'  => [ $key_2 ],           ## Restrict to a single supset of logic names...
	'types'       => [ undef  ],
        'name'        => $data->{$key_2}{'name'},
        'description' => $data->{$key_2}{'desc'},
	'colours'     => $self->species_defs->colour( 'repeat' ),
        'on'          => 'on',
        'optimizable' => 1,
        'depth'       => 0.5,
        'bump_width'  => 0,
	'strand'      => 'r'
      }));
    }
## Add track for each repeat_type ();
    my $d2 = $data->{$key_2}{'types'};
    if( keys %$d2 > 1 ) {
      foreach my $key_3 ( sort keys %$d2 ) {
        (my $key_3a = $key_3) =~ s/\W/_/g;
        $menu->append( $self->create_track( 'repeat_'.$key.'_'.$key_2.'_'.$key_3a, "$key_3 (".$data->{$key_2}{'name'}.")",{
          'db'          => $key,
          'glyphset'    => '_repeat',
          'logicnames'  => [ $key_2 ],
          'types'       => [ $key_3 ],
          'name'        => "$key_3 (".$data->{$key_2}{'name'}.")",
          'description' => $data->{$key_2}{'desc'}." ($key_3)",
	  'colours'     => $self->species_defs->colour( 'repeat' ),
          'on'          => 'on',
          'optimizable' => 1,
          'depth'       => 0.5,
          'bump_width'  => 0,
	  'strand'      => 'r'
        }));
      }
    }
  }
}

#----------------------------------------------------------------------#
# Functions to add tracks from compara like databases....
#----------------------------------------------------------------------#

sub add_synteny {
  my( $self, $key, $hashref, $species ) = @_;
  return unless $self->get_node( 'synteny' );
  my @synteny_species = sort keys %{$hashref->{'SYNTENY'}{$species}||{}};
  return unless @synteny_species;
  my $menu = $self->get_node( 'synteny' );
  foreach my $species ( @synteny_species ) {
    ( my $species_readable = $species ) =~ s/_/ /g;
    $menu->append( $self->create_track( 'synteny_'.$species, "Synteny with $species_readable", {
      'db'          => $key,
      'glyphset'    => '_synteny',
      'name'        => "Synteny with $species_readable",
      'caption'     => sprintf( "%1s.%3s synteny", split / /, $species_readable ),
      'description' => "Synteny blocks",
      'colours'     => $self->species_defs->colour( 'synteny' ),
      'on'          => 'on',
      'strand'      => 'r'
    }));
  }
}

sub add_alignments {
  my( $self, $key, $hashref,$species ) = @_;
  return unless $self->_check_menus( qw(multiple_align pairwise_tblat pairwise_blastz pairwise_other) );
  my $alignments = {};
  foreach my $row ( values %{$hashref->{'ALIGNMENTS'}} ) {
    next unless $row->{'species'}{$species};
    if( $row->{'class'} =~ /pairwise_alignment/ ) {
      my( $other_species ) = grep { $species ne $_ } keys %{$row->{'species'}};
      my $menu_key = $row->{'type'} =~ /BLASTZ/ ? 'pairwise_blastz' 
                   : $row->{'type'} =~ /TRANSLATED_BLAT/  ? 'pairwise_tblat'
		   : 'pairwise_align'
		   ;
      $alignments->{$menu_key}{ $row->{'id'} } = {
        'db' => $key,
        'glyphset'       => '_alignment_pairwise',
        'name'           => $row->{'name'},
        'type'           => $row->{'type'},
        'species_set_id' => $row->{'species_set_id'},
        'other_species'  => $other_species,
        'class'          => $row->{'class'},
        'description'    => "Pairwise alignments",
        'order'          => $row->{'type'}.'::'.$other_species,
	'colours'        => $self->species_defs->colour( 'pairwise' ),
	'strand'         => 'b',
        'on'             => 'on'
      };
    } else {
      my $n_species = keys %{$row->{'species'}};
      $alignments->{'multiple_align'}{ $row->{'id'} } = {
        'db' => $key,
        'glyphset'       => '_alignment_multiple',
        'name'           => $row->{'name'},
        'type'           => $row->{'type'},
        'species_set_id' => $row->{'species_set_id'},
        'class'          => $row->{'class'},
        'constrained_element' => $row->{'constrained_element'},
        'conservation_score'  => $row->{'conservation_score'},
        'description'    => "Multiple alignments",
	'colours'     => $self->species_defs->colour( 'multiple' ),
        'order'          => sprintf '%12d::%s::%s',1e12-$n_species, $row->{'type'}, $row->{'name'},
	'strand'         => 'b',
	'on'             => 'on'
      };
    } 
  }
  foreach my $menu_key ( keys %$alignments ) {
    my $menu = $self->get_node( $menu_key );
    next unless $menu;
    foreach my $key_2 ( sort {
      $alignments->{$menu_key}{$a}{'order'} cmp  $alignments->{$menu_key}{$b}{'order'}
    } keys %{$alignments->{$menu_key}} ) {
      my $row = $alignments->{$menu_key}{$key_2};
      $menu->append( $self->create_track( 'alignment_'.$key.'_'.$key_2, $row->{'name'}, $row ));
    }
  }
}

sub add_option {
  my( $self, $key, $caption, $values ) = @_;
  my $menu = $self->get_node( 'options' );
  return unless $menu;
  $menu->append( $self->create_option( $key, $caption, $values ) );
}

sub add_options {
  my $self = shift;
  my $menu = $self->get_node( 'options' );
  return unless $menu;
  foreach my $row (@_) {
    my ($key, $caption, $values ) = @$row;
    $menu->append( $self->create_option( $key, $caption, $values ) );
  } 
}

sub create_track {
  my ( $self, $code, $caption, $options ) = @_;
  my $details = { 'name'    => $caption, 'node_type' => 'track' };
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  $details->{'strand'}   ||= 'b';  # Make sure we have a strand setting!!
  $details->{'on'    }   ||= 'on'; # Show unless we explicitly say no!!
  $details->{'colours'}  ||= $self->species_defs->colour( $options->{'colourset'} ) if exists $options->{'colourset'};
  $details->{'glyphset'} ||= $code;
  $details->{'caption'}  ||= $caption;
  $self->tree->create_node( $code, $details );
}

sub add_track {
  my( $self, $menu_key, $key, $caption, $glyphset, $params ) = @_;
  my $menu =  $self->get_node( $menu_key );
  return unless $menu;
  return if $self->get_node( $key ); ## Don't add duplicates...
  $params->{'glyphset'} = $glyphset;
  $menu->append( $self->create_track( $key, $caption, $params ) );
}

sub add_tracks {
  my $self     = shift;
  my $menu_key = shift;
  my $menu =  $self->get_node( $menu_key );
  return unless $menu;
  foreach my $row (@_) {
    my ( $key, $caption, $glyphset, $params ) = @$row; 
    next if $self->get_node( $key ); ## Don't add duplicates...
    $params->{'glyphset'} = $glyphset;
    $menu->append( $self->create_track( $key, $caption, $params ) );
  }
}

#----------------------------------------------------------------------#
# Functions to add tracks from functional genomics like database....
#----------------------------------------------------------------------#

sub add_regulation_feature {
  my( $self, $key, $hashref ) = @_;
  return unless $self->get_node( 'regulation_feature' );
}

#----------------------------------------------------------------------#
# Functions to add tracks from variation like databases....
#----------------------------------------------------------------------#

sub add_variation_feature {
  my( $self, $key, $hashref ) = @_;
  my $menu = $self->get_node( 'variation' );
  return unless $menu;
  return unless $hashref->{'variation_feature'}{'rows'} > 0;
  $menu->append( $self->create_track( 'variation_feature_'.$key, sprintf( "All variations" ), {
    'db'          => $key,
    'glyphset'    => '_variation',
    'sources'     => undef,
    'strand'      => 'r',
    'depth'       => 0.5,
    'bump_width'  => 0,
    'colourset'   => 'variation',
    'description' => 'Variation features from all sources'
  }));
  $menu->append( $self->create_track( 'variation_feature_genotyped_'.$key, sprintf( "Genotyped variations" ), {
    'db'          => $key,
    'glyphset'    => '_variation',
    'sources'     => undef,
    'strand'      => 'r',
    'depth'       => 0.5,
    'bump_width'  => 0,
    'filter'      => 'genotyped',
    'colourset'   => 'variation',
    'description' => 'Genotyped variation features from all sources'
  }));

  foreach my $key_2 (sort keys %{$hashref->{'source'}{'counts'}||{}}) {
    ( my $k = $key_2 ) =~ s/\W/_/g;
    $menu->append( $self->create_track( 'variation_feature_'.$key.'_'.$k, sprintf( "%s variations", $key_2 ), {
      'db'          => $key,
      'glyphset'    => '_variation',
      'caption'     => $key_2,
      'sources'     => [ $key_2 ],
      'strand'      => 'r',
      'depth'       => 0.5,
      'bump_width'  => 0,
      'colourset'   => 'variation',
      'description' => sprintf( 'Variation features from the "%s" source', $key_2 )
    }));
  }
}

## return a list of glyphsets...
sub glyphset_configs {
  my $self = shift;
  return grep { $_->data->{'node_type'} eq 'track' } $self->tree->nodes;
}

sub get_node {
  my $self = shift;
  return $self->tree->get_node(@_);
}

sub create_submenu {
  my ($self, $code, $caption, $options ) = @_;
  my $details = { 'caption'    => $caption, 'node_type' => 'menu' };
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  return $self->tree->create_node( $code, $details );
}


sub create_option {
  my ( $self, $code, $caption, $values ) = @_;
  $values ||= {qw(0 no 1 yes)};
  return $self->tree->create_node( $code, {
    'node_type' => 'option',
    'caption'   => $caption,
    'name'      => $caption,
    'values'    => $values,
  });
}

sub _set_core { $_[0]->{'_core'} = $_[1]; }
sub core_objects { return $_[0]->{'_core'}; }

sub storable :lvalue {
### a
### Set whether this ScriptConfig is changeable by the User, and hence needs to
### access the database to set storable do $script_config->storable = 1; in SC code...
  $_[0]->{'storable'};
}
sub altered :lvalue {
### a
### Set to one if the configuration has been updated...
  $_[0]->{'altered'};
}

sub TRIM   { return sub { return $_[0]=~/(^[^\.]+)\./ ? $1 : $_[0] }; }

sub update_config_from_parameter {
  my( $self, $string ) = @_;
  my @array = split /\|/, $string;
  shift @array;
  return unless @array;
  foreach( @array ) {
    my( $key, $value ) = /^(.*):(.*)$/;
    if( $key =~ /bump_(.*)/ ) {
      $self->set( $1, 'compact', $value eq 'on' ? 0 : 1 );
    } elsif( $key eq 'imagemap' || $key=~/^opt_/ ) {
      $self->set( '_settings', $key, $value eq 'on' ? 1: 0 );
    } elsif( $key =~ /managed_(.*)/ ) {
      $self->set( $key, 'on', $value, 1 );
    } else {
      $self->set( $key, 'on', $value );
    }
  }
  #$self->save; - deprecated
}

sub set_species {
  my $self = shift;
  $self->{'species'} = shift; 
}

sub get_user_settings {
  my $self = shift;
  return $self->{'user'};
}

sub artefacts { my $self = shift; return @{ $self->{'general'}->{$self->{'type'}}->{'_artefacts'}||[]} };

sub remove_artefacts {
  my $self = shift;
  my %artefacts = map { ($_,1) } @_;
  @{ $self->{'general'}->{$self->{'type'}}->{'_artefacts'} } = 
    grep { !$artefacts{$_} } $self->subsections( );
}
  
sub add_artefacts {
  my $self = shift;
  $self->_set( $_, 'on', 'on') foreach @_;
  push @{$self->{'general'}->{$self->{'type'}}->{'_artefacts'}}, @_;
}

# add general and artefact settings
sub add_settings {
    my $self = shift;
    my $settings = shift;
    foreach (keys %{$settings}) {
        $self->{'general'}->{$self->{'type'}}->{$_} = $settings->{$_};
    }
}

sub turn_on {
  my $self = shift;
  $self->_set( $_, 'on', 'on') foreach( @_ ? @_ : $self->subsections( 1 ) ); 
}

sub turn_off {
  my $self = shift;
  $self->_set( $_, 'on', 'off') foreach( @_ ? @_ : $self->subsections( 1 ) ); 
}

sub _set {
  my( $self, $entry, $key, $value ) = @_;
  $self->{'general'}->{$self->{'type'}}->{$entry}->{$key} = $value;
}

sub save {
  my ($self) = @_;
  warn "UserConfig->save - Deprecated call now handled by session";
  return;
    $self->{'_db'}->setConfigByName(
    	$self->{'_r'}, $ENV{'ENSEMBL_FIRSTSESSION'}, $self->{'type'},
    	&Storable::nfreeze($self->{'user'})
    ) if $self->{'_db'};
  return;
}

sub reset {
  my ($self) = @_;
  my $script = $self->script();
  $self->{'user'}->{$script} = {}; 
  $self->altered = 1;
  return;
}

sub reset_subsection {
  my ($self, $subsection) = @_;
  my $script = $self->script();
  return unless(defined $subsection);

  $self->{'user'}->{$script}->{$subsection} = {}; 
  $self->altered = 1;
  return;
}

sub species_defs {
### a
  my $self = shift;
  return $self->{'species_defs'};
}

sub colourmap {
### a
  my $self = shift;
  return $self->{'_colourmap'};
}

sub image_height {
### a
  my $self = shift;
  $self->set_parameter('_height',shift) if @_;
  return $self->get_parameter('_height');
}

sub bgcolor {
### a
  my $self = shift;
  $self->get_parameter( 'bgcolor' );
}

sub bgcolour {
### a
  my $self = shift;
  return $self->bgcolor;
}

sub texthelper {
### a
  my $self = shift;
  return $self->{'_texthelper'};
}

sub scalex {
  my $self = shift;
  if(@_) {
    $self->{'_scalex'} = shift;
    $self->{'_texthelper'}->scalex($self->{'_scalex'});
  }
  return $self->{'_scalex'};
}

sub set_width {
  my( $self, $val ) = @_;
  $self->set_parameter( 'width', $val );
}
sub container_width {
  my $self = shift;
  if(@_) {
    $self->{'_containerlength'} = $_[0];
    my $width = $self->image_width();
    $self->scalex($width/$_[0]) if $_[0];
  }
  return $self->{'_containerlength'};
}

sub transform {
  my $self = shift;
  return $self->{'transform'};
}

1;
