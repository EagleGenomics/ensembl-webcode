package EnsEMBL::Web::Document::Renderer::String;

use strict;
use EnsEMBL::Web::Document::Renderer::Table::Text;
use Apache2::RequestUtil;

use base 'EnsEMBL::Web::Document::Renderer';

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(string => '', @_);
  return $self;
}

sub new_table_renderer {
### Create a new table renderer.
  my $self = shift;
  return EnsEMBL::Web::Document::Renderer::Table::Text->new( { 'renderer' => $self } );
}

sub printf  { shift->{'string'} .= sprintf(shift, @_);  }
sub print   { shift->{'string'} .= join('', @_); }
sub content { return $_[0]{'string'} }

1;