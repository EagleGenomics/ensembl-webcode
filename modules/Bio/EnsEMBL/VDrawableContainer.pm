package Bio::EnsEMBL::VDrawableContainer;

use strict;
use Bio::EnsEMBL::GlyphSet::Videogram;
use Data::Dumper;

sub _init {
  my $class = shift;
  my $Contents = shift;
  unless(ref($Contents) eq 'ARRAY') {
    $Contents = [[ $Contents, shift ]];
  } else {
    my $T = [];
    while( @$Contents ) {
      push @$T, [splice(@$Contents,0,2)] ;
    }
    $Contents = $T;
  }

  my( $highlights, $strandedness, $spacing, $Storage) = @_;

  my $self = {
    'glyphsets'     => [],
    'config'        => $Contents->[0][1],
    'storage'       => $Storage,
    'prefix'        => 'Bio::EnsEMBL',
    'contents'      => $Contents,
    'highlights'    => $highlights || [],
    'spacing'       => $spacing || $Contents->[0][1]->get_parameter('spacing') || 0,
    'strandedness'  => $strandedness || 0,
    '__extra_block_spacing__'    => 0,
    'timer'         => $Contents->[0][1]->species_defs->timer
  };

  $self->{'strandedness'} = 1 if $self->{'config'}->get_parameter('text_export');

  bless( $self, $class );
  return $self;
}

sub timer_push {
  my( $self, $tag, $dep ) = @_;
  $self->{'timer'}->push( $tag, $dep, 'draw' );
}

