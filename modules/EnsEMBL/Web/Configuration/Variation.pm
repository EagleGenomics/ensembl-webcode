package EnsEMBL::Web::Configuration::Variation;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Document::Panel::Image;
use Data::Dumper;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Structure';
}

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub populate_tree {
  my $self = shift;

  $self->create_node( 'Structure', "Transcript Neighbourhood",
    [qw(neighbourhood EnsEMBL::Web::Component::Gene::transcript_neighbourhood)],
    { 'availability' => 1}
  );
}

1;
