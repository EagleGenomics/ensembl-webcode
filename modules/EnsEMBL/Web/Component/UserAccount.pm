package EnsEMBL::Web::Component::UserAccount;

use EnsEMBL::Web::Component;

use strict;
use warnings;
no warnings "uninitialized";

our @ISA = qw( EnsEMBL::Web::Component);


sub _wrap_form {
  my ( $panel, $object, $node ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form($node)->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

##-----------------------------------------------------------------

sub accountview {
  my( $panel, $object ) = @_;
  my $html;

  my $id = $object->get_user_id;
  $html .= _show_details($panel, $object, $id);
  #$html .= _show_groups($panel, $object, $id);
  $html .= _show_bookmarks($panel, $object, $id);
  #$html .= _show_mydas($panel, $object, $id);

  $panel->print($html);
  return 1;
}

sub _show_details {
  my( $panel, $object, $id ) = @_;

  my %details = %{$object->get_user_by_id($id)};

## Get the user's full name
  my $name  = $details{'name'};
  my $email = $details{'email'};
  my $org   = $details{'org'};

## return the message
  my $html = "<h3>Personal details</h3>";

  $html .= qq(<p><strong>Name</strong>: $name</p>
<p><strong>Email address</strong>: $email</p>
<p><strong>Organisation</strong>: $org</p>);

  return $html;
}

sub _show_groups {
  my( $panel, $object, $id ) = @_;

## Get the user's group list
  my @groups = @{$object->get_groups_by_user($id)};

## return the message
  my $html = "<h3>My Groups</h3>\n";

  if (scalar(@groups) > 0) {
    $html .= "<ul>\n";
    foreach my $group (@groups) {
      my $title = $$group{'title'};
      $html .= qq(<li>$title</li>);
    }
    $html .= qq(</ul>
<p><a href="/Multi/user_manage_groups">Manage group subscriptions</a></p>);
  }
  else {
    $html .= "<p>You have not subscribed to any groups.</p>";
  }

  return $html;
}

sub _show_bookmarks {
  my( $panel, $object, $id ) = @_;

## Get the user's bookmark list
  my @bookmarks = @{$object->get_bookmarks($id)};

## return the message
  my $html = "<h3>My bookmarks</h3>\n";

  if (scalar(@bookmarks) > 0) {
    $html .= "<ul>\n";
    foreach my $bookmark (@bookmarks) {
      my $name = $$bookmark{'bm_name'};
      my $url  = $$bookmark{'bm_url'};
      $html .= qq(<li><a href="$url">$name</a></li>);
    }
    $html .= qq(</ul>
<p><a href="/Multi/user_manage_bkmarks">Manage bookmarks</a></p>);
  }
  else {
    $html .= "<p>You have no bookmarks set.</p>";
  }

  return $html;
}

sub _show_mydas {
  my( $panel, $object, $id ) = @_;

## Get the user's DAS upload list
  my $das_list = {};

## return the message
  my $html = "<h3>My DAS uploads</h3>\n";

  if (keys %$das_list) {
    $html .= "<ul>\n";
    while( my ($text, $url) = each %$das_list) {
      $html .= qq(<li><a href="$url">$text</a></li>);
    }
    $html .= "</ul>\n";
  }
  else {
    $html .= "<p>You have not uploaded any DAS sources.</p>";
  }

  return $html;
}

sub denied {
  my( $panel, $object ) = @_;

## return the message
  my $html = qq(<p>Sorry - this page requires you to be logged into your Ensembl user account and to have the appropriate permissions. If you cannot log in or need your access privileges changed, please contact <a href="mailto:webmaster\@ensembl.org">webmaster\@ensembl.org</a>. Thank you.</p>);

  $panel->print($html);
  return 1;
}

##-----------------------------------------------------------------
## USER REGISTRATION COMPONENTS    
##-----------------------------------------------------------------

sub login {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:50%">);
  $html .= $panel->form('login')->render();
  $html .= qq(<p><a href="/Multi/user_register">Register</a> | <a href="/Multi/user_pw_lost">Lost password</a></p>);
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub details   { 
  my ( $panel, $object, $node ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  if (!$object->param('email')) { ## new registration
    $html .= qq(<p><strong>Register with Ensembl to bookmark your favourite pages, manage your DAS uploads and more!</strong></p>);
  }

  $html .= $panel->form('details')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub preview           { _wrap_form($_[0], $_[1], 'preview'); }

sub new_password      { 
  my ( $panel, $object, $node ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);

  if ($object->param('code')) { ## resetting lost password
    $html .= qq(<p><strong>Please enter a new password to reactivate your account.</strong></p>);
  }

  $html .= $panel->form('new_password')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub lost_password {
  my ( $panel, $object ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= qq(<p>Please note that information on resetting your password will be emailed to your <strong>current registered email address</strong>. If you have changed your email address as well as losing your password, please contact <a href="mailto:webmaster\@ensembl.org">webmaster\@ensembl.org</a> for assistance. Thank you.</p>);
  $html .= $panel->form('lost_password')->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub acknowledge {
  my ( $panel, $object ) = @_;
  my $html = '<div>Thank you. An email has been sent to your current registered email address - please check your mailbox and click on the link provided.</div>';
  $panel->print($html);
  return 1;
}

##-----------------------------------------------------------------
## USER CUSTOMISATION COMPONENTS    
##-----------------------------------------------------------------

sub select_bookmarks {
  my ( $panel, $object, $node ) = @_;

  ## Get the user's bookmark list
  my $id = $object->get_user_id;
  my @bookmarks = @{$object->get_bookmarks($id)};

  my $html = qq(<div class="formpanel" style="width:80%">);
  if (scalar(@bookmarks)) {
    $html .= $panel->form($node)->render();
  }
  else {
    $html .= qq(<p>You have no bookmarks set at the moment. To set a bookmark, go to any Ensembl content page whilst logged in (any 'view' page such as GeneView, or static content such as documentation), and click on the "Bookmark this page" link in the lefthand menu.</p>);
  }
  $html .= '</div>';
  
  $panel->print($html);
  return 1;
}

sub name_bookmark     { _wrap_form($_[0], $_[1], 'name_bookmark'); }

sub show_groups {
  my ( $panel, $object ) = @_;

  my $user_id = $object->get_user_id;
  my @groups = @{ $object->get_groups_by_user($user_id) };

  my $html = qq(<div class="formpanel" style="width:80%">);
  if (scalar(@groups)) {
    $html .= qq(<p>Select the group subscriptions you wish to remove:</p>);
    $html .= $panel->form('show_groups')->render();
  }
  else {
    $html .= qq(<p>You have no subscriptions at the moment.</p>);
  }
  $html .= '</div>';
  
  $panel->print($html);
  return 1;
}

1;