sub new {
  my $class        = shift;
  my $self         = $class->_init( @_ );

  ########## loop over all the glyphsets the user wants:

  foreach my $CC ( @{$self->{'contents'}} ) {
    my( $Container,$Config) = @$CC;

    my $tmp = {};
    $Container->{'web_species'} ||= $ENV{'ENSEMBL_SPECIES'};
    my @chromosomes = ($Container->{'chr'});
    my $flag        = 0;
    if( $Config->get_parameter('all_chromosomes') eq 'yes' ) { 
      @chromosomes = @{$Config->species_defs->get_config($Container->{'web_species'}, 'ENSEMBL_CHROMOSOMES')||[]};
      $flag = 1;
    }
    
    my $pos = 100000;
    my $scalex = $Config->get_parameter('image_height') / $Config->get_parameter('container_width');
    $Config->{'transform'}->{'scalex'}         = $scalex;
    $Config->texthelper->{'_scalex'}           = $scalex;
    $Config->{'transform'}->{'absolutescalex'} = 1; # $Config->{'_image_height'} / $Config->image_width();
    $Config->{'transform'}->{'translatex'}    += $Config->get_parameter('top_margin');

    my @glyphsets;
    my @configs = $Config->glyphset_configs;
    my %chr_glyphset_counts = ();
    foreach my $chr ( @chromosomes ) {
      $Container->{'chr'} = $chr;
      foreach my $row_config (@configs) {
        my $display = $row_config->get('display')||($row_config->get('on')eq'on'?'normal':'off');
        next if ($display eq 'off' || $display =~ /highlight/);

        ########## create a new glyphset for this row
        my $glyphset  = $row_config->get('glyphset')||$row_config->code;
        #warn ">>> GLYPHSET $glyphset DISPLAY $display";
        my $classname = qq($self->{'prefix'}::GlyphSet::$glyphset);
        next unless $self->dynamic_use( $classname );

        my $EW_Glyphset;
        eval { # Generic glyphsets need to have the type passed as a fifth parameter...
          $EW_Glyphset = $classname->new({
	          'container'  => $Container,
	          'config'     => $Config,
	          'my_config'  => $row_config,
	          'strand'     => 0,
	          'highlights' => $self->{'highlights'},
            'display'    => $display,
          });
        };
        if($@ || !$EW_Glyphset) {
          my $reason = $@ || "No reason given just returns undef";
          warn "GLYPHSET: glyphset $classname failed (@{[$self->{container}{web_species}]}/$ENV{'ENSEMBL_SCRIPT'} at ".gmtime()."\nGLYPHSET:  $reason";
	        next;
        }
        $EW_Glyphset->{'chr'} = $chr; 

        ## Parse and/or cache data for use on subsequent chromosomes
        if ($row_config->get('id')) {
          my $data = $self->{'storage'}{$row_config->get('id')};
          unless (defined($data->{$chr})) {
            $data = $EW_Glyphset->data(\@chromosomes); 
            $self->{'storage'}{$row_config->get('id')} = $data;
          }
          $EW_Glyphset->{'data'} = $data;
        }

        $EW_Glyphset->render_normal();

        if ( @{$EW_Glyphset->{'glyphs'}||[]}) {
	        push @glyphsets,  $EW_Glyphset;
	        $chr_glyphset_counts{$chr}++;
        }
        elsif (!$row_config->get('hide_empty')) {
	        push @glyphsets,  $EW_Glyphset;
	        $chr_glyphset_counts{$chr}++;
        }
      }
    }

    ########## sort out the resulting mess
    my $spacing = $self->{'spacing'};

    ########## go ahead and do all the database work
    my $yoffset = 0;

## Firstly lets work how many entries to draw per row!
## Then work out the minimum start for each of these rows
## We then shift up all these points up by that many base 
## pairs to close up any gaps

    my( $max_gs_chr ) = sort { $b<=>$a } values %chr_glyphset_counts;
    my $glyphsets = @glyphsets;
    my $GS = $Config->get_parameter( 'group_size' ) || $max_gs_chr;
    my $entries_per_row = $Config->get_parameter( 'columns' ) || ( int( ($glyphsets/$GS - 1) / ($Config->get_parameter('rows') || 1) + 1 ) * $GS );
    $entries_per_row = $max_gs_chr if $max_gs_chr > $entries_per_row;

##  warn ".... $max_gs_chr .... $GS, $entries_per_row ...";
    my $entry_no = 0;
    $Config->set_parameter('max_height', 0);
    $Config->set_parameter('max_width', 0);

    my @min   = ();
    my @max   = ();
    my $row_count = 0;
    my $row_index = 0;
    my $current_chr = undef;
    for my $glyphset (@glyphsets) {
      if( $current_chr ne $glyphset->{'chr'} ) { ## Can we fit all the chr stuff in!
        $row_count += $chr_glyphset_counts{$glyphset->{'chr'}};
        if( $row_count > $entries_per_row ) {
          $row_index++;
          $row_count = 0;
        }
        $current_chr = $glyphset->{'chr'};
      }
      $glyphset->{'row_index'} = $row_index;
      next unless defined($glyphset->minx());
      $min[$row_index] = $glyphset->minx() if(!defined $min[$row_index] || $min[$row_index] > $glyphset->minx() );
    }
    ## Close up gap!
#  my $translateX = shift @row_min;
    my $translateX = shift @min;
    $Config->{'transform'}->{'translatex'} -= $translateX * $scalex; #$xoffset;
    my $xoffset = -$translateX * $scalex;

    my $row_index = 0;

    for my $glyphset (@glyphsets) {
      if( $row_index != $glyphset->{'row_index'} ) {  ## We are on a new row - so reset the yoffset [horizontal] to 0 
        $row_index = $glyphset->{'row_index'};
        $yoffset = 0;
        my $translateX = shift @min;
        $xoffset += $Config->image_width() - $translateX * $scalex;
        ## Shift down - and then close up gap!
        $Config->{'transform'}->{'translatex'} += $Config->image_width() - $translateX * $scalex; #$xoffset;
      }
      $Config->set_parameter( 'max_width',  $xoffset + $Config->get_parameter('image_width') );
      ########## set up the label for this strip 
      ########## first we get the max width of label in characters
      my $feature_type_1 = $glyphset->my_config('feature_type')   || ( $glyphset->my_config('keys') ? $glyphset->my_config('keys')->[0] : undef );
      my $feature_type_2 = $glyphset->my_config('feature_type_2') || ( $glyphset->my_config('keys') ? $glyphset->my_config('keys')->[1] : undef );
      my $label_1 = $glyphset->my_config('label')   || ( $feature_type_1 ? $glyphset->my_colour( $feature_type_1, 'text' ) : undef );
      my $label_2 = $glyphset->my_config('label_2') || ( $feature_type_2 ? $glyphset->my_colour( $feature_type_2, 'text' ) : undef );
      if( $glyphset->{'my_config'}->id eq 'Videogram' && $flag ) {
        $label_1 = $glyphset->{'chr'};
      }
      my $gw  = length( length($label_2) > length($label_1) ? $label_2 : $label_1 );
      if($gw>0) {
        ########## and convert it to pels
        $gw = $Config->texthelper->width('Small');
        ########## If the '_label' position is not 'above' move the labels below the image
        my $label_x = $Config->get_parameter('label') eq 'above' ? 0 : $Config->get_parameter('image_height');
        $label_x   += 4 - $Config->get_parameter('top_margin');
        my $label_y = ($glyphset->maxy() + $glyphset->miny() - $gw ) / 2;
        my $colour_1 = $glyphset->my_config('colour') ||
                     ( $feature_type_1 ? $glyphset->my_colour( $feature_type_1, 'label' ) : undef );
        my $colour_2 = $glyphset->my_config('colour_2') ||
                     ( $feature_type_2 ? $glyphset->my_colour( $feature_type_2, 'label' ) : undef );
        $glyphset->push($glyphset->Text({
          'x'      => $label_x / $scalex,
	        'y'      => ($glyphset->maxy() + $glyphset->miny() - length($label_1)*$gw ) / 2,
	        'height' => $gw * length($label_1),
	        'font'   => 'Small',
	        'text'   => $label_1,
          'absolutey' => 1,
	        'colour' => $colour_1
        })) if $label_1;
        $glyphset->push($glyphset->Text({
          'x'      => ( $label_x + 2 + $Config->texthelper->height('Tiny') )/ $scalex,
	        'y'      => ($glyphset->maxy() + $glyphset->miny() - length($label_2)*$gw ) / 2,
	        'height' => $gw * length($label_2),
	        'font'   => 'Small',
	        'text'   => $label_2,
          'absolutey' => 1,
	        'colour' => $colour_2
        })) if $label_2;
      }
      ########## remove any whitespace at the top of this row
      $Config->{'transform'}->{'translatey'} = -$glyphset->miny() + $spacing/2 + $yoffset;
      $glyphset->transform();
      ########## translate the top of the next row to the bottom of this one
      $yoffset += $glyphset->height() + $spacing;
      $Config->set_parameter('max_height',  $yoffset + $spacing ) if( $yoffset + $spacing > $Config->get_parameter('max_height') );
    }
    $self->{'glyphsets'} = \@glyphsets;
    ########## Store the maximum "width of the image"
  }
  $self->timer_push("DrawableContainer->new: End GlyphSets");
  return $self;
}

