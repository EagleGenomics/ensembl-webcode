package EnsEMBL::Web::Component::Location::Ideogram;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  0 );
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $slice = $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );
  my $wuc = $object->image_config_hash( 'chromosome' );
     $wuc->container_width( $object->seq_region_length );
     $wuc->set_width( $object->param('image_width') );

  my $image    = $object->new_image( $slice, $wuc );
     $image->{'panel_number'} = 'ideogram';
     $image->imagemap = 'yes';
     $image->set_button( 'drag', 'title' => 'Click or drag to centre display' );
  return '<p>.</p>'.$image->render;

}

1;
