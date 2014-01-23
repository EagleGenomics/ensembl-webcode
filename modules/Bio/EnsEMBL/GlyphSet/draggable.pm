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

package Bio::EnsEMBL::GlyphSet::draggable;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _colour_background { return 0; }

sub _init {
  my $self      = shift;
  my $container = $self->{'container'};
  my $strand    = $self->strand > 0 ? 1 : 0;
  my $start     = $container->start;
  my $end       = $container->end;
  my $glyph     = $self->Rect({
    x      => 0,
    y      => 6,
    width  => $end - $start + 1,
    height => 0,
    color  => 'black'
  });
  
  my @common = (
    y     => $strand,
    style => 'fill',
    z     => -10,
    alt   => 'Click and drag to select a region',
    class => 'drag',
    href  => join('|',
      '#drag', $self->get_parameter('slice_number'), $self->species,
      $container->seq_region_name, $start, $end, $container->strand
    ),
  );
  
  $self->push($glyph);
  $self->join_tag($glyph, 'draggable', { x => $strand,     @common });
  $self->join_tag($glyph, 'draggable', { x => 1 - $strand, @common });
}

1;
