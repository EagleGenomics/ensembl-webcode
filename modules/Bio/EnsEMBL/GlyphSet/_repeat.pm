package Bio::EnsEMBL::GlyphSet::_repeat;

use strict;
use base qw( Bio::EnsEMBL::GlyphSet_simple );

sub features {
  my $self = shift;
## Need to add code to restrict by logic_name and by db!

  my $types      = $self->my_config( 'types'      );
  my $logicnames = $self->my_config( 'logicnames' );

  my @repeats = sort { $a->seq_region_start <=> $b->seq_region_end }
                 map { my $t = $_; map { @{ $self->{'container'}->get_all_RepeatFeatures( $t, $_ ) } } @$types }
                @$logicnames;
  
  return \@repeats;
}

sub colour_key {
  my( $self, $f ) = @_;
  return 'repeat';
}

sub image_label {
  my( $self, $f ) = @_;
  return '', 'invisible';
}

sub title {
  my( $self, $f ) = @_;
  return sprintf "%s; Type: %s; Analysis: %s",
    $f->repeat_consensus()->name(),
    $f->repeat_consensus->repeat_type,
    $f->analysis->logic_name;
}

sub href {
  return;
}

sub tag {
  return;
}
1 ;
