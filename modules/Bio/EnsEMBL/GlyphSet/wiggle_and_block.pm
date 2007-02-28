package Bio::EnsEMBL::GlyphSet::wiggle_and_block;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Rect;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Data::Dumper;

sub init_label {

  ### Returns (string) the label for the track

  my $self = shift;
  my $HELP_LINK = $self->check();
  $self->init_label_text( $self->my_config('label'), $HELP_LINK );
  $self->bumped( $self->{'config'}->get($HELP_LINK, 'compact') ? 'no' : 'yes' );
  return;
}

sub _init {
  my ($self) = @_;
  my $slice = $self->{'container'};
  my $max_length    = $self->{'config'}->get( $self->check(), 'threshold' )  || 500;
  my $slice_length  = $slice->length;
  my $wiggle_name   =  $self->my_config('wiggle_name');
  if($slice_length > $max_length*1010) {
    my $height = $self->errorTrack("$wiggle_name only displayed for less than $max_length Kb");
    $self->_offset($height+4);
    return;
  }

  my $db = undef;
  my $db_type = $self->my_config('db_type')||'compara';
  unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $db = $slice->adaptor->db->get_db_adaptor($db_type);
    if(!$db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }


  my %drawn_flag;
  my @flags;

  if ( $self->my_config('compact') ) {
    $drawn_flag{ 'wiggle' } = 1;
    @flags =  $self->draw_features( $db );
  }

  # If no blocks are drawn or on expand mode: draw wiggles
  if ( $flags[0] ne 'block_features' or ! $self->my_config('compact') ) {
    @flags =  $self->draw_features( $db, "wiggle" );
  }

  map { $drawn_flag{$_} = 1 } @flags;
  return if $drawn_flag{'wiggle'} && $drawn_flag{'block_features'};

  # Error messages ---------------------
  my $block_name =  $self->my_config('block_name');
  # If both wiggle and predicted features tracks aren't drawn in expanded mode..
  my $error;
  if (!$drawn_flag{'block_features'}  && !$drawn_flag{'wiggle'}) {
    $error = "$block_name or $wiggle_name";
  }
  elsif (!$drawn_flag{'block_features'}) {
    $error = $block_name;
  }
  elsif (!$drawn_flag{'wiggle'}) {
    $error = $wiggle_name;
  }

  my $height = $self->errorTrack( "No $error in this region", 0, $self->_offset ) if $self->{'config'}->get('_settings','opt_empty_tracks')==1;
  $self->_offset($height + 4);
  return 1;
}


sub render_block_features {

  ### Predicted features
  ### Draws the predicted features track
  ### Arg1: arrayref of Feature objects
  ### Arg2: colour of the track

  my ( $self, $features, $colour, $score ) = @_;
  my $length = $self->{'container'}->length;

  foreach my $f (@$features ) {
    my $start = $f->start;
    my $end   = $f->end;
    $start = 1 if $start < 1;
    $end   = $length if $end > $length;
    my $Glyph = new Sanger::Graphics::Glyph::Rect({
      'y'         => $self->_offset,
      'height'    => 10,
      'x'         => $start -1,
      'width'     => $end - $start,
      'absolutey' => 1,          # in pix rather than bp
      'colour'    => $colour,
      'zmenu'     => $self->block_features_zmenu($f, $score),
    });
    $self->push( $Glyph );
  }
  $self->_offset(13);
  return 1;
}


