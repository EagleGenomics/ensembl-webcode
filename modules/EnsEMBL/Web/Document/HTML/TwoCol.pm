package EnsEMBL::Web::Document::HTML::TwoCol;

use strict;
use CGI qw(escapeHTML);

sub new {
  my $class = shift;
  my $self = { 'content' => [] };
  bless $self, $class;
  return $self;
}

sub _row {
  my($self, $label, $value ) = @_;
  return sprintf '<dl class="summary">
    <dt>%s</dt>
    <dd>%s</dd>
  </dl>', escapeHTML($label), $value;
}

sub add_row {
  my($self, $label, $value, $raw ) = @_;
  $value = sprintf( '<p>%s</p>', escapeHTML($value) ) unless $raw;
  push @{$self->{'content'}}, $self->_row( $label, $value );
}

sub render {
  my $self = shift;
  return join '',@{$self->{'content'}};
}

1;
