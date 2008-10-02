package EnsEMBL::Web::Component::Account::AdimnDetails;

### Module to show details of a particular group that an administrator belongs to

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return undef;
}

sub content {
  my $self = shift;
  return unless $self->object->param('id');

  my $html;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $group = EnsEMBL::Web::Data::Group->new($self->object->param('id')); 

  if ($group) {
    my $creator = EnsEMBL::Web::Data::User->new($group->created_by);

    #$html .= '<p class="right"><a href="/Account/MemberGroups">&larr; Hide details</a></p>';

    $html .= '<div class="plain-box" style="padding:1em;margin:1em">';
    $html .= '<p><strong>Group created by</strong>: '.$creator->name;
    $html .= ' <strong>on</strong> '.$self->pretty_date($group->created_at).'</p>';

    $html .= '<h3>Bookmarks</h3>';
    if ($group->bookmarks) {

      my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

      $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',          'width' => '30%', 'align' => 'left' },
        { 'key' => 'desc',      'title' => 'Description',   'width' => '70%', 'align' => 'left' },
      );

      foreach my $bookmark ($group->bookmarks) {
        my $row = {};

        $row->{'name'} = sprintf(qq(<a href="/Account/UseBookmark?id=%s" title="%s" class="cp-internal">%s</a>),
                        $bookmark->id, $bookmark->url, $bookmark->name);

        $row->{'desc'} = $bookmark->description || '&nbsp;';

        $table->add_row($row);
      }
      $html .= $table->render;
    }
    else {
      $html .= '<p>No shared bookmarks</p>';
    }

    $html .= '<h3>Configurations</h3>';
    if ($group->configurations) {

      my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

      $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',          'width' => '30%', 'align' => 'left' },
        { 'key' => 'desc',      'title' => 'Description',   'width' => '70%', 'align' => 'left' },
      );

      foreach my $config ($group->configurations) {
        my $row = {};
        
        $row->{'name'} = sprintf(qq(<a href="/Account/UseConfig?id=%s" class="cp-internal">%s</a>),
                        $config->id, $config->name);

        $row->{'desc'} = $config->description || '&nbsp;';

        $table->add_row($row);
      }
      $html .= $table->render;
    }
    else {
      $html .= '<p>No shared configurations</p>';
    }

    $html .= '<h3>Annotations</h3>';
    if ($group->annotations) {

      my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

      $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',    'width' => '30%', 'align' => 'left' },
        { 'key' => 'title',      'title' => 'Title',  'width' => '70%', 'align' => 'left' },
      );

      foreach my $note ($group->annotations) {
        my $row = {};

        $row->{'name'} = sprintf(qq(<a href="/Gene/Summary?g=%s" class="cp-external">%s</a>),
                        $note->stable_id, $note->stable_id);

        $row->{'title'} = $note->title || '&nbsp;';

        $table->add_row($row);
      }
      $html .= $table->render;
    }
    else {
      $html .= '<p>No shared annotations</p>';
    }

    $html .= '</div>';
  }

  return $html;
}

1;