sub render_wiggle_plot {

  ### Wiggle plot
  ### Args: array_ref of features in score order, colour, min score for features, max_score for features, display label
  ### Description: draws wiggle plot using the score of the features
  ### Returns 1

  my( $self, $features, $colour, $min_score, $max_score, $display_label ) = @_;
  my $slice = $self->{'container'};
  my $row_height = 60;
  my $offset     = $self->_offset();
  my $P_MAX = $max_score > 0 ? $max_score : 0;
  my $N_MIN = $min_score < 0 ? $min_score : 0;
  my $pix_per_score   = ($P_MAX-$N_MIN) ? $row_height / ( $P_MAX-$N_MIN ) : 0;
  my $red_line_offset = $P_MAX * $pix_per_score;
  my $axis_colour = $self->my_config('axis_colour')|| 'red';

  # Draw the axis ------------------------------------------------
  $self->push( new Sanger::Graphics::Glyph::Line({ # horzi line
    'x'         => 0,
    'y'         => $offset + $red_line_offset,
    'width'     => $slice->length,
    'height'    => 0,
    'absolutey' => 1,
    'colour'    => $axis_colour,
    'dotted'    => 1,
						   }));

  $self->push( new Sanger::Graphics::Glyph::Line({ # vertical line
    'x'         => 0,
    'y'         => $offset,
    'width'     => 0,
    'height'    => $row_height,
    'absolutey' => 1,
    'absolutex' => 1,
    'colour'    => $axis_colour,
    'dotted'    => 1,
						   }));


  # Draw max and min score ---------------------------------------------
  my $display_max_score = sprintf("%.2f", $P_MAX); 
  my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
  my @res_i = $self->get_text_width( 0, $display_max_score, '', 
				       'font'=>$fontname_i, 
				       'ptsize' => $fontsize_i );
  my $textheight_i = $res_i[3];
  my $pix_per_bp = $self->{'config'}->transform->{'scalex'};

  $self->push( new Sanger::Graphics::Glyph::Text({
    'text'          => $display_max_score,
    'width'         => $res_i[2],
    'textwidth'     => $res_i[2],
    'font'          => $fontname_i,
    'ptsize'        => $fontsize_i,
    'halign'        => 'right',
    'valign'        => 'top',
    'colour'        => $axis_colour,
    'height'        => $textheight_i,
    'y'             => $offset,
    'x'             => -4 - $res_i[2],
    'absolutey'     => 1,
    'absolutex'     => 1,
    'absolutewidth' => 1,
    }) );

  if ($min_score < 0) {
    my $display_min_score = sprintf("%.2f", $N_MIN); 
    my @res_min = $self->get_text_width( 0, $display_min_score, '', 
					   'font'=>$fontname_i, 
					   'ptsize' => $fontsize_i );

    $self->push(new Sanger::Graphics::Glyph::Text({
      'text'          => $display_min_score,
      'height'        => $textheight_i,
      'width'         => $res_min[2],
      'textwidth'     => $res_min[2],
      'font'          => $fontname_i,
      'ptsize'        => $fontsize_i,
      'halign'        => 'right',
      'valign'        => 'bottom',
      'colour'        => $axis_colour,
      'y'             => $offset + $row_height - $textheight_i,
      'x'             => -4 - $res_min[2],
      'absolutey'     => 1,
      'absolutex'     => 1,
      'absolutewidth' => 1,
						    }));
  }


  # Draw wiggly plot -------------------------------------------------
  foreach my $f (@$features) {
    my $START = $f->start < 1 ? 1 : $f->start;
    my $END   = $f->end   > $slice->length  ? $slice->length : $f->end;
    my $score = $f->score || 0;
    # warn(join('*', $f, $START, $END, $score));
    my $y = $score < 0 ? 0 : -$score * $pix_per_score;

    my $Glyph = new Sanger::Graphics::Glyph::Rect({
      'y'         => $offset + $red_line_offset + $y,
      'height'    => abs( $score * $pix_per_score ),
      'x'         => $START-1,
      'width'     => $END - $START,
      'absolutey' => 1,
      'title'     => sprintf("%.2f", $score),
      'colour'    => $colour,
						    });
    $self->push( $Glyph );
  }

  $offset = $self->_offset($row_height);


  # Add line of text -------------------------------------------
  my @res_analysis = $self->get_text_width( 0,  $display_label,
					      '', 'font'=>$fontname_i, 
					      'ptsize' => $fontsize_i );

  $self->push( new Sanger::Graphics::Glyph::Text({
    'text'      => $display_label,
    'width'     => $res_analysis[2],
    'font'      => $fontname_i,
    'ptsize'    => $fontsize_i,
    'halign'    => 'left',
    'valign'    => 'bottom',
    'colour'    => $colour,
    'y'         => $offset,
    'height'    => $textheight_i,
    'x'         => 1,
    'absolutey' => 1,
    'absolutex' => 1,
						 }) ); 
  $self->_offset($textheight_i);  #update offset
  $self->render_space_glyph(5);
  return 1;
}


sub render_track_name {

  ### Predicted features
  ### Draws the name of the predicted features track
  ### Arg1: arrayref of Feature objects
  ### Arg2: colour of the track

  my ( $self, $name, $colour ) = @_;
  my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
  my @res_analysis = $self->get_text_width( 0, $name,
                        '', 'font'=>$fontname_i, 
                        'ptsize' => $fontsize_i );

  $self->push( new Sanger::Graphics::Glyph::Text({
    'text'      => $name,
    'height'    => $res_analysis[3],
    'width'     => $res_analysis[2],
    'font'      => $fontname_i,
    'ptsize'    => $fontsize_i,
    'halign'    => 'left',
    'valign'    => 'bottom',
    'colour'    => $colour,
    'y'         => $self->_offset,
    'x'         => 1,
    'absolutey' => 1,
    'absolutex' => 1,
    }) );

  $self->_offset($res_analysis[3]);
  return 1;
}


sub render_space_glyph {

  ### Draws a an empty glyph as a spacer
  ### Arg1 : (optional) integer for space height,

  my ($self, $space) = @_;
  $space ||= 9;

  $self->push( new Sanger::Graphics::Glyph::Space({
    'height'    => $space,
    'width'     => 1,
    'y'         => $self->_offset,
    'x'         => 0,
    'absolutey' => 1,  # puts in pix rather than bp
    'absolutex' => 1,
          }));
  $self->_offset($space);
  return 1;
}


sub _offset {

  ### Arg1 : (optional) number to add to offset
  ### Description: Getter/setter for offset
  ### Returns : integer

  my ($self, $offset) = @_;
  $self->{'offset'} += $offset if $offset;
  return $self->{'offset'} || 0;
}


1;
### Contact: Fiona Cunningham fc1@sanger.ac.uk
