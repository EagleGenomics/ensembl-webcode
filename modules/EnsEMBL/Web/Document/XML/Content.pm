package EnsEMBL::Web::Document::XML::Content;
use strict;

use EnsEMBL::Web::Document::XML;

our @ISA = qw(EnsEMBL::Web::Document::XML);

sub new { return shift->SUPER::new( 'panels' => [], 'first' => 1, 'form' => '' ); }

sub add_panel {
  $_[1]->renderer = $_[0]->renderer; push @{$_[0]{'panels'}}, $_[1];
}

sub panel {
  my( $self, $code ) = @_;
  foreach( @{$self->{'panels'}} ) {
    return $_ if $code eq $_->{'code'};
  }
  return undef;
}

sub first :lvalue { $_[0]->{'first'}; }
sub form  :lvalue { $_[0]->{'form'}; }
sub render {
  my $self = shift;
  foreach my $panel ( @{$self->{'panels'}} ) {
    $panel->{_renderer} = $self->renderer;
    $panel->render_XML( 0 );
  }
}

1;
