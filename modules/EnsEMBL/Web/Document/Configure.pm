package EnsEMBL::Web::Document::Configure;

use CGI qw(escapeHTML);
use strict;
use warnings;

use EnsEMBL::Web::Root;
use EnsEMBL::Web::RegObj;

our @ISA  = qw(EnsEMBL::Web::Root);

sub common_menu_items {
  my( $self, $doc ) = @_;
## Now the links on the left hand side....

  if ($doc->species_defs->ENSEMBL_LOGINS) {
    ## Is the user logged in?
    my $user = $ENSEMBL_WEB_REGISTRY->get_user;

    my $flag = 'ac_mini';
    $doc->menu->add_block( $flag, 'bulleted', "Your $SiteDefs::ENSEMBL_SITETYPE", 'priority' => 0 );
    my @bookmark_sections = ();

    if ($user) {
      #$doc->menu->add_entry( $flag, 'text' => "<a href='/common/user/account'>Your account</a> &middot; <a href='javascript:logout_link()'>Log out</a>", 'raw' => 'yes');
      #$doc->menu->add_entry( $flag, 'text' => "Bookmark this page",
      #                              'code' => 'bookmark',
      #                            'href' => "javascript:bookmark_link()" );

      ## Link to existing bookmarks
      my %included;
      my @records = reverse sort {$a->click <=> $b->click} $user->bookmarks;
      my $found = 0;
      if ($#records > -1) { 
        $found = 1;
        my $max_bookmarks = 5;
        if ($#records < $max_bookmarks) {
          $max_bookmarks = $#records;
        }

        for my $n (0..$max_bookmarks) {
          push @bookmark_sections, &bookmark_menu_item($records[$n]);
          $included{$records[$n]->url} = "yes";
        }

      }

      foreach my $group ($user->groups) {
        $found = 1;
        my @bookmarks = $group->bookmarks;
        foreach my $bookmark (@bookmarks) {
          if (!$included{$bookmark->url}) {
            push @bookmark_sections, &bookmark_menu_item($bookmark);
          }
        }
      }


      if ($found) {
        push @bookmark_sections, { 'href' => 'javascript:bookmark_link()', 
                                   'text'  => 'Bookmark this page', extra_icon => '/img/bullet_toggle_plus.png' };

        push @bookmark_sections, { 'href' => '/common/user/account', 
                                   'text'  => 'More bookmarks...', extra_icon => '/img/bullet_go.png' };

      #  $doc->menu->add_entry(
      #    $flag,
      #      'href' => '/common/user/account',
      #      'text' => 'Bookmarks',
      #    'options'=> \@bookmark_sections );

      } else {
        #$doc->menu->add_entry( $flag, 'text' => "Add bookmark",
        #                              'href' => "javascript:bookmark_link()" );
      }

      $doc->menu->add_entry( $flag, 'text' => "<a href='#' onclick='toggle_settings_drawer();' id='settings_link'>Show account</a> &middot; <a href='#' onclick='logout_link()'>Log out</a>",
                                    'raw' => "yes" );

      $doc->menu->add_entry( $flag, 'text' => "Bookmark this page",
                                    'href' => "javascript:bookmark_link()" );
    
      #$doc->menu->add_entry( $flag, 'text' => "Your account",
      #                            'href' => "/common/user/account" );

    }
    else {
      $doc->menu->add_entry( $flag, 'text' => "<a href='javascript:login_link();'>Login</a> or <a href='/common/user/register'>Register</a>", 'raw' => 'yes');
      $doc->menu->add_entry( $flag, 'text' => "About User Accounts",
                                  'href' => "/info/about/accounts.html",
                                  'icon' => '/img/infoicon.gif' );
    }
    $doc->menu->add_entry( $flag, 'text' => "Display Your Data",
                                    'href' => "javascript:void(window.open('/common/user_data','user_data','width=640,height=480,resizable,scrollbars,toolbar'))" );
  }
}

sub bookmark_menu_item {
  my $bookmark = shift;
  my $url = $bookmark->url;
  $url =~ s/\?/\\\?/g;
  $url =~ s/&/!and!/g;
  $url =~ s/;/!with!/g;
  my $return = { href => $url,
                 text => $bookmark->name,
                 extra_icon => '/img/bullet_star.png' };
  return $return;
}

sub static_menu_items {
  my( $self, $doc ) = @_;
  $doc->menu->add_block( 'docs', 'nested', 'Help & Documentation', 'priority' => 20 );
  my $URI = $doc->{_renderer}->{r}->uri;

  my $tree = $doc->species_defs->ENSEMBL_WEB_TREE->{info};
  my @dirs  = grep { $_ !~ /(:?\.html|^_)/ } keys %$tree;

  foreach my $dir (@dirs) {
    my $node = $tree->{$dir};
    my $options = [];
    my $link = $node->{_path};
    my $text = $node->{_title};
    next unless $text;
    next if $link =~ /genomes/;
    next unless ($link);

    ## Second-level nav for current section
    if ($URI =~ m#^/info# && index($URI, $link) > -1) {
      my @subdirs = grep { $_ !~ /(:?\.html|^_)/ } keys %$node;
      my @pages = grep { /\.html/ } keys %$node;
      my ($url, $title);

      foreach my $subdir (@subdirs) {
        $url   = $node->{$subdir}->{_path};
        $title = $node->{$subdir}->{_title};
        push @$options, {'href'=>$url, 'text'=>$title} if $title;
      }
      foreach my $page (sort { $node->{$a} cmp $node->{$b} } @pages) {
        $url   = $node->{_path} . $page;
        $title = $node->{$page}->{_title};
        push @$options, {'href'=>$url, 'text'=>$title} if $title;
      }
    }
    $doc->menu->add_entry('docs', 'href'=> $link, 'text'=> $text, 'options' => $options );
  }
}

sub dynamic_menu_items {
  my( $self, $doc ) = @_;

  ## Is the user logged in?
  if ($ENV{'ENSEMBL_USER_ID'}) {
    my $flag = 'ac_mini';
      ## to do - add a check for configurability
      my $configurable = 1;
      if ($configurable) {
#        $doc->menu->add_entry_after( $flag, 'bookmark', 
#                                    'text' => "Save DAS sources...",
#                                  'href' => "javascript:das_link()" );
        $doc->menu->add_entry_after( $flag, 'bookmark', 
                                    'text' => "Save configuration as...",
                                  'href' => "javascript:add_config()" );
      }
  }
}

1;
