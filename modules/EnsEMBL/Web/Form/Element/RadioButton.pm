package EnsEMBL::Web::Form::Element::RadioButton;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_ );
}
                                                                                
sub new {
  my $class = shift;
  my %params = @_;
  my $self = $class->SUPER::new(
    %params,
  );
  $self->checked = $params{'checked'};
  return $self;
}
sub checked  :lvalue { $_[0]->{'checked'};  }

sub render {
  my $self = shift;
  return sprintf(
    qq(<input type="radio" name="%s" id="%s" value="%s" %s/> %s),
    CGI::escapeHTML( $self->name ), CGI::escapeHTML( $self->id ),
    $self->value || 'yes', $self->checked ? 'checked="checked" ' : '', $self->notes
  );
}
                                                                                
sub validate { return 1; }


1;
