package EnsEMBL::Web::Component::UserData::UploadStableIDs;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Select File to Upload';
}

sub content {
  my $self = shift;
  my $object = $self->object;

 my $referer = '_referer='.$object->param('_referer').';x_requested_with='.$object->param('x_requested_with');
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $object->data_species;

  ## Get assembly info
  my $html;

  my $form = $self->modal_form('select', "/$current_species/UserData/CheckConvert");
  my $subheader = 'Upload file';

   ## Species now set automatically for the page you are on
  $form->add_element( type => 'NoEdit', name => 'show_species', label => 'Species', 'value' => $self->object->species_defs->species_label($current_species));
  $form->add_element( type => 'Hidden', name => 'species', 'value' => $current_species);
  $form->add_element( type => 'Hidden', name => 'id_mapper', 'value' => 1);
  ## Check for uploaded data for this species
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user) {
    my (@data, @temp);
    foreach my $upload ($user->uploads) {
      next unless $upload->species eq $object->species;
      push @data, $upload;
    }
    foreach my $upload ($object->get_session->get_data('type' => 'upload')) {
      next unless $upload->{'species'} eq $object->species;
      push @data, $upload;
    }
    foreach my $url ($user->urls) {
      next unless $url->species eq $object->species;
      push @data, $url;
    }
    foreach my $url ($object->get_session->get_data('type' => 'url')) {
      next unless $url->{'species'} eq $object->species;
    }

    if (@data) {
      $form->add_element('type' => 'SubHeader',
        'value' => 'Select existing upload(s)',
      );
      foreach my $file (@data) {
        my ($name, $id, $species);
        if (ref ($file) =~ /Record/) {
          my $type = $file->type;
          $name = $file->name;
          $id   = 'user-'.$type.'-'.$file->id;
        }
        else {
          my $type = $file->{'type'};
          $name = $file->{'name'};
          $id   = 'temp-'.$type.'-'.$file->{'code'};
        }
        $form->add_element(
          'type'    => 'CheckBox',
          'name'    => 'convert_file',
          'label'   => $name,
          'value'   => $id.':'.$name,
        );
      }
      $subheader = 'Or upload new file';
    }
  }

  $form->add_element('type' => 'SubHeader', 'value' => $subheader);

  $form->add_element( type => 'String', name => 'name', label => 'Name for this upload (optional)' );

  $form->add_element( type => 'Text', name => 'text', label => 'Paste file' );
  $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $form->add_element( type => 'String', name => 'url', label => 'or provide file URL', size => 30 );
 

  $html .= $form->render;
  return $html;
}


1;
