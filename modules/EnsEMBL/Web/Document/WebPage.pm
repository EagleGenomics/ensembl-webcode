package EnsEMBL::Web::Document::WebPage;

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::Timer;
use Exporter;
use Apache2::Const qw(:common M_GET);
use EnsEMBL::Web::Tools::Encryption;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::OrderedTree;
use EnsEMBL::Web::CoreObjects;
use EnsEMBL::Web::DBSQL::DBConnection;

use CGI qw(header escapeHTML unescape);
use CGI::Cookie;
use SiteDefs;
use strict;

use constant 'DEFAULT_RENDERER'   => 'Apache';
use constant 'DEFAULT_OUTPUTTYPE' => 'HTML';
use constant 'DEFAULT_DOCUMENT'   => 'Dynamic';

use Bio::EnsEMBL::Registry; # Required so we can do the disconnect all call!!
our @ISA = qw(EnsEMBL::Web::Root Exporter);
our @EXPORT_OK = qw(redirect simple_self simple_with_redirect wrapper_self);
our @EXPORT    = @EXPORT_OK;

sub _prof { my $self = shift; $self->timer->push( @_ ); }
sub timer { return $_[0]{'timer'}; }

sub new {
### Object Instantiation
### Arg[1]: hash of parameters, keys include;
###  scriptname : name of the calling script (def $ENV{'ENSEMBL_SCRIPT'})
###  cgi        : CGI object (def CGI->new) 
###  command    : Access restriction param
###  renderer   : E::W::Document::Renderer::<module> to use (def Apache)
###  doctype    : E::W::Document::<doctype> to use (def Dynamic)
###  outputtype : The output type, e.g. XML, DAS (def HTML). the doctype
###               module needs an _initialise_<outputtype> method.
###  outputtype_version : e.g. XML/HTML version for page headers, passed to 
###               _initialise_<outputtype>, often refers to a DTD.
###  objecttype : E::W::Object::<objecttype>
###  fast       : Hint to the object factory to use fastCreateObjects method.
### Certain CGI object pamams can also affect object instantiation;
###  _format    : see <outputtype>
###  _format_version : see <outputtype_version>

  my $class = shift;
  my $self = {
    'page'         => undef,
    'factory'      => undef,
    'command'      => undef,
    'configurable' => undef,
    'cache'        => undef,
    'r'            => undef,
    'timer'        => $ENSEMBL_WEB_REGISTRY->timer,
    'species_defs' => $ENSEMBL_WEB_REGISTRY->species_defs
  };
  bless $self, $class;
  my %parameters = @_;
  $| = 1;

  $self->{'cache'} = $parameters{'cache'};
  $self->{'r'}     = $parameters{'r'};
  $self->{'parent'}     = $parameters{'parent'};
  
## Input module...
  $self->{'script'} = $parameters{'scriptname'} || $ENV{'ENSEMBL_SCRIPT'};
  my $input;
  if ($parameters{'cgi'}) {
    $input = $parameters{'cgi'};
  }  
  elsif ($parameters{'command'}) {
    $input = $parameters{'command'}->action->get_cgi;
  }
  else {
    $input  = new CGI;
  }
  # $ENSEMBL_WEB_REGISTRY->get_session->set_input( $input );
  $self->_prof("Parameters initialised from input");

## Page module...

## Compile and create renderer ... [ Apache, File, ... ]
  my $renderer_type = $parameters{'renderer'} || DEFAULT_RENDERER;
  my $render_module = "EnsEMBL::Web::Document::Renderer::$parameters{'renderer'}";
  unless( $self->dynamic_use( $render_module ) ) { ## If fails to compile try default rendered
    $render_module = "EnsEMBL::Web::Document::Renderer::".DEFAULT_RENDERER;
    $self->dynamic_use( $render_module ); 
  }

  my $rend = new $render_module(
    r     => $self->{'r'},
    cache => $self->{'cache'},
  );
  $self->_prof("Renderer compiled and initialized");

## Compile and create "Document" object ... [ Dynamic, Popup, ... ]
  $self->{doctype} = $parameters{'doctype'} || DEFAULT_DOCUMENT;
  my $doc_module = "EnsEMBL::Web::Document::".$self->{doctype};

  unless( $self->dynamic_use( $doc_module ) ) {
    $doc_module = "EnsEMBL::Web::Document::".DEFAULT_DOCUMENT;
    $self->dynamic_use( $doc_module ); 
  }
  $self->page = new $doc_module( $rend, $self->{'timer'}, $self->{'species_defs'}, $input );          
  $self->_prof("Page object compiled and initialized");

## Initialize output type! [ HTML, XML, Excel, Txt ]
  $self->{'format'} = $input->param('_format') 
      || $parameters{'outputtype'} 
      || DEFAULT_OUTPUTTYPE;
  my $method = "_initialize_".($self->{'format'});
  $self->{'format_version'} = $input->param('_format_version')
      || $parameters{'outputtype_version'}
      || undef();

  $self->page->$method($self->{'format_version'});
  $self->_prof("Output method initialized" );

## Finally we get to the Factory module!
  my $db_connection;
  if ($ENV{'ENSEMBL_SPECIES'} ne 'common') {
    $db_connection = EnsEMBL::Web::DBSQL::DBConnection->new(
      $ENV{'ENSEMBL_SPECIES'},
      $ENSEMBL_WEB_REGISTRY->species_defs
    );
  }
  my $core_objects = EnsEMBL::Web::CoreObjects->new( $input, $db_connection );
  $self->factory = EnsEMBL::Web::Proxy::Factory->new(
    $parameters{'objecttype'}, {
      '_input'         => $input,
      '_apache_handle' => $rend->r,
      '_core_objects'  => $core_objects,
      '_databases'     => $db_connection
    }
  );
    $self->factory->__data->{'timer'} = $self->{'timer'};
    $self->_prof("Factory compiled and objects created...");
  return $self if $self->factory->has_fatal_problem();
  eval {
    if( $parameters{'fast'} ) {
#warn "FAST CREATE OBJECTS...";
      $self->factory->fastCreateObjects();
    } else {
      $self->factory->createObjects();
    }
  };
  if( $@ ) {
    $self->problem( 'fatal', "Unable to execute createObject on Factory of type $parameters{'objecttype'}.", $@ );
                                                                     $self->_prof("Object creation failed");
  } else {
                                                                     $self->_prof("Objects created");
    my $sc = $self->factory->get_scriptconfig( );
#       $sc->update_from_input( $input, $rend->{'r'} ) if $sc;        $self->_prof("Script config updated from input");
  }
  return $self;
}

