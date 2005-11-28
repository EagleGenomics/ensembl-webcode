package EnsEMBL::Web::File::Image;

use strict;
use Digest::MD5 qw(md5_hex);
use Image::Size;

our $TMP_IMG_FORMAT     = 'XXX/X/X/XXXXXXXXXXXXXXX';
our $DEFAULT_FORMAT = 'png';

use EnsEMBL::Web::Root;

our @ISA =qw(EnsEMBL::Web::Root);

#  ->cache   = G/S 0/1
#  ->ticket  = G/S ticketname (o/w uses random date stamp)
#  ->dc      = G/S E::W::DC
#  ->render(format) 
#  ->imagemap = [ Note a cached image will store this when called & DC exists ]

sub new {
  my $class = shift;
  my $self = {
    'cache'     => 0,
    'species_defs' => shift,
    'token'     => '',
    'filename'  => '',
    'file_root' => '',
    'URL_root'  => '',
    'dc'        => undef
  };
  bless $self, $class;
  return $self;
}

sub dc :lvalue { $_[0]->{'dc'}; }

sub set_cache_filename {
  my $self     = shift;
  my $filename = shift;
  $self->{'cache'}      = 1;
  my $MD5 = hex(substr( md5_hex($filename), 0, 6 )); ## Just the first 6 characters will do!
  my $c1  = $EnsEMBL::Web::Root::random_ticket_chars[($MD5>>5)&31];
  my $c2  = $EnsEMBL::Web::Root::random_ticket_chars[$MD5&31];
  
  $self->{'token'}      = "$c1$c2$filename";
  $self->{'filename'}   = "$c1/$c2/$filename";

  $self->{'file_root' } = $self->{'species_defs'}->ENSEMBL_TMP_DIR_CACHE;
  $self->{'URL_root'}   = $self->{'species_defs'}->ENSEMBL_TMP_URL_CACHE;
}

sub set_tmp_filename {
  my $self     = shift;
  my $filename = shift || $self->{'token'} || $self->ticket;
  $self->{'cache'}      = 0;
  $self->{'token'}      = $filename;
  $self->{'filename'}   = $self->templatize( $filename, $TMP_IMG_FORMAT ); 
  $self->{'file_root' } = $self->{'species_defs'}->ENSEMBL_TMP_DIR_IMG;
  $self->{'URL_root'}   = $self->{'species_defs'}->ENSEMBL_TMP_URL_IMG;
}

sub extraHTML {
  my $self = shift;
  my $extra = '';
  if( $self->{'img_map'} ) {
    $extra .= qq(usemap="#$self->{'token'}" );
  }
  return $extra;
}

sub filename { 
  my $self = shift;
  my $extn = shift;
  $extn .= '.gz'  if $extn eq 'imagemap';
  $extn .= '.eps' if $extn eq 'postscript';
  return $self->{'file_root'}.'/'.$self->{'filename'}.".$extn";
}

sub URL { 
  my $self = shift;
  my $extn = shift;
  return $self->{'URL_root'}.'/'.$self->{'filename'}.".$extn";
}
sub extraStyle {
  my $self = shift;
  my $extra = '';
  if( $self->{'border'} ) {
    $extra .= sprintf qq(border: %s %dpx %s;),
              $self->{'border_colour'} || '#000', $self->{'border'},
              $self->{'border_style'}||'solid'; 
  }
  return $extra;
}

sub render_image_tag {
  my $self = shift;
  my $IF = $self->render( @_ );
  my($width, $height ) = imgsize( $IF->{'file'} );
  my $HTML = sprintf '<img src="%s" alt="%s" title="%s" style="width: %dpx; height: %dpx; %s" %s />',
                       $IF->{'URL'}, $self->{'text'}, $self->{'text'},
                       $width, $height,
                       $self->extraStyle,
                       $self->extraHTML;
  $self->{'width'}  = $width;
  $self->{'height'} = $height;
  return $HTML;
} 

sub render_image_button {
  my $self = shift;
  my $IF = $self->render( @_ );
  my($width, $height ) = imgsize( $IF->{'file'} );
  $self->{'width'}  = $width;
  $self->{'height'} = $height;
  my $HTML = sprintf '<input style="width: %dpx; height: %dpx;" type="image" name="%s" id="%s" src="%s" alt="%s" title="%s" />', $width, $height, $self->{'name'}, $self->{'id'}||$self->{'name'}, $IF->{'URL'}, $self->{'text'}, $self->{'text'};
  return $HTML;
} 

sub render_image_link {
  my $self   = shift;
  my $format = shift;
  my $IF     = $self->render( lc($format) );
  my $HTML   = sprintf '<a target="_blank" href="%s">Render as %s</a>', $IF->{'URL'}, uc($format);
  return $HTML;
}

sub render_image_map {
  my $self = shift;
  my $IF   = $self->render( 'imagemap' );
  my $HTML = sprintf( qq(<map name="%s" id="%s">\n%s</map>), $self->{'token'}, $self->{'token'}, $IF->{'imagemap'} );
  return $HTML
}

sub exists { 
  my( $self, $format ) = @_;
  $format ||= $DEFAULT_FORMAT;
  my $file = $self->filename( $format );
  return $self->{'cache'} && -e $file && -f $file;
}
 
use Compress::Zlib;

sub render {
  my( $self, $format ) = @_;
  $format ||= $DEFAULT_FORMAT;
  my $file = $self->filename( $format );
  if( $self->{'cache'} && -e $file && -f $file ) {
warn ">>>> CACHE HIT $file";
      ## If cached image required and it exists return it!
    if( $format eq 'imagemap' ) {
      my $gz = gzopen( $file, 'rb' );
      my $imagemap = '';
      my $buffer = 0;
      $imagemap .= $buffer while $gz->gzread( $buffer ) > 0;
      $gz->gzclose;
      return { 'imagemap' => $imagemap };
    } else {
      return { 'URL' => $self->URL($format), 'file' => $file };
    }
  }
  my $image;
  eval { $image    = $self->dc->render($format); };
  if( $image ) {
    if( $format eq 'imagemap' ) {
      if( $self->{'cache'} ) { ## Now we write the image...
        $self->make_directory( $file );
        my $gz = gzopen( $file, 'wb' );
        $gz->gzwrite( $image );
        $gz->gzclose();
      }
      return { 'imagemap' => $image };
    } else { 
      $self->make_directory( $file );
      open(IMG_OUT, ">$file") || warn qq(Cannot open temporary image file for $format image: $!);
      binmode IMG_OUT;
      print IMG_OUT $image;
      close(IMG_OUT);
      return { 'URL' => $self->URL($format), 'file' => $file };
    }
  } else {
    warn $@;
    return {};
  }
}

                                                                                

1; 
