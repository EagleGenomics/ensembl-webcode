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

package EnsEMBL::Web::Component::Gene::HomologAlignment;

use strict;

use Bio::AlignIO;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $cdb          = shift || $hub->param('cdb') || 'compara';

  my $species      = $hub->species;
  my $species_defs = $hub->species_defs;
  my $gene_id      = $self->object->stable_id;
  my $second_gene  = $hub->param('g1');
  my $homology_id  = $hub->param('hom_id');
  my $seq          = $hub->param('seq');
  my $text_format  = $hub->param('text_format');
  my (%skipped, $html);

  my $match_type = $hub->action eq 'Compara_Ortholog' ? 'Orthologue' : 'Paralogue';
  my %desc_mapping = $self->object->get_desc_mapping($match_type); 
 
  my $homology_types = EnsEMBL::Web::Constants::HOMOLOGY_TYPES;
 
  my $homologies = $self->get_homologies;
 
  foreach my $homology (@{$homologies}) {

  # Remove the homologies with hidden species
  foreach my $homology (@{$homologies}) {

    my $compara_seq_type = $seq eq 'cDNA' ? 'cds' : undef;
    $homology->update_alignment_stats($compara_seq_type);
    my $sa;
    
    eval {
      $sa = $homology->get_SimpleAlign(-SEQ_TYPE => $compara_seq_type);
    };
    warn $@ if $@;
    
    if ($sa) {
      my $data = [];
      
      foreach my $peptide (@{$homology->get_all_Members}) {
        
        my $gene = $peptide->gene_member;
        my $member_species = ucfirst $peptide->genome_db->name;
        my $location       = sprintf '%s:%d-%d', $gene->dnafrag->name, $gene->dnafrag_start, $gene->dnafrag_end;
        
        if ($gene->stable_id eq $gene_id) {
          push @$data, [
            $species_defs->species_label($member_species),
            $gene->stable_id,
            $peptide->stable_id,
            sprintf('%d %s', $peptide->seq_length, $unit),
            sprintf('%d %%', $peptide->perc_id),
            sprintf('%d %%', $peptide->perc_cov),
            $location,
          ]; 
        } else {
          push @$data, [
            $species_defs->species_label($member_species),
            sprintf('<a href="%s">%s</a>',
              $hub->url({ species => $member_species, type => 'Gene', action => 'Summary', g => $gene->stable_id, r => undef }),
              $gene->stable_id
            ),
            sprintf('<a href="%s">%s</a>',
              $hub->url({ species => $member_species, type => 'Transcript', action => 'ProteinSummary', peptide => $peptide->stable_id, __clear => 1 }),
              $peptide->stable_id
            ),
            sprintf('%d %s', $peptide->seq_length, $unit),
            sprintf('%d %%', $peptide->perc_id),
            sprintf('%d %%', $peptide->perc_cov),
            sprintf('<a href="%s">%s</a>',
              $hub->url({ species => $member_species, type => 'Location', action => 'View', g => $gene->stable_id, r => $location, t => undef }),
              $location
            )
          ];
        }
      }
      
      my $homology_desc_mapped = $Bio::EnsEMBL::Compara::Homology::PLAIN_TEXT_DESCRIPTIONS{$homology->{'_description'}} || $homology->{'_description'} || 'no description';

      $html .= "<h2>Type: $homology_desc_mapped</h2>";
      
      my $ss = $self->new_table([
          { title => 'Species',          width => '20%' },
          { title => 'Gene ID',          width => '15%' },
          { title => "$gene_product ID",       width => '15%' },
          { title => "$gene_product length",   width => '10%' },
          { title => $identity_title,    width => '10%' },
          { title => '% coverage',       width => '10%' },
          { title => 'Genomic location', width => '20%' }
        ],
        $data
      );
      
      $html .= $ss->render;

      my $alignio = Bio::AlignIO->newFh(
        -fh     => IO::String->new(my $var),
        -format => $self->renderer_type($text_format)
      );
      
      print $alignio $sa;
      
      $html .= "<pre>$var</pre>";
    }
  }
  
  if (scalar keys %skipped) {
    my $count;
    $count += $_ for values %skipped;
    
    $html .= '<br />' . $self->_info(
      'Orthologues hidden by configuration',
      sprintf(
        '<p>%d orthologues not shown in the table above from the following species. Use the "<strong>Configure this page</strong>" on the left to show them.<ul><li>%s</li></ul></p>',
        $count,
        join "</li>\n<li>", map "$_ ($skipped{$_})", sort keys %skipped
      )
    );
  }
  
  return $html;
}        

sub get_homologies {
  my $self         = shift;
  my $hub          = $self->hub;
  my $cdb          = shift || $hub->param('cdb') || 'compara';
  my $object       = $self->object || $hub->core_object('gene');
  my $gene_id      = $object->stable_id;

  my $database     = $hub->database($cdb);
  my $qm           = $database->get_GeneMemberAdaptor->fetch_by_stable_id($gene_id);
  my $homologies;
  my $ok_homologies = [];
  
  eval {
    $homologies = $database->get_HomologyAdaptor->fetch_all_by_Member($qm);
  };
  warn $@ if $@;
 
  my $match_type    = $hub->action eq 'Compara_Ortholog' ? 'Orthologue' : 'Paralogue';
  my %desc_mapping  = $object->get_desc_mapping($match_type); 
 
  my $homology_types = EnsEMBL::Web::Constants::HOMOLOGY_TYPES;

  foreach my $homology (@{$homologies}) {

    ## filter out non-required types
    my $homology_desc  = $homology_types->{$homology->{'_description'}} || $homology->{'_description'};
    next unless $desc_mapping{$homology_desc}; 

    push @$ok_homologies, $homology;     
  }

  return $homologies;
}

sub renderer_type {
  my $self = shift;
  my $K    = shift;
  my %T    = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;
  return $T{$K} ? $K : EnsEMBL::Web::Constants::SIMPLEALIGN_DEFAULT;
}

sub export_options { return {'action' => 'Homologs'}; }

sub get_export_data {
## Get data for export
  my ($self, $type) = @_;

  ## Fetch explicitly, as we're probably coming from a DataExport URL
  if ($type && $type eq 'gene') {
    return $self->hub->core_object('gene');
  }

  ## ...or get alignments
  my $simple_alignments = [];
  my $seq = $self->hub->param('align');
  
  my $homologies = $self->get_homologies;
 
  foreach my $homology (@{$homologies}) {

    my $sa;
    
    eval {
      if($seq eq 'cDNA') {
        $sa = $homology->get_SimpleAlign(-SEQ_TYPE => 'cds');
      } else {
        $sa = $homology->get_SimpleAlign;
      }
    };
    warn $@ if $@;
    
    push @$simple_alignments, $sa if $sa;
  }

  return $simple_alignments;
}

sub buttons {
  my $self    = shift;
  my $hub     = $self->hub;
  my $gene    =  $self->object->Obj;

  my $dxr  = $gene->can('display_xref') ? $gene->display_xref : undef;
  my $name = $dxr ? $dxr->display_id : $gene->stable_id;

  my $params  = {
                  'type'      => 'DataExport', 
                  'action'    => 'Homologs', 
                  'data_type' => 'Gene', 
                  'component' => 'HomologAlignment', 
                  'gene_name' => $name, 
                  'align'     => $hub->param('seq') || 'protein',
                };

  return {
    'url'     => $hub->url($params),
    'caption' => 'Download alignment',
    'class'   => 'export',
    'modal'   => 1
  };
}


1;

