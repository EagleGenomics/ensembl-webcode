package EnsEMBL::Web::Component::Gene::RegulationImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content { 
  my $self = shift;
  my $object = $self->object; 

  ## retrieve default slice
  my $object_slice = $object->Obj->feature_Slice; 
     $object_slice = $object_slice->invert if $object_slice->strand < 1; ## Put back onto correct strand!


  ## retrieve gene_regulation_features_extended_slice
  my $fg_db = undef;
  my $db_type  = 'funcgen';
  unless($object_slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $fg_db = $object_slice->adaptor->db->get_db_adaptor($db_type);
    if(!$fg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
 }

  my $fg_slice_adaptor = $fg_db->get_SliceAdaptor;
  my $fsets = $object->feature_sets;  
  my $gr_slice = $fg_slice_adaptor->fetch_by_Gene_FeatureSets($object->Obj, $fsets);
  $gr_slice = $gr_slice->invert if $gr_slice->strand < 1; ## Put back onto correct strand!


## Now we need to extend the slice!! Default is to add 2kb to either end of slice, if gene_reg slice is 
## extends more than this use the values returned from this 
  my $start = $object->Obj->start; 
  my $end   = $object->Obj->end;  

  my $gr_start = $gr_slice->start;
  my $gr_end = $gr_slice->end;  
  my ($new_start, $new_end);

  if ( ($start  - 2000) < $gr_start) {
     $new_start = 2000; 
  } else {
     $new_start = $start - $gr_start;
  }

  if ( ($end +2000) > $gr_end) {
    $new_end = 2000;
  }else {
    $new_end = $gr_end - $end;
  }

  my $extended_slice =  $object_slice->expand($new_start, $new_end);
  my $offset = $extended_slice->start -1;

  my $trans = $object->get_all_transcripts;
  my $gene_track_name =$trans->[0]->default_track_by_gene;

  my $wuc = $object->get_imageconfig( 'generegview' );
 
 $wuc->set_parameters({
       'container_width'   => $extended_slice->length,
       'image_width',      => $self->image_width || 800,
       'slice_number',     => '1|1',
     });

  ## We now need to select the correct track to turn on....

  my $key = $wuc->get_track_key( 'transcript', $object );
  ## Then we turn it on....
  $wuc->modify_configs( [$key], {qw(display transcript)} );
  $wuc->cache( 'feature_sets', $fsets);  
  $wuc->cache('gene', $object);
  
  my $image    = $self->new_image( $extended_slice, $wuc, [] );
      $image->imagemap           = 'yes';
      $image->{'panel_number'} = 'top';
      $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

return $image->render;
}

1;
