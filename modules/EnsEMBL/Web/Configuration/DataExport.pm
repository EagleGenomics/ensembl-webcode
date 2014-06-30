=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Configuration::DataExport;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Configuration);

sub caption { 
  my $self = shift;
  return 'Export '.$self->hub->action; 
}

sub populate_tree {
  my $self  = shift;

  ## Input nodes
  my @input_nodes = qw(ExonSeq FlankingSeq GeneSeq Protein Transcript TranscriptComparison);
  foreach (@input_nodes) {
    $self->create_node($_, "Sequence Input", [lc($_), 'EnsEMBL::Web::Component::DataExport::'.$_]);
  }

  ## Output nodes
  $self->create_node('Output',  '', [], { 'command' => 'EnsEMBL::Web::Command::DataExport::Output'});
  $self->create_node('Results', 'Results', ['results', 'EnsEMBL::Web::Component::DataExport::Results']);
  $self->create_node('Error', 'Output Error', ['error', 'EnsEMBL::Web::Component::DataExport::Error']);
}

1;