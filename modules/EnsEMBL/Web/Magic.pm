package EnsEMBL::Web::Magic;

### EnsEMBL::Web::Magic is the new module which handles
### script requests, producing the appropriate WebPage objects,
### where required... There are four exported functions:
### magic - clean up and logging; stuff - rendering whole pages;
### carpet - simple redirect handler for old script names; and
### ingredient - to create partial pages for AJAX inclusions.

use strict;
use Apache2::RequestUtil;

use EnsEMBL::Web::Document::WebPage;
use EnsEMBL::Web::RegObj;
use CGI;

use base qw(Exporter);
our @EXPORT = our @EXPORT_OK = qw(magic stuff carpet ingredient Gene Transcript Location menu modal_stuff Variation Server configurator spell);

our $MEMD = EnsEMBL::Web::Cache->new(
  enable_compress    => 1,
  compress_threshold => 10_000,
);


### Three constants defined and exported to the parent scripts...
### To allow unquoted versions of Gene, Transcript and Location
### in the parent scripts.

sub Gene       { return 'Gene',       @_; }
sub Transcript { return 'Transcript', @_; }
sub Location   { return 'Location',   @_; }
sub Variation  { return 'Variation',  @_; }
sub Server     { return 'Server',     @_; }

sub timer_push { $ENSEMBL_WEB_REGISTRY->timer->push( @_ ); }

sub magic      {
### Usage: use EnsEMBL::Web::Magic; magic stuff
###
### Postfix for all the magic actions! doesn't really do much!
### Could potentially be used as a clean up script depending
### on what the previous scripts do!
###
### In this case we use it as a way to warn lines to the error log
### to show what the script has just done!
  my $t = shift;
  warn sprintf "MAGIC < %-60.60s > %s\n",$ENV{'REQUEST_URI'},$t if 
    $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_FLAGS &
    $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_MAGIC_MESSAGES;
}

sub carpet { 
### Usage: use EnsEMBL::Web::Magic; magic carpet Gene 'Summary'
### 
### Magically you away through the clouds away from the boring and
### mundane old existance of your 7 year old 'view' script to the
### wonderous realms of the magical new Ensembl 2.0 routing based
### 'action' script.
  my $URL         = sprintf '%s%s/%s/%s%s%s',
    '/', ## Fix this to include full path so as to replace URLs...
    $ENV{'ENSEMBL_SPECIES'},
    shift,  # object_type
    shift,  # action
    $ENV{'QUERY_STRING'}?'?':'',  $ENV{'QUERY_STRING'};
  CGI::redirect( -uri => $URL );
  return "Redirecting to $URL (taken away on the magic carpet!)";
}

sub menu {
### use EnsEMBL::Web::Magic; magic menu Gene; 
###
### Wrapper around a list of components to produce a zmenu
### for inclusion via AJAX
  my $webpage     = EnsEMBL::Web::Document::WebPage->new(
    'objecttype' => shift || $ENV{'ENSEMBL_TYPE'},
    'scriptname' => 'zmenu',
    'cache'      => $MEMD,
  );
  $webpage->configure( $webpage->dataObjects->[0], 'ajax_zmenu' );
  $webpage->render;
  return "Generated magic menu ($ENV{'ENSEMBL_ACTION'})";
}