sub configure {
  my( $self, $object, @functions ) = @_;
  my $objecttype;
  if (ref($object)) { ## Actual object
    $objecttype = $object->__objecttype;
  }
  elsif ($object =~ /^\w+$/) { ## String (type of E::W object)
    $objecttype = $object;
  }
  else {
    $objecttype = 'Static';
  }
  $objecttype = 'DAS' if ($objecttype =~ /^DAS::.+/);

  my $flag = 0;
  my @T = ('EnsEMBL::Web', '', @{$ENSEMBL_PLUGINS});

  my $FUNCTIONS_CALLED = {};
  my $common_conf = {
    'tree'           => EnsEMBL::Web::OrderedTree->new(),
    'default'        => undef,
    'action'         => undef,
    'configurable'   => 0,
  };
  my @modules = ();
  while( my ($module_root, $X) = splice( @T, 0, 2) ) {
# Starting with the standard EnsEMBL module configure the script....
# Then loop through the plugins in order after that...
# First work out what the module name is - to see if it can be "used"
    $flag ++;
    my $config_module_name = $module_root."::Configuration::$objecttype";

    if( $self->dynamic_use( $config_module_name ) ) { ## Successfully used
      # If it has been successfully used then look for
      # the functions named in the script "configure" line
      # of the script.
      my $CONF = $config_module_name->new( $self->page, $object, $flag, $common_conf );
      push @modules, [$CONF,$config_module_name];
      ## Attach any control modules to the configuration
      $CONF->{wizard}  = $self->{wizard};
      $CONF->{doctype} = $self->{doctype};
    } elsif( $self->dynamic_use_failure( $config_module_name ) !~ /^Can't locate/ ) {
# Handle "use" failures gracefully...
# Firstly skip Can't locate errors o/w display a "compile time" error message.
      $self->page->content->add_panel(
        new EnsEMBL::Web::Document::Panel(
         'caption' => 'Configuration module compilation error',
         'content' => sprintf( qq(
    <p>
      Unable to use Configuration module <b>$config_module_name</b> due to
      the following error:
    </p>
    <pre>%s</pre>), $self->_format_error( $self->dynamic_use_failure( $config_module_name )) )
        )
      );
    }
  }
## Tree is now built... so we need to set the action...

  $modules[0][0]->set_action( $ENV{'ENSEMBL_ACTION'} );

  foreach my $T ( @modules ) {
    my( $CONF,$config_module_name ) = @$T;
## Loop through the functions to configure
    foreach my $FN ( @functions ) { 
      if( $CONF->can($FN) ) {
# If this configuration module can perform this function do so...
        eval { $CONF->$FN(); };
        if( $@ ) { # Catch any errors and display as a "configuration runtime error"
          $self->page->content->add_panel( 
            new EnsEMBL::Web::Document::Panel(
              'caption' => 'Configuration module runtime error',
              'content' => sprintf( qq(
    <p>
      Unable to execute configuration $FN from configuration module <b>$config_module_name</b>
      due to the following error:
    </p>
    <pre>%s</pre>), $self->_format_error($@) )
            )
          );
        } else {
          $FUNCTIONS_CALLED->{$FN} = 1;
          ## Check if we've added any configurable components
          my $node = $CONF->get_node($CONF->_get_valid_action( $ENV{'ENSEMBL_ACTION'} ));
          my @components = @{$node->data->{'components'}};
          while( my($code, $module) = splice( @components, 0, 2) ) {
            if ($self->dynamic_use($module)) {
              my $component = $module->new;
              if ($component->configurable) {
                $CONF->{'_data'}{'configurable'} = 1;
                last;
              }
            }
          }
        } 
      }
    }
  }

  foreach my $FN ( @functions ) {
    unless( $FUNCTIONS_CALLED->{$FN} ) {
      if( $objecttype eq 'DAS' ) {
        $self->problem('Fatal', 'Bad request', 'Unimplemented');
      } else {
        warn "Can't do configuration function $FN on $objecttype objects, or an error occurred when executing that function.";
      }
    }
  }


  $self->add_error_panels(); # Add error panels to end of display!!
  $self->_prof("Script configured ($objecttype)");
}   

