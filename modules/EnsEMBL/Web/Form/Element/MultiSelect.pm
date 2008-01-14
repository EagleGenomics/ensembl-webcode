package EnsEMBL::Web::Form::Element::MultiSelect;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  my %params = @_;

  my $self = $class->SUPER::new( %params, 'render_as' => $params{'select'} ? 'select' : 'radiobutton', 'values' => $params{'values'} );
  $self->{'class'} = $params{'class'} || 'radiocheck';

  return $self;
}

sub validate { return $_[0]->render_as eq 'select'; }

sub render {
  my $self =shift;

  #cluck "This is how we got here!";

  if( $self->render_as eq 'select' ) {
    my $options = '';
    foreach my $V( @{$self->values} ) {
      $options .= sprintf( "<option value=\"%s\"%s>%s</option>\n",
			   $V->{'value'}, $V->{'checked'} eq 'yes' ? ' selected="selected"' : '', $V->{'name'}
      );
    }
    return sprintf( qq(%s<select multiple="multiple" name="%s" id="%s" class="normal" onChange="os_check('%s',this,%s)">%s</select>%s),
      $self->introduction,
      CGI::escapeHTML( $self->name ), CGI::escapeHTML( $self->id ),
      $self->type, $self->required eq 'yes'?1:0,
      $options,
      $self->notes
    );
  } else {
    my $output = '';
    my $K = 0;
    my $checked;

    foreach my $V ( @{$self->values} ) {
        $checked = 'no';
        # check if we want to tick this box
        foreach my $M ( @{$self->value||[]} ) {
            if ($M eq $$V{'value'}) {
                $checked = 'yes';
                last;
            }
        }
        if ($V->{'checked'}) {
            $checked = 'yes';
        }
        $output .= sprintf( "    <div class=\"%s\"><input id=\"%s_%d\" class=\"radio\" type=\"checkbox\" name=\"%s\" value=\"%s\" %s/><label for=\"%s_%d\">%s</label></div>\n",
            $self->{'class'},
            CGI::escapeHTML($self->id), $K, 
	          CGI::escapeHTML($self->name), 
	          CGI::escapeHTML($V->{'value'}),
            $checked eq 'yes' ? ' checked="checked"' : '', 
            CGI::escapeHTML($self->id), $K, 
            $self->{'noescape'} ? $V->{'name'} : CGI::escapeHTML($V->{'name'})
        );
        $K++;
    }

# To deal with the case when all checkboxes get unselected we intoduce a dummy 
# hidden field that will force CGI to pass the parameter to our script
    $output .= sprintf( "    <input id=\"%s_%d\" type=\"hidden\" name=\"%s\" value=\"\" />\n",
            CGI::escapeHTML($self->id), 
	    $K, 
	    CGI::escapeHTML($self->name), 
			);

    return $self->introduction.$output.$self->notes;
  }
}

1;
