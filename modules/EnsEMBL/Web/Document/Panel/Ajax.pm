package EnsEMBL::Web::Document::Panel::Ajax;

use strict;
use Data::Dumper qw(Dumper);

use base qw(EnsEMBL::Web::Document::Panel);

sub _start {
  my $self = shift;
}

sub _end   { 
  my $self = shift;
}

sub add_row {
  my $self = shift;

}
sub render {
  my( $self, $first ) = @_;
  my $content = '';
  if( $self->{'delayed_write'} ) {
    $content = $self->_content_delayed();
  }

  if( $self->{'_delayed_write_'} ) {
    $self->renderer->print($content);
  } else {
    $self->content();
  }
}

sub _error {
  my( $self, $caption, $body ) = @_;
  $self->printf( '
<h1>AJAX error - %s</h1>%s',
    $caption, $body
  );
}

1;
