package EnsEMBL::Web::Component::UserData::ManageRemote;

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;

  ## Do any 'deletes'
  my $type = $object->param('record') || '';
  my $data = $object->param('user') || '';
  if ($type eq 'session') {
    if ($data eq 'url') {
      $object->get_session->purge_tmp_data('url');
    }
    elsif ($data eq 'das') {
      my $temp_das = $object->get_session->get_all_das;
      if ($temp_das) {
        my $das = $temp_das->{$object->param('logic_name')};
        $das->mark_deleted();
        $object->get_session->save_das();
      }
    }
  }
  elsif ($type eq 'user') {
    if ($data eq 'url') {
      $object->delete_userurl($object->param('id'));
    }
    elsif ($data eq 'das') {
      $object->delete_userdas($object->param('id'));
    }
  }

  ## Control panel fixes
  my $dir = '/'.$ENV{'ENSEMBL_SPECIES'};
  $dir = '' if $dir !~ /_/;
  my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');

  my $html;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $save = sprintf('<a href="%s/Account/Login?%s" class="modal_link">Log in to save</a>', $dir, $referer);

  ## List DAS sources
  $html .= "<h4>DAS sources</h4>";

  my @sources = values %{$self->object->get_session->get_all_das};

  if ($user) {
    push @sources, $user->dases;
  }

  if (@sources) {

    my $table = EnsEMBL::Web::Document::SpreadSheet->new();
    $table->add_columns(
      {'key' => "name", 'title' => 'Datasource name', 'width' => '50%', 'align' => 'left' },
      {'key' => "date", 'title' => 'Last updated', 'width' => '20%', 'align' => 'left' },
      {'key' => "save", 'title' => '', 'width' => '15%', 'align' => 'left' },
      {'key' => "delete", 'title' => '', 'width' => '15%', 'align' => 'left' },
    );
    
    foreach my $source (sort { lc $a->label cmp lc $b->label } @sources) {

      if (ref($source) =~ /Record/) { ## from user account
        my $date = $source->modified_at || $source->created_at;
        my $link = sprintf('<a href="%s/UserData/ManageRemote?record=user;data=das;id=%s;%s" class="modal_link">Delete</a>', $dir, $source->id, $referer);
        $table->add_row( { 'name'  => $source->label, 'date' => $self->pretty_date($date), 'delete' => $link } );
      }
      else { ## temporary
        if ($user) {
          $save = sprintf('<a href="%s/UserData/SaveRemote?wizard_next=save_tempdas;dsn=%s;%s" class="modal_link">Save to account</a>', $dir, $source->logic_name, $referer);
        }
        my $detach = sprintf('<a href="%s/UserData/ManageRemote?record=session;data=das;logic_name=%s;%s">Detach</a>', $dir, $source->logic_name, $referer);
        $table->add_row( { 'name'  => $source->label, 'date' => 'N/A', 'save' => $save, 'delete' => $detach } );
      }

    }
    $html .= $table->render;
  }
  else {
    $html .= qq(<p class="space-below">You have no DAS sources attached.</p>);
  }

  ## List URL data
  $html .= "<h4>URL-based data</h4>";

  my @urls;
  my $temp_url = $self->object->get_session->get_tmp_data('url');
  if ($temp_url && $temp_url->{'url'}) {
    @urls = ($temp_url);
  }

  if ($user) {
    push @urls, $user->urls;
  }

  if (@urls) {
    my $table = EnsEMBL::Web::Document::SpreadSheet->new();
    $table->add_columns(
      {'key' => "url", 'title' => 'Datasource URL', 'width' => '50%', 'align' => 'left' },
      {'key' => "date", 'title' => 'Last updated', 'width' => '20%', 'align' => 'left' },
      {'key' => "save", 'title' => '', 'width' => '15%', 'align' => 'left' },
      {'key' => "delete", 'title' => '', 'width' => '15%', 'align' => 'left' },
    );
    foreach my $source (@urls) {
      if (ref($source) =~ /Record/) { ## from user account
        my $date = $source->modified_at || $source->created_at;
        my $link = sprintf('<a href="%s/UserData/ManageRemote?record=user;data=url;id=%s;%s">Delete</a> class="modal_link"', $dir, $source->id, $referer);
        $table->add_row( { 'url'  => $source->url, 'date' => $self->pretty_date($date), 'delete' => $link } );
      }
      else { ## temporary
        if ($user) {
          $save = sprintf('<a href="%s/UserData/SaveRemote?wizard_next=save_tempdas;url=%s;%s" class="modal_link">Save to account</a>', $dir, $source->{'url'}, $referer);
        }
        my $detach = sprintf('<a href="%s/UserData/ManageRemote?record=session;data=url;%s" class="modal_link">Detach</a>', $dir, $referer);
        $table->add_row( { 'url'  => $source->{'url'}, 'date' => 'N/A', 'save' => $save, 'delete' => $detach } );
      }
    }
    $html .= $table->render;
  }
  else {
    $html .= qq(<p class="space-below">You have no URL data attached.</p>);
  }
  return $html;
}

1;
