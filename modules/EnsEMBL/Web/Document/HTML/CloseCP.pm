package EnsEMBL::Web::Document::HTML::CloseCP;

### Generates link to 'close' control panel (currently in Popup masthead)

use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new(); }

sub referer   :lvalue { $_[0]{'referer'};   }
## Needed to avoid problems in Document::Common
sub logins    :lvalue { $_[0]{'logins'};   }
sub blast     :lvalue { $_[0]{'blast'};   }
sub biomart   :lvalue { $_[0]{'biomart'};   }

sub render   {
  my $self = shift;
  $self->print('<a id="cp_close" href="'.$self->referer.'">Close</a>');
}

1;

