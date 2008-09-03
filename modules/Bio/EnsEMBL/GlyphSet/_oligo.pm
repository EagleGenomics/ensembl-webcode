package Bio::EnsEMBL::GlyphSet::_oligo;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::_alignment);

sub features { ## Hack in db in the future!!
  my ($self) = @_;
  my $T = $self->{'container'}->get_all_OligoFeatures( $self->my_config('array') );
  return $T;
}

sub feature_group {
  my( $self, $f ) = @_;
  return $f->probeset;    ## For core features this is what the sequence name is...
}

sub feature_title {
  my( $self, $f ) = @_;
  return "Probe set: ".$f->probeset;
}

sub href {
### Links to /Location/Feature with type of 'OligoProbe'
  my ($self, $f ) = @_;
  return $self->_url({
    'object' => 'Location',
    'action' => 'Feature',
    'fdb'    => $self->my_config('db'),
    'ftype'  => 'OligoProbe',
    'fname'  => $f->probeset
  });
}

sub feature_group{
  my( $self, $f ) = @_;
  return $f->probeset();
}

1;
