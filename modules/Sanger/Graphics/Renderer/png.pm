#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::Renderer::png;
use strict;
use Sanger::Graphics::Renderer::gif;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::Renderer::gif);

sub init_canvas {
  my ($self, $config, $im_width, $im_height) = @_;
  $self->{'im_width'}  = $im_width;
  $self->{'im_height'} = $im_height;
  my $canvas = GD::Image->newTrueColor($im_width, $im_height);
  $self->canvas($canvas);
  my $bgcolor = $self->colour($config->bgcolor);
  $self->{'canvas'}->filledRectangle(0,0, $im_width, $im_height, $bgcolor );
}

sub canvas {
    my ($self, $canvas) = @_;
    if(defined $canvas) {
	$self->{'canvas'} = $canvas;
    } else {
	return $self->{'canvas'}->png();
    }
}

sub render_Sprite {
  my ($self, $glyph) = @_;
  my $spritename     = $glyph->{'sprite'} || "unknown";
  my $config         = $self->config();

  unless(exists $config->{'_spritecache'}->{$spritename}) {
    my $libref = $config->get("_settings", "spritelib");
    my $lib    = $libref->{$glyph->{'spritelib'} || "default"};
    my $fn     = "$lib/$spritename.png";
    unless( -r $fn ){ 
      warn( "$fn is unreadable by uid/gid" );
      return;
    }
    eval {
      $config->{'_spritecache'}->{$spritename} = GD::Image->newFromPng($fn);
    };
    if( $@ || !$config->{'_spritecache'}->{$spritename} ) {
      eval {
        $config->{'_spritecache'}->{$spritename} = GD::Image->newFromPng("$lib/missing.png");
      };
    }
  }

  return $self->SUPER::render_Sprite($glyph);
}

1;
