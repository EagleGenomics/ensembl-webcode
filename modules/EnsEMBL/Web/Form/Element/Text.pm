package EnsEMBL::Web::Form::Element::Text;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_ );
}

sub render {
  my $self = shift;
  my $style;
  if ( CGI::escapeHTML( $self->rows ) ) {
    my $height = CGI::escapeHTML( $self->rows ) * 1.2;
    $style = 'style="height:'.$height.'em"';
  }
  return sprintf(
    qq(<textarea name="%s" id="%s" rows="%s" cols="%s" onKeyUp="check('text',this,%d)" onChange="check( 'text', this, %d )" %s>%s</textarea>),
    CGI::escapeHTML( $self->name ), CGI::escapeHTML( $self->id ),
    CGI::escapeHTML( $self->rows ) ? CGI::escapeHTML( $self->rows ) : '10', 
    CGI::escapeHTML( $self->cols ) ? 'style="'.CGI::escapeHTML( $self->rows ) * 1.2 : '',
    $self->required eq 'yes' ? 1 : 0,
    $self->required eq 'yes' ? 1 : 0,
    $style,
    CGI::escapeHTML( $self->value )
  );
}

sub validate { return 1; }

1;
