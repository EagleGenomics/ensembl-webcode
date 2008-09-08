package EnsEMBL::Web::Component::Gene::TranscriptsImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init { 
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  my $html = 'Transcripts';
  return $html;
}

sub content {
  my $self = shift;
  my $gene = $self->object;

  my @trans = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts()};
  my $gene_slice = $gene->Obj->feature_Slice->expand( 10e3, 10e3 );
     $gene_slice = $gene_slice->invert if $gene->seq_region_strand < 0;
    ## Get the web_user_config
  my $wuc        = $gene->user_config_hash( 'gene_summary' );
     $wuc->set_parameters({
       'container_width'   => $gene_slice->length,
       'image_width',      => $self->image_width || 800,
       'slice_number',     => '1|1',
     });

  ## We now need to select the correct track to turn on....
  
  my $key = $wuc->get_track_key( 'transcript', $gene );
  ## Then we turn it on....
  $wuc->modify_configs( [$key], {qw(on on)} );

  my  $image  = $gene->new_image( $gene_slice, $wuc, [$gene->Obj->stable_id] );
      $image->imagemap         = 'yes';
      $image->{'panel_number'} = 'top';
      $image->set_button( 'drag', 'title' => 'Drag to select region' );


  return $image->render;
}

1;
