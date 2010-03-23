package EnsEMBL::Web::Component::Gene::TranscriptsImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init { 
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub caption {
  my $html = 'Transcripts';
  return $html;
}

sub content {
  my $self = shift;
  my $gene = $self->object;

  my @trans = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts};
  my $gene_slice = $gene->Obj->feature_Slice->expand(10e3, 10e3);
     $gene_slice = $gene_slice->invert if $gene->seq_region_strand < 0;
     
  # Get the web_image_config
  my $image_config = $gene->image_config_hash('gene_summary');
  
  $image_config->set_parameters({
    'container_width' => $gene_slice->length,
    'image_width',    => $gene->param('i_width') || $self->image_width || 800,
    'slice_number'    => '1|1',
  });
  
  $self->_attach_das($image_config);

  my $key = $image_config->get_track_key('transcript', $gene);
  my $n   = $image_config->get_node(lc($key));

  $n->set('display', 'transcript_label') if $n && $n->get('display') eq 'off';

  my $image = $self->new_image($gene_slice, $image_config, [ $gene->Obj->stable_id ]);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');


  my $html = $image->render;
  $html .= $self->_info(
    'Configuring the display',
    '<p>Tip: use the "<strong>Configure this page</strong>" link on the left to show additional data in this region.</p>'
  );
  
  return $html;
}

1;
