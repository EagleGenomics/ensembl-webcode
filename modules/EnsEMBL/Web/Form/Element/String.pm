package EnsEMBL::Web::Form::Element::String;

use strict;
use base qw( EnsEMBL::Web::Form::Element );

use CGI qw(escapeHTML);

sub _is_valid { return 1; }

sub _class { return '_string'; }

sub validate { return 1; }


sub render {
  my $self = shift;
  return sprintf( '
  <tr>
    <th><label for="%s">%s: </label></th>
    <td><input type="%s" name="%s" value="%s" id="%s" class="input-text %s %s" size="%s" />
    %s
    %s
    </td>
  </tr>',
    CGI::escapeHTML( $self->name ),
    CGI::escapeHTML( $self->label ),
    $self->widget_type,
    CGI::escapeHTML( $self->name ),
    CGI::escapeHTML( $self->value ), CGI::escapeHTML( $self->id ),
    $self->_class,
    $self->required eq 'yes' ? 'required' : 'optional',
    $self->size || 20,
    $self->required eq 'yes' ? $self->required_string : '',
    $self->notes ? "<br />".$self->notes : '',
  );
}


1;
