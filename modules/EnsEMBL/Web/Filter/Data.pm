package EnsEMBL::Web::Filter::Data;

use strict;
use warnings;
use Class::Std;

use base qw(EnsEMBL::Web::Filter);

### Checks if an uploaded file or other input is non-zero and usable

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Set the messages hash here
  $self->set_messages({
    'no_url'  => 'No URL was entered. Please try again.',
    'no_response' => 'We were unable to access your data file. Please check the file path and try again. If you continue to get this message, your file may be too large for us to upload.',
    'empty'   => 'Your file appears to be empty. Please check that it contains correctly-formatted data.',
    'too_big' => 'Your file is too big to parse. Please select a smaller file.',
    'no_save' => 'Your data could not be saved. Please check the file contents and try again.',
  });
}

sub catch {
  my $self = shift;
}

}

1;
