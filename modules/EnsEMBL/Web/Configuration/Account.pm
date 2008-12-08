package EnsEMBL::Web::Configuration::Account;

### Configuration for all views based on the Account object, including
### account management 

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub _get_valid_action {
  my $self = shift;
  return $_[0] if $_[0] eq 'SetCookie';
  return $self->SUPER::_get_valid_action( @_ );
}

sub set_default_action {
  my $self = shift;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user && $user->id) {
    $self->{_data}{default} = 'Links';
  }
  else {
    $self->{_data}{default} = 'Login';
  }
}

sub global_context { return $_[0]->_user_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return undef; }
sub content_panel  { return $_[0]->_content_panel;   }
sub context_panel  { return undef; }


sub user_populate_tree {
  my $self = shift;

  if (my $user = $ENSEMBL_WEB_REGISTRY->get_user) {

    my $settings_menu = $self->create_submenu( 'Settings', 'Manage Saved Settings' );

    $settings_menu->append(
      $self->create_node( 'Bookmarks', "Bookmarks ([[counts::bookmarks]])",
        [qw(bookmarks EnsEMBL::Web::Component::Account::Bookmarks)],
        { 'availability' => 1, 'concise' => 'Bookmarks' },
      )
    );
    ## Control panel fixes
    my $species = $ENV{'ENSEMBL_SPECIES'};
    $species = '' if $species !~ /_/;
    $species = $self->object->species_defs->ENSEMBL_PRIMARY_SPECIES unless $species;
    my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');

    $settings_menu->append(
      $self->create_node( 'UserData', "Custom data ([[counts::userdata]])",
        [], { 'availability' => 1, 'url' => '/'.$species.'/UserData/ManageData?'.$referer, 'raw' => 1 },
      )
    );

    #$settings_menu->append($self->create_node( 'Configurations', "Configurations ([[counts::configurations]])",
    #[qw(configs EnsEMBL::Web::Component::Account::Configurations
    #    )],
    #  { 'availability' => 1, 'concise' => 'Configurations' }
    #));
    #$settings_menu->append($self->create_node( 'Annotations', "Gene Annotations ([[counts::annotations]])",
    #[qw(notes EnsEMBL::Web::Component::Account::Annotations
    #    )],
    #  { 'availability' => 1, 'concise' => 'Annotations' }
    #));

    $settings_menu->append(
      $self->create_node( 'NewsFilters', "News Filters ([[counts::news_filters]])",
        [qw(news EnsEMBL::Web::Component::Account::NewsFilters)],
        { 'availability' => 1, 'concise' => 'News Filters' },
      )
    );

    my $groups_menu = $self->create_submenu( 'Groups', 'Groups' );
    
    $groups_menu->append(
      $self->create_node( 'MemberGroups', "Subscriptions ([[counts::member]])",
        [qw(
          groups   EnsEMBL::Web::Component::Account::MemberGroups
          details  EnsEMBL::Web::Component::Account::MemberDetails
        )],
        { 'availability' => 1, 'concise' => 'Subscriptions' }
      )
    );
    
    $groups_menu->append(
      $self->create_node( 'AdminGroups', "Administrator ([[counts::admin]])",
        [qw(
          admingroups   EnsEMBL::Web::Component::Account::AdminGroups
          admindetails  EnsEMBL::Web::Component::Account::MemberDetails
        )],
        { 'availability' => 1, 'concise' => 'Administrator' },
      )
    );

    $groups_menu->append(
      $self->create_node( 'CreateGroup', "Create a New Group",
        [],
        { 'availability' => 1, 'concise' => 'Create a Group', 
          'url' => '/'.$species.'/Account/Group?dataview=add;'.$referer, 'raw' => 1 }
      )
    );
    
    $self->create_node( 'ManageGroup', '',
      [qw(manage_group EnsEMBL::Web::Component::Account::ManageGroup)],
      { 'no_menu_entry' => 1 }
    );
  }
   
}

sub populate_tree {
  my $self = shift;

  if (my $user = $ENSEMBL_WEB_REGISTRY->get_user) {

    $self->create_node( 'Links', 'Quick Links',
      [qw(links EnsEMBL::Web::Component::Account::Links)],
      { 'availability' => 1 },
    );
    $self->create_node( 'Details', 'Your Details',
      [qw(account EnsEMBL::Web::Component::Account::Details)],
      { 'availability' => 1 }
    );
    $self->create_node( 'ChangePassword', 'Change Password',
      [qw(password EnsEMBL::Web::Component::Account::Password)], 
      { 'availability' => 1 }
    );

  } else {
    $self->create_node( 'Login', "Log in",
      [qw(account EnsEMBL::Web::Component::Account::Login)],
      { 'availability' => 1 }
    );
    $self->create_node( 'Register', "Register",
      [qw(account EnsEMBL::Web::Component::Account::Register)],
      { 'availability' => 1 },
    );
    $self->create_node( 'LostPassword', "Lost Password",
      [qw(account EnsEMBL::Web::Component::Account::LostPassword)],
      { 'availability' => 1 }
    );
    $self->create_node( 'Activate', "",
      [qw(password EnsEMBL::Web::Component::Account::Password)], 
      { 'no_menu_entry' => 1 }
    );
  }

  ## Add "invisible" nodes used by interface but not displayed in navigation
  $self->create_node( 'Message', '',
    [qw(message EnsEMBL::Web::Component::CommandMessage)],
    { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'LoggedIn', '',
    [qw(logged_in EnsEMBL::Web::Component::Account::LoggedIn)],
    { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'Logout', "Log Out",
    [],
    { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'RegistrationFailed', '',
    [qw(reg_failed EnsEMBL::Web::Component::Account::RegistrationFailed)],
    { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'Update', '',
    [qw(update EnsEMBL::Web::Component::Account::Update)],
    { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'UpdateFailed', '',
    [qw(update_failed EnsEMBL::Web::Component::Account::UpdateFailed)],
    { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'SelectGroup', '',
    [qw(select_group EnsEMBL::Web::Component::Account::SelectGroup)],
    { 'no_menu_entry' => 1 }
  );

}

sub tree_cache_key {
  my ($class, $user, $session) = @_;

  ## Default trees for logged-in users and 
  ## for non logged-in are defferent
  ## but we cache both:
  my $key = ($ENSEMBL_WEB_REGISTRY->get_user)
             ? "::${class}::TREE::USER"
             : "::${class}::TREE";

  ## If $user was passed this is for
  ## user_populate_tree (this user specific tree)
  $key .= '['. $user->id .']'
    if $user;

  return $key;
}

1;
