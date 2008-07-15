package EnsEMBL::Web::Document::HTML::CloseCP;

### Generates link to 'close' control panel (currently in Popup masthead)

use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new(); }

sub referer   :lvalue { $_[0]{'referer'};   }
sub logins    :lvalue { $_[0]{'logins'};   } ## Needed to avoid problems in Document::Common

sub render   {
  my $self = shift;
  warn "GO TO: ".$self->referer;
  $self->print('<a href="'.$self->referer.'">Exit Control Panel</a>');
}

1;

