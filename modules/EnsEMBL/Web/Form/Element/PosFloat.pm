package EnsEMBL::Web::Form::Element::PosFloat;

use EnsEMBL::Web::Form::Element::String;
our @ISA = qw( EnsEMBL::Web::Form::Element::String );

sub new { my $class = shift; return $class->SUPER::new( @_, 'style' => 'short' ); }

sub _is_valid { return $_[0]->value =~ /^([+]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/; }

1;