sub configurator {
  my $objecttype  = shift || $ENV{'ENSEMBL_TYPE'};
  my $session_id  = $ENSEMBL_WEB_REGISTRY->get_session->get_session_id;

  warn "MY SESSION $session_id" if 
    $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_FLAGS &
    $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_MAGIC_MESSAGES;
    
  my $r = Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $session = $ENSEMBL_WEB_REGISTRY->get_session;

  my $input  = new CGI;
  $session->set_input( $input );
  my $ajax_flag = $r && (
    $r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest'||
    $input->param('x_requested_with') eq 'XMLHttpRequest'
  );

  my $webpage     = EnsEMBL::Web::Document::WebPage->new(
    'objecttype' => 'Server',
    'doctype'    => 'Configurator',
    'scriptname' => 'config',
    'r'          => $r,
    'ajax_flag'  => $ajax_flag,
    'cgi'        => $input,
#    'parent'     => $referer_hash,
    'renderer'   => 'String',
    'cache'      => $MEMD,
  );
  $webpage->page->{'_modal_dialog_'} = $ajax_flag;

  my $root = $session->get_species_defs->ENSEMBL_BASE_URL;
  if(
    $input->param('submit') ||
    $input->param('reset')
  ) {
    my $config = $input->param('config');
    my $vc = $session->getViewConfig( $ENV{'ENSEMBL_TYPE'}, $ENV{'ENSEMBL_ACTION'} );
    if($config && $vc->has_image_config($config) ) { ### We are updating an image config!
## We need to update the image config....
      ## If AJAX - return "SUCCESSFUL RESPONSE" -> Force reload page on close....
      my $ic = $session->getImageConfig( $config, $config );
      $vc->altered = $ic->update_from_input( $input );
      $session->store;
      if( $input->param('submit') ) {
        if( $ajax_flag ) { ## If AJAX - return "SUCCESSFUL RESPONSE" -> Force reload page on close....
## Note reset links drop back into the form....
        ## We need to
          CGI::header( 'text/plain' );
          print "SUCCESS";
          return "Updated configuration for ($ENV{'ENSEMBL_TYPE'}::$ENV{'ENSEMBL_ACTION'}::$config)";
        }
        if( $input->param('_') eq 'close' ) {
          if( $input->param('force_close') ) {
            CGI::header();
            print '<html>
<head>
  <title>Please close this window</title>
</head>
<body onload="window.close()">
  <p>Your configuration has been updated, please close this window and reload you main Ensembl view page</p> 
</body>
</html>';
            return "Updated configuration for ($ENV{'ENSEMBL_TYPE'}::$ENV{'ENSEMBL_ACTION'}::$config Redirect (closing form nasty hack)";
          } else {
            CGI::redirect( $root.$input->param('_referer') );
            return "Updated configuration for ($ENV{'ENSEMBL_TYPE'}::$ENV{'ENSEMBL_ACTION'}::$config Redirect (closing form)";
          }
        }
        CGI::redirect( $input->param('_') );
        return "Updated configuration for ($ENV{'ENSEMBL_TYPE'}::$ENV{'ENSEMBL_ACTION'}::$config Redirect (new form page)";
      }
      ## If not AJAX - refresh page!
      # redirect( to this page )
    } else { ### We are updating a view config!
      $vc->update_from_input( $input );
      if( $ENV{'ENSEMBL_ACTION'} ne 'ExternalData' ) {
        my $vc_2 = $session->getViewConfig( $ENV{'ENSEMBL_TYPE'}, 'ExternalData' );
        $vc_2->update_from_input( $input ) if $vc_2;
      }
      $session->store;
      my $cookie_host = $session->get_species_defs->ENSEMBL_COOKIEHOST;
      if( $input->param( 'cookie_width' ) && $input->param( 'cookie_width' ) != $ENV{'ENSEMBL_IMAGE_WIDTH'} ) { ## Set width!
        my $cookie = CGI::Cookie->new(
          -name    => 'ENSEMBL_WIDTH',
          -value   => $input->param( 'cookie_width' ),
          -domain  => $cookie_host,
          -path    => "/",
          -expires => $input->param( 'cookie_width' ) =~ /\d+/ ? "Monday, 31-Dec-2037 23:59:59 GMT" : "Monday, 31-Dec-1970 00:00:01 GMT"
        );
        $r->headers_out->add(  'Set-cookie' => $cookie );
        $r->err_headers_out->add( 'Set-cookie' => $cookie );
      }
      if( $input->param( 'cookie_ajax' ) && $input->param( 'cookie_ajax' ) ne $ENV{'ENSEMBL_AJAX_VALUE'} ) {  ## Set ajax cookie!
        my $cookie = CGI::Cookie->new(
          -name    => 'ENSEMBL_AJAX',
          -value   => $input->param( 'cookie_ajax' ),
          -domain  => $cookie_host,
          -path    => "/",
          -expires => "Monday, 31-Dec-2037 23:59:59 GMT"
        );
        $r->headers_out->add(  'Set-cookie' => $cookie );
        $r->err_headers_out->add( 'Set-cookie' => $cookie );
      }
      if( $input->param('submit') ) { ## If AJAX - return "SUCCESSFUL RESPONSE" -> Force reload page on close....
        if( $ajax_flag ) { ## If AJAX - return "SUCCESSFUL RESPONSE" -> Force reload page on close....
          ## We need to 
          CGI::header( 'text/plain' );
  	  print "SUCCESS";
          return "Updated configuration for ($ENV{'ENSEMBL_TYPE'}::$ENV{'ENSEMBL_ACTION'} AJAX";
        }
        if( $input->param('_') eq 'close' ) {
          if( $input->param('force_close') ) {
            CGI::header();
            print '<html>
<head>
  <title>Please close this window</title>
</head>
<body onload="window.close()">
  <p>Your configuration has been updated, please close this window and reload you main Ensembl view page</p> 
</body>
</html>';
            return "Updated configuration for ($ENV{'ENSEMBL_TYPE'}::$ENV{'ENSEMBL_ACTION'} Redirect (closing form nasty hack)";
          } else {
            CGI::redirect( $root.$input->param('_referer') );
            return "Updated configuration for ($ENV{'ENSEMBL_TYPE'}::$ENV{'ENSEMBL_ACTION'} Redirect (closing form)";
          }
        }
        CGI::redirect( $input->param('_') );
        return "Updated configuration for ($ENV{'ENSEMBL_TYPE'}::$ENV{'ENSEMBL_ACTION'} Redirect (new form page)";
      }
    }
  }
  $webpage->configure( $webpage->dataObjects->[0], qw(user_context configurator) );
    ## Now we need to setup the content of the page -- need to set-up 
    ##  1) Global context entries
    ##  2) Local context entries   [ hacked versions with # links / and flags ]
    ##  3) Content of panel (expansion of tree)
  $webpage->render;
  my $content = $webpage->page->renderer->content;
  print $content;
  return "Generated configuration panel ($ENV{'ENSEMBL_TYPE'}::$ENV{'ENSEMBL_ACTION'})";
}

