package Bio::EnsEMBL::GlyphSet::generic_gene;

use strict;
use Bio::EnsEMBL::GlyphSet_gene;
@Bio::EnsEMBL::GlyphSet::generic_gene::ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub my_label { my $self = shift; warn $self->my_config('track_label'); 
 return $self->my_config('track_label'); }

sub ens_ID {
  my( $self, $g ) = @_;
  my $X = $self->my_config('ens_ID');
  if( ref($X) eq 'CODE' ) {
    return &$X( $g );
  } elsif( $X ) {
    return $X;
  } else {
    return $g->stable_id;
  }
}

sub gene_label {
  my( $self, $g ) = @_;
  my $X = $self->my_config('gene_label');
  if( ref($X) eq 'CODE' ) {
    return &$X( $g );
  } elsif( $X ) {
    return $X;
  } else {
    return $g->stable_id;
  }
}

sub gene_col {
  my( $self, $g ) = @_;
  my $X = $self->my_config('gene_col');
  if( ref($X) eq 'CODE' ) {
    return &$X( $g );
  } elsif( $X ) {
    return $X;
  } else {
    return $g->type;
  }
}

1;