########## render does clever drawing things
sub render {
  my ($self, $type) = @_;
  
  ########## build the name/type of render object we want
  my $renderer_type = qq(Bio::EnsEMBL::VRenderer::$type);
  ########## dynamic require of the right type of renderer

  return unless $self->dynamic_use( $renderer_type );

  ########## big, shiny, rendering 'GO' button
  my $renderer = $renderer_type->new(
    $self->{'config'},
    $self->{'vc'},
    $self->{'glyphsets'}
  );
  return $renderer->canvas();
}

sub config {
  my ($self, $Config) = @_;
  $self->{'config'} = $Config if(defined $Config);
  return $self->{'config'};
}

sub glyphsets {
  my ($self) = @_;
  return @{$self->{'glyphsets'}};
}

sub dynamic_use {
  my( $self, $classname ) = @_;
  my( $parent_namespace, $module ) = $classname =~/^(.*::)(.*?)$/;
  no strict 'refs';
  return 1 if $parent_namespace->{$module.'::'}; # return if already used
  eval "require $classname";
  if($@) {
    warn "VVDrawableContainer: failed to use $classname\nVVDrawableContainer: $@";
    return 0;
  }
  $classname->import();
  return 1;
}

1;

=head1 RELATED MODULES

See also: Bio::EnsEMBL::GlyphSet Bio::EnsEMBL::Glyph

=head1 AUTHOR - Roger Pettett

Email - rmp@sanger.ac.uk

=cut
