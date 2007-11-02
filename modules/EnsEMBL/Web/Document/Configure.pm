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
    my $user_id = $ENV{'ENSEMBL_USER_ID'};

    my $user_adaptor = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor;

    my $flag = 'ac_mini';
    $doc->menu->add_block( $flag, 'bulleted', "Your $SiteDefs::ENSEMBL_SITETYPE", 'priority' => 0 );
    my @bookmark_sections = ();

    if ($user_id) {
      #$doc->menu->add_entry( $flag, 'text' => "<a href='/common/accountview'>Your account</a> &middot; <a href='javascript:logout_link()'>Log out</a>", 'raw' => 'yes');
      #$doc->menu->add_entry( $flag, 'text' => "Bookmark this page",
      #                              'code' => 'bookmark',
      #                            'href' => "javascript:bookmark_link()" );

      my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;

      ## Link to existing bookmarks
      my %included = ();
      my @records = $user->bookmark_records({order_by => 'click' });
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

      foreach my $group (@{ $user->groups }) {
        $found = 1;
        my @bookmarks = $group->bookmark_records;   
        foreach my $bookmark (@bookmarks) {
          if (!$included{$bookmark->url}) {
            push @bookmark_sections, &bookmark_menu_item($bookmark);
          }
        }
      }


      if ($found) {
        push @bookmark_sections, { 'href' => 'javascript:bookmark_link()', 
                                   'text'  => 'Bookmark this page', extra_icon => '/img/bullet_toggle_plus.png' };

        push @bookmark_sections, { 'href' => '/common/accountview', 
                                   'text'  => 'More bookmarks...', extra_icon => '/img/bullet_go.png' };

      #  $doc->menu->add_entry(
      #    $flag,
      #      'href' => '/common/accountview',
      #      'text' => 'Bookmarks',
      #    'options'=> \@bookmark_sections );

      } else {
        #$doc->menu->add_entry( $flag, 'text' => "Add bookmark",
        #                              'href' => "javascript:bookmark_link()" );
      }

      $doc->menu->add_entry( $flag, 'text' => "<a href='javascript:void(0);' onclick='javascript:toggle_settings_drawer();' id='settings_link'>Show account</a> &middot; <a href='javascript:void(0);' onclick='logout_link()'>Log out</a>",
                                    'raw' => "yes" );

      $doc->menu->add_entry( $flag, 'text' => "Bookmark this page",
                                    'href' => "javascript:bookmark_link()" );
    
      #$doc->menu->add_entry( $flag, 'text' => "Your account",
      #                            'href' => "/common/accountview" );

    }
    else {
      $doc->menu->add_entry( $flag, 'text' => "<a href='javascript:login_link();'>Login</a> or <a href='/common/user/register'>Register</a>", 'raw' => 'yes');
      $doc->menu->add_entry( $flag, 'text' => "About User Accounts",
                                  'href' => "/info/about/accounts.html",
                                  'icon' => '/img/infoicon.gif' );
    }
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
=pod
  $doc->menu->add_block( 'docs', 'nested', 'Help & Documentation', 'priority' => 20 );
  my $URI = $doc->{_renderer}->{r}->uri;

  my $tree = $doc->species_defs->ENSEMBL_INFO;
  my ($info_dir, $info_title, @subdirs) = @$tree;
  foreach my $dir (@subdirs) {
    my $options = [];
    my @elements = @$dir;
    next if ref($elements[0]) eq 'HASH';
    my $link = shift @elements;
    my $text = shift @elements;
    next unless ($link);
    if ($URI =~ m#^/info# && index($URI, $link) > -1) {
      my %links;
      foreach my $subelement (@elements) {
        if (ref($subelement) eq 'ARRAY') {
          $links{$subelement->[1]} = $subelement->[0];
        }
        elsif (ref($subelement) eq 'HASH') {
          while (my ($k, $v) = each (%$subelement)) {
          $links{$k} = $v;
          }
        }
      }
      my @page_order = sort keys %links;
      foreach my $page ( @page_order ) {
        push @$options, {'href'=>$links{$page}, 'text'=>$page} if $page;
      }
    }
    $doc->menu->add_entry('docs', 'href'=> $link, 'text'=> $text, 'options' => $options );
  }
=cut
}

sub dynamic_menu_items {
  my( $self, $doc ) = @_;

  ## Is the user logged in?
  my $user_id = $ENV{'ENSEMBL_USER_ID'};

  if ($user_id) {
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
