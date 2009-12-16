package EnsEMBL::Web::Command::Help::DoSearch;

# Searches the help_record table in the ensembl_website database 

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Help;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  my $new_param;
  if ($object->param('hilite')) {
    $new_param->{'hilite'} = $object->param('hilite');
    $new_param->{'string'} = $object->param('string');
  }

  my $help = EnsEMBL::Web::Data::Help->new;
  my @results;
  my %matches = %{ $help->search({'string'=>$object->param('string')}) };
  if (keys %matches) {
    while (my ($k, $v) = each (%matches)) {
      push @results, $v.'_'.$k;
    }
  }
  $new_param->{'result'} = \@results;

  $self->ajax_redirect('/Help/Results', $new_param);
}

1;