sub ingredient {
### use EnsEMBL::Web::Magic; magic ingredient Gene 'EnsEMBL::Web::Component::Gene::geneview_image'
###
### Wrapper around a list of components to produce a panel or
### part thereof - for inclusion via AJAX
  my $objecttype  = shift || $ENV{'ENSEMBL_TYPE'};
  my $r = Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;

  my $session_id   = $ENSEMBL_WEB_REGISTRY->get_session->get_session_id;
  $ENV{CACHE_KEY}  = $ENV{REQUEST_URI};
  $ENV{CACHE_TAGS} ||= {};
  $ENV{CACHE_TAGS}->{$ENV{'HTTP_REFERER'}} = 1;

  ## Ajax request
  $ENV{CACHE_KEY} .= "::SESSION[$session_id]" if $session_id;
  $ENV{CACHE_KEY} .= "::WIDTH[$ENV{ENSEMBL_IMAGE_WIDTH}]" if $ENV{'ENSEMBL_IMAGE_WIDTH'};
  
  my $content = $MEMD ? $MEMD->get($ENV{CACHE_KEY}) : undef;

  timer_push( 'Retrieved content from cache' ); 	 
  $ENSEMBL_WEB_REGISTRY->timer->set_name( "COMPONENT $ENV{'ENSEMBL_SPECIES'} $ENV{'ENSEMBL_COMPONENT'}" );

  if ($content) {
    warn "AJAX CONTENT CACHE HIT $ENV{CACHE_KEY}"
      if $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_FLAGS &
         $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_MEMCACHED;
    $r->content_type('text/html');
  } else {
    warn "AJAX CONTENT CACHE MISS $ENV{CACHE_KEY}"
      if $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_FLAGS &
         $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_MEMCACHED;

    my $webpage     = EnsEMBL::Web::Document::WebPage->new(
      'objecttype' => $objecttype,
      'doctype'    => 'Component',
      'ajax_flag'  => 1,
      'scriptname' => 'component',
      'r'          => $r,
      'outputtype' => $objecttype eq 'DAS' ? 'DAS': undef,
      'renderer'   => 'String',
      'cache'      => $MEMD,
    );
    $ENV{'ENSEMBL_ACTION'} = $webpage->{'parent'}->{'ENSEMBL_ACTION'};

    $webpage->factory->action( $webpage->{'parent'}->{'ENSEMBL_ACTION'} );
    if( $webpage->dataObjects->[0] ) {
      $webpage->dataObjects->[0]->action(  $webpage->{'parent'}->{'ENSEMBL_ACTION'} );
      if ($objecttype eq 'DAS') {
	  $webpage->configure( $webpage->dataObjects->[0], $ENV{ENSEMBL_SCRIPT} );
      } else {
	  $webpage->configure( $webpage->dataObjects->[0], 'ajax_content' );
      }
      $webpage->render;
      $content = $webpage->page->renderer->content;
    } else {
      $content = '<p>Unable to produce objects - panic!</p>';
    }
    $MEMD->set(
      $ENV{CACHE_KEY},
      $content,
      60*60*24*7,
      ( 'AJAX', keys %{ $ENV{CACHE_TAGS}||{} } ) ## TAGS
    ) if $MEMD && $webpage->format eq 'HTML';
    timer_push( 'Rendered content cached' );
  }

  print $content;
  timer_push( 'Rendered content printed' );
  return "Generated magic ingredient ($ENV{'ENSEMBL_COMPONENT'})";
}

