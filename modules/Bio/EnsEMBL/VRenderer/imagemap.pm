package Bio::EnsEMBL::VRenderer::imagemap;
use strict;
use Bio::EnsEMBL::VRenderer;
use Sanger::Graphics::JSTools;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::VRenderer);

#########
# imagemaps are basically strings, so initialise the canvas with ""
# imagemaps also aren't too fussed about width & height boundaries
#
sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;
  $self->canvas("");
  $self->{'show_zmenus'} = defined( $config->get("_settings","opt_zmenus") ) ? $config->get("_settings","opt_zmenus") : 1;
  $self->{'zmenu_zclick'} = $config->get("_settings","opt_zclick");
  $self->{'zmenu_behaviour'} = $config->get("_settings","zmenu_behaviour") || 'onmouseover';
}

sub add_canvas_frame {
    my ($self, $config, $im_width, $im_height) = @_;
	return(); # no-op!	
}

sub render_Rect {
  my ($self, $glyph) = @_;
  my $href = $self->_getHref( $glyph );
  return unless defined $href;
  return if $href eq '';
  my $x1 = int( $glyph->pixelx() );
  my $x2 = int( $x1 + $glyph->pixelwidth() );
  my $y1 = int( $glyph->pixely() );
  my $y2 = int( $y1 + $glyph->pixelheight() );

  $x1 = 0 if($x1<0);
  $x2 = 0 if($x2<0);
  $y1 = 0 if($y1<0);
  $y2 = 0 if($y2<0);
  $y2 ++;
  $x2 ++;
  $self->{'canvas'} = qq(<area shape="rect" coords="$y1 $x1 $y2 $x2"$href />\n).$self->{'canvas'}; 
}

sub render_Text {
    my ($self, $glyph) = @_;
	$self->render_Rect($glyph);
}

sub render_Circle { }

sub render_Ellipse { }

sub render_Intron { }

sub render_Poly {
  my ($self, $glyph) = @_;
  my $href = $self->_getHref( $glyph );
  return unless(defined $href);
  return if $href eq '';
  my $pointslist = join ' ',map { int } reverse @{$glyph->pixelpoints()};
  $self->{'canvas'} = qq(<area shape="poly" coords="$pointslist"$href />\n).$self->{'canvas'} ; 
}

sub render_Composite {
    my ($self, $glyph) = @_;
    $self->render_Rect($glyph);
	return;
}

sub render_Line { }

sub render_Space {
    my ($self, $glyph) = @_;
    $self->render_Rect($glyph);
	return;
}

sub _getHref {
  my( $self, $glyph ) = @_;
  my %actions = ();
  my @X = qw( title onmouseover onmouseout alt href );
  foreach(@X) {
    my $X = $glyph->$_;
    $actions{$_} = $X if defined $X;
  }
  $actions{'title'} = $glyph->alt if defined $glyph->alt;

  if($self->{'show_zmenus'}==1) {
    my $zmenu = $glyph->zmenu();
    if(defined $zmenu && (ref($zmenu) eq '' || ref($zmenu) eq 'HASH' && keys(%$zmenu)>0) ) {
      if($self->{'zmenu_zclick'} || ($self->{'zmenu_behaviour'} =~ /onClick/i)) {
        #$actions{'ondoubleclick'} = $actions{'href'}        if exists $actions{'href'};
        $actions{'onclick'}       = &Sanger::Graphics::JSTools::js_menu($zmenu).";return false;";
        delete $actions{'onmouseover'};
        delete $actions{'onmouseout'};
        $actions{'alt'} = "Click for Menu";
      } else {
        delete $actions{'alt'};
        $actions{'onmouseover'} = &Sanger::Graphics::JSTools::js_menu($zmenu);
      }
      $actions{'href'} ||= 'javascript:void(0)';
    }
  }
  return join '', map { qq( $_="$actions{$_}") } keys %actions;
}

1;
