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

package EnsEMBL::Web::Component::DataExport::Homologs;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::DataExport::Alignments);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  ### N.B. There currently are no additional options for alignment export
  my $self  = shift;
  my $hub   = $self->hub;

  my $settings = {
                'possible_orthologs' => {
                                          'type' => 'Checkbox',
                                          'label' => 'Treat not-supported duplications as speciations (makes a non species-tree-compliant tree)',       
                                          'checked' => 1,
                                        },
                'Hidden' => ['align', 'g1', 'data_action']
                };

  ## Options per format
  my $fields_by_format = {'OrthoXML' => [['possible_orthologs']]};

  ## Add formats output by BioPerl
  foreach ($self->alignment_formats) {
    $fields_by_format->{$_} = [];
  }

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

sub default_file_name {
  my $self = shift;
  my $name = $self->hub->species_defs->SPECIES_COMMON_NAME;

  $name .= '_'.$self->hub->param('gene_name').'_ortholog_alignment';
  return $name;
}

1;
