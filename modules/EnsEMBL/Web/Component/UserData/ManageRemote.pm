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
  my $object = $self->object;

  ## Do any 'deletes'
  my $type = $object->param('record') || '';
  my $data = $object->param('data') || '';
  if ($type eq 'session' && $data eq 'url') {
    my $temp = $self->object->get_session->get_tmp_data('url');
    my $urls = $temp->{'urls'} || [];
    if (scalar(@$urls) && $object->param('url')) {
      for my $i ( 0 ..  $#{@$urls}) { 
        if ( $urls->[$i]{'url'} eq $object->param('url') ) { 
          splice @$urls, $i, 1; 
        } 
      } 
    }
    if (scalar(@$urls) < 1) {
      $object->get_session->purge_tmp_data('url');
    }
  }
  elsif ($type eq 'user' && $data eq 'url') {
    $object->delete_userurl($object->param('id'));
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
        my $link = sprintf('<a href="%s/UserData/DeleteDAS?id=%s;%s" class="modal_link">Delete</a>', $dir, $source->id, $referer);
        $table->add_row( { 'name'  => $source->label, 'date' => $self->pretty_date($date), 'delete' => $link } );
      }
      else { ## temporary
        if ($user) {
          $save = sprintf('<a href="%s/UserData/SaveRemote?wizard_next=save_tempdas;dsn=%s;%s" class="modal_link">Save to account</a>', $dir, $source->logic_name, $referer);
        }
        my $detach = sprintf('<a href="%s/UserData/DeleteDAS?logic_name=%s;%s" class="modal_link">Remove</a>', $dir, $source->logic_name, $referer);
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

  my $temp = $self->object->get_session->get_tmp_data('url');
  my $urls = $temp->{'urls'} || [];

  if ($user) {
    push @$urls, $user->urls;
  }

  if (@$urls) {
    my $table = EnsEMBL::Web::Document::SpreadSheet->new( [], [], {'margin' => '0 0 1em 0'} );
    $table->add_columns(
      {'key' => "url", 'title' => 'Datasource URL', 'width' => '50%', 'align' => 'left' },
      {'key' => "date", 'title' => 'Last updated', 'width' => '20%', 'align' => 'left' },
      {'key' => "save", 'title' => '', 'width' => '15%', 'align' => 'left' },
      {'key' => "delete", 'title' => '', 'width' => '15%', 'align' => 'left' },
    );
    foreach my $source (@$urls) {
      if (ref($source) =~ /Record/) { ## from user account
        my $date = $source->modified_at || $source->created_at;
        my $link = sprintf('<a href="%s/UserData/ManageRemote?record=user;data=url;id=%s;%s" class="modal_link">Delete</a>', $dir, $source->id, $referer);
        $table->add_row( { 'url'  => $source->url, 'date' => $self->pretty_date($date), 'delete' => $link } );
      }
      else { ## temporary
        if ($user) {
          $save = sprintf('<a href="%s/UserData/SaveRemote?wizard_next=save_tempdas;url=%s;species=%s;%s" class="modal_link">Save to account</a>', $dir, $source->{'url'}, $source->{'url'}, $referer);
        }
        my $detach = sprintf('<a href="%s/UserData/ManageRemote?record=session;data=url;url=%s;%s" class="modal_link">Remove</a>', $dir, $source->{'url'}, $referer);
        $table->add_row( { 'url'  => $source->{'url'}.'<br />('.$source->{'species'}.')', 'date' => 'N/A', 'save' => $save, 'delete' => $detach } );
      }
    }
    $html .= $table->render;
  }
  else {
    $html .= qq(<p class="space-below">You have no URL data attached.</p>);
  }

  $html .= $self->_info(
    'Adding tracks',
    qq(<p>Please note that custom data can only be added on pages that allow these tracks to be configured, for example 'Region in detail' images</p>),
    '100%',
  );

  return $html;
}

1;