sub mushroom {
### use EnsEMBL::Web::Magic; magic mushroom
###
### AJAX Wrapper around pfetch to access the Mole/Mushroom requests for description

}

sub stuff {
### Usage use EnsEMBL::Web::Magic; magic stuff
###
### The stuff that dreams are made of - instead of using separate
### scripts for each view we now use a 'routing' approach which
### transmogrifies the URL and separates it into 'species', 'type' 
### and 'action' - giving nice, clean, systematic URLs for handling
### heirarchical object navigation
  my $object_type  = shift || $ENV{'ENSEMBL_TYPE'};
  my $action       = shift;
  my $command      = shift;
  my $doctype      = shift;
  my $modal_dialog = shift;
  my $session      = $ENSEMBL_WEB_REGISTRY->get_session;

  my $r = Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  $ENV{CACHE_KEY} = $ENV{REQUEST_URI};
  ## If user logged in, some content depends on user
  $ENV{CACHE_KEY} .= "::USER[$ENV{ENSEMBL_USER_ID}]" if $ENV{ENSEMBL_USER_ID};


  my $input = new CGI;
  my $url = undef;
  $session->set_input( $input );
  if (my @share_ref = $input->param('share_ref')) {
    $session->receive_shared_data(@share_ref);
    $input->delete('share_ref');
    $url = $input->self_url;
  }
  my $vc = $session->getViewConfig( $ENV{'ENSEMBL_TYPE'}, $ENV{'ENSEMBL_ACTION'} );
  my $url2 = $vc->update_from_config_strings( $session, $r );
  $url = $url2 if $url2;
  if( $url ) {
    CGI::redirect( $url );
    return 'Jumping back in without parameter!';
  }

  my $session_id  = $session->get_session_id;
  $ENV{CACHE_KEY} .= "::SESSION[$session_id]" if $session_id;

  if (
      $MEMD && 
      ($r->headers_in->{'Cache-Control'} eq 'max-age=0' || $r->headers_in->{'Pragma'} eq 'no-cache')
     ) {
      $MEMD->delete_by_tags(
        $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_BASE_URL.$ENV{'REQUEST_URI'},
        $session_id ? "session_id[$session_id]" : (),
      );
  }

  my $content = $MEMD ? $MEMD->get($ENV{CACHE_KEY}) : undef;

  if ($content) {
    warn "DYNAMIC CONTENT CACHE HIT $ENV{CACHE_KEY}"
      if $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_FLAGS &
         $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_MEMCACHED;
    
    $r->content_type('text/html');
  } else {
    warn "DYNAMIC CONTENT CACHE MISS $ENV{CACHE_KEY}"
      if $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_FLAGS &
         $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_MEMCACHED;    

    my $webpage = EnsEMBL::Web::Document::WebPage->new( 
      'objecttype' => $object_type, 
      'doctype'    => $doctype,
      'scriptname' => 'action',
      'renderer'   => 'String',
      'command'    => $command, 
      'cache'      => $MEMD,
      'cgi'        => $input,
    );
    if( $modal_dialog ) {
      $webpage->page->{'_modal_dialog_'} = $webpage->page->renderer->{'r'}->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest' ||
                                           $webpage->factory->param('x_requested_with') eq 'XMLHttpRequest';
    }
    # The whole problem handling code possibly needs re-factoring 
    # Especially the stuff that may end up cyclic! (History/UnMapped)
    # where ID's don't exist but we have a "gene" based display
    # for them.
    if( $webpage->has_a_problem ) {
      if( $webpage->has_problem_type( 'redirect' ) ) {
        my($p) = $webpage->factory->get_problem_type('redirect');
        my $u = $p->name;
        if( $r->headers_in->{'X-Requested-With'} ) {
          $u.= ($p->name=~/\?/?';':'?').'x_requested_with='.CGI::escape($r->headers_in->{'X-Requested-With'});
        }
        $webpage->redirect( $p->name );
        return;
      } elsif( $webpage->has_problem_type('mapped_id') ) {
        my $feature = $webpage->factory->__data->{'objects'}[0];
        my $URL = sprintf "/%s/%s/%s?%s",
          $webpage->factory->species, $ENV{'ENSEMBL_TYPE'},$ENV{'ENSEMBL_ACTION'},
          join(';',map {"$_=$feature->{$_}"} keys %$feature );
        $webpage->redirect( $URL );
        return "Redirecting to $URL (mapped object)";
      } elsif ($webpage->has_problem_type('unmapped')) {
        my $f     = $webpage->factory;
        my $id  = $f->param('peptide') || $f->param('transcript') || $f->param('gene');
        my $type = $f->param('gene')    ? 'Gene' 
                 : $f->param('peptide') ? 'ProteinAlignFeature'
             :                        'DnaAlignFeature'
             ;
        my $URL = sprintf "/%s/$object_type/Karyotype?type=%s;id=%s",
          $webpage->factory->species, $type, $id;
  
        $webpage->redirect( $URL );
        return "Redirecting to $URL (unmapped object)";
      } elsif ($webpage->has_problem_type('archived') ) {
        my $f     = $webpage->factory;
        my( $type, $param, $id ) = $f->param('peptide')    ? ( 'Transcript', 'peptide',    $f->param('peptide' )   )
                                 : $f->param('transcript') ? ( 'Transcript', 'transcript', $f->param('transcript') )
                     :                           ( 'Gene',       'gene',       $f->param('gene')       )
                     ;
        my $URL = sprintf "/%s/%s/History?%s=%s", $webpage->factory->species, $type, $param, $id;
        $webpage->redirect( $URL );
        return "Redirecting to $URL (archived object)";
      } else {
        $webpage->configure( $ENV{ENSEMBL_TYPE}, 'local_context' );
        $webpage->render_error_page;
        #return "Rendering Error page";
      }
    } else {
  # This still works... (beth you may have to change the four parts that are configured - note these
  # have changed from the old WebPage::simple_wrapper...
      foreach my $object( @{$webpage->dataObjects} ) {
        my @sections;
        if ($doctype && $doctype eq 'Popup') {
          @sections = qw(global_context local_context content_panel local_tools);
        } else {
          @sections = qw(global_context local_context context_panel content_panel local_tools);
        }
        $webpage->configure( $object, @sections );
      }
      if( $webpage->dataObjects->[0] && $webpage->dataObjects->[0]->has_problem_type( 'redirect' ) ) {
        my($p) = $webpage->dataObjects->[0]->get_problem_type('redirect');
        my $u = $p->name;
        if( $r->headers_in->{'X-Requested-With'} ) {
          $u.= ($u=~/\?/?';':'?').'x_requested_with='.CGI::escape($r->headers_in->{'X-Requested-With'});
        }
        $webpage->redirect( $u );
      } else {
        $webpage->factory->fix_session; ## Will have to look at the way script configs are stored now there is only one script!!
        $webpage->render;
        warn $webpage->timer->render if
          $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_FLAGS &
          $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_PERL_PROFILER;
        #return "Completing action";
      }
    }

    $content = $webpage->page->renderer->content;

    my @tags = (
      $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_BASE_URL . $ENV{'REQUEST_URI'},
      'DYNAMIC'
    );
    push @tags, keys %{ $ENV{CACHE_TAGS} } if $ENV{CACHE_TAGS};
    $MEMD->set($ENV{CACHE_KEY}, $content, 60*60*24*7, @tags)
      if $MEMD &&
         !$webpage->has_a_problem &&
         $webpage->format eq 'HTML';
  }
  
  print $content;
  return "Completing action";
}

