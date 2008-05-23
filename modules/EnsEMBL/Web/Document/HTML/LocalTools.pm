package EnsEMBL::Web::Document::HTML::LocalTools;

### Generates the local context tools - configuration, data export, etc.

use strict;
use base qw(EnsEMBL::Web::Document::HTML);
use Data::Dumper;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( );
  return $self;
}

sub add_entry {
### a
  my $self = shift;
  push @{$self->{'_entries'}}, {@_};
}

sub entries {
### a
  my $self = shift;
  return $self->{'_entries'}||[];
}

sub render {
  my $self = shift;
  $self->print( q(<div id="local-tools">
      <ul>) );

  foreach my $link ( @{$self->entries} ) {
    $self->print('<li><a href="'.$link->{'url'}.'"');
    if ($link->{'type'} eq 'external') {
      $self->print(' class="external" rel="external"');
    }
    $self->print('>'.$link->{'caption'}.'</a></li>');
  }

  $self->print( q(
      </ul>
      </div>) );
}

return 1;
