package EnsEMBL::Web::Component::LRG::UserAnnotation;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $html;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  if ($user) {
    my $id = $self->object->param('lrg');
    my $type = 'LRG';
    my $species = $self->object->species;

    my @annotations = $user->annotations;
    my @gene_annotations;
    foreach my $record (@annotations) {
      next unless $record->stable_id eq $id;
      push @gene_annotations, $record;
    }
    if (scalar(@gene_annotations)) {
      foreach my $annotation (@gene_annotations) {
        $html = '<h2>'.$annotation->title.'</h2><pre>'.$annotation->annotation.'</pre>';
        $html .= qq(<p><a href="/Account/Annotation/Edit?id=).$annotation->id.qq(;species=$species" class="modal_link">Edit this annotation</a>.</p>);
      }
    }
    else {
      $html = qq(<p>You don't have any annotation on this LRG. <a href="/Account/Annotation/Add?stable_id=$id;ftype=$type;species=$species" class="modal_link">Add an annotation</a>.</p>);
    }
  }
  else {
    $html = $self->_info('User Account', 'You need to be logged in to save your own annotation');
  }

  return $html;
}

1;
