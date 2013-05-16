package EnsEMBL::Web::Text::Feature::VEP_INPUT;

### Ensembl default input format for Variant Effect Predictor
### Also used to display individual SNPs

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub seqname           { return $_[0]->{'__raw__'}[0]; }
sub rawstart          { return $_[0]->{'__raw__'}[1];  }
sub rawend            { return $_[0]->{'__raw__'}[2];  }
sub allele            { return $_[0]->{'__raw__'}[3];  }
sub strand            { return $_[0]->{'__raw__'}[4];  }
sub id                { return $_[0]->{'__raw__'}[5];  }

sub coords {
  my ($self, $data) = @_;
  return @$data[0..2]; 
}


1;