sub static_links {
  my $self = shift;
#  $self->configure( undef, 'links' );
#  $self->_prof("Static links added");
}

sub factory   :lvalue { $_[0]->{'factory'}; }
sub page      :lvalue { $_[0]->{'page'};    }

## Wrapper functions around factory and page....
sub has_fatal_problem { my $self = shift; return $self->factory->has_fatal_problem;       }
sub has_a_problem     { my $self = shift; return $self->factory->has_a_problem(@_);       }
sub has_problem_type  { my $self = shift; return $self->factory->has_problem_type( @_ );  }
sub problem           { my $self = shift; return $self->factory->problem(@_);             }
sub dataObjects       { my $self = shift; return $self->factory->DataObjects;             }

sub restrict  { 
  my $self = shift;
  $self->{'restrict'} = shift if @_;
  return $self->{'restrict'}; ## returns string   
}
sub groups  { 
  my $self = shift;
  $self->{'groups'} = shift if @_;
  return $self->{'groups'} || []; ## returns array ref    
}

sub get_user_id {
  my $self = shift;
  ## do we have one in the current session?
  my $user_id = $ENV{'ENSEMBL_USER_ID'};

  return $user_id;
}


sub redirect {
  my( $self, $URL ) = @_;
  CGI::redirect( $URL );
  alarm(0);
}

sub render {
  my $self = shift;
  if( $self->{'format'} eq 'Text' ) { 
    CGI::header("text/plain"); $self->page->render_Text;
  } elsif( $self->{'format'} eq 'DAS' ) { 
    $self->page->{'subtype'} = $self->{'subtype'};
    CGI::header("text/xml"); $self->page->render_DAS;
  } elsif( $self->{'format'} eq 'XML' ) { 
    CGI::header("text/xml"); $self->page->render_XML;
  } elsif( $self->{'format'} eq 'Excel' ) { 
    CGI::header( -type => "application/x-msexcel", -attachment => "ensembl.xls" );
warn "Now we render Excel....";
    $self->page->render_Excel;
  } elsif( $self->{'format'} eq 'TextGz' ) { 
    CGI::header( -type => "application/octet-stream", -attachment => "ensembl.txt.gz" );
    $self->page->render_TextGz;
  } else {
    CGI::header; $self->static_links; $self->page->render;
  }
}

sub render_popup {
  my $self = shift;
  if( $self->{'format'} eq 'Text' ) { 
    CGI::header("text/plain");
    $self->page->render_Text;
  } else { 
    CGI::header;
    $self->page->render;
  }
}

sub render_error_page { 
  my $self = shift;
  $self->add_error_panels( @_ );
  $self->render();
}

sub add_error_panels {
  my( $self, @problems ) = @_;
  @problems = @{$self->problem} if !@problems && $self->factory;

  if (@problems) {
      $self->{'format'} = 'HTML';
      $self->page->set_doc_type('HTML', '4.01 Trans');
  }

  foreach my $problem ( sort { $b->isFatal <=> $a->isFatal } @problems ) {
    next if !$problem->isFatal && $self->{'show_fatal_only'};
    my $desc = $problem->description;
    #warn "PROBLEM: $desc"; ## Just in case other bugs prevent error page rendering!
    $desc = "<p>$desc</p>" unless $desc =~ /<p/;
    # Find an example for the page
    my @eg;
    my $view = uc ($ENV{'ENSEMBL_SCRIPT'});
    my $ini_examples = $self->{'species_defs'}->SEARCH_LINKS;

    foreach ( map { $_ =~/^$view(\d)_TEXT/ ? [$1, $_] : () } keys %$ini_examples ) {
      my $url = $ini_examples->{$view."$_->[0]_URL"};
      push @eg, qq( <a href="$url">).$ini_examples->{$_->[1]}."</a>";
    }

    my $eg_html = join ", ", @eg;
    $eg_html = "<p>Try an example: $eg_html or use the search box.</p>" if $eg_html;

    $self->page->content->add_panel(
      new EnsEMBL::Web::Document::Panel(
        'caption' => $problem->name,
        'content' => qq(
  $desc
  $eg_html
  <p>
    If you think this is an error, or you have any questions, please <a href="/Help/Contact" class="modal_link">contact our HelpDesk team</a>.
  </p>) 
      )
    );
    $self->factory->clear_problems();
  }
}

sub DESTROY {
  Bio::EnsEMBL::Registry->disconnect_all();
}

1;
