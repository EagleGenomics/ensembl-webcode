# $Id$

package EnsEMBL::Web::Document::HTML::CloseCP;

### Generates link to 'close' control panel (currently in Popup masthead)

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new(); }

sub referer     :lvalue { $_[0]{'referer'}; }
## Needed to avoid problems in Document::Common
sub logins      :lvalue { $_[0]{'logins'}; }
sub blast       :lvalue { $_[0]{'blast'}; }
sub biomart     :lvalue { $_[0]{'biomart'}; }
sub mirror_icon :lvalue { $_[0]{'mirror_icon'}; }

sub render   {
  my $self = shift;
  $self->print('<a class="popup_close" href="'.encode_entities($self->referer).'">Close</a>');
}

1;