sub modal_stuff {
  return stuff( @_, 1 );
}

# Exports data. Function name by order of js5
sub spell {
  my $objecttype = shift || $ENV{'ENSEMBL_TYPE'};
  my $session_id = $ENSEMBL_WEB_REGISTRY->get_session->get_session_id;

  warn "MY SESSION $session_id" if 
    $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_FLAGS &
    $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEBUG_MAGIC_MESSAGES;
    
  my $r = Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $session = $ENSEMBL_WEB_REGISTRY->get_session;

  my $input = new CGI;
  $session->set_input($input);
  
  my $ajax_flag = $r && (
    $r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest' ||
    $input->param('x_requested_with') eq 'XMLHttpRequest'
  );
  
  if ($input->param('save')) {
    my $conf = $session->getViewConfig($ENV{'ENSEMBL_TYPE'}, 'Export');
    $conf->update_from_input($input);
    $session->store;
  }

  my $webpage = EnsEMBL::Web::Document::WebPage->new(
    'objecttype' => $ENV{'ENSEMBL_TYPE'},
    'scriptname' => 'export',
    'r'          => $r,
    'ajax_flag'  => $ajax_flag,
    'cgi'        => $input,
    'renderer'   => 'String',
    'cache'      => $MEMD,
  );
  
  $webpage->page->{'_modal_dialog_'} = $ajax_flag;
  
  $webpage->configure($webpage->dataObjects->[0], qw(export_configurator));
  
  # Now we need to setup the content of the page -- need to set-up 
  # 1) Global context entries
  # 2) Local context entries [ hacked versions with # links / and flags ]
  # 3) Content of panel (expansion of tree)
  $webpage->render;
  
  my $content = $webpage->page->renderer->content;
  
  print $content;
  
  return "Generated export panel ($ENV{'ENSEMBL_TYPE'}::$ENV{'ENSEMBL_ACTION'})";
}

1;
