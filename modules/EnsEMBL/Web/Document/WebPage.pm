package EnsEMBL::Web::Document::WebPage;

use strict;

use Apache2::Const qw(:common M_GET);
use Exporter;
use CGI qw(header escapeHTML unescape);
use CGI::Cookie;

use SiteDefs;

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::CoreObjects;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::OrderedTree;
use EnsEMBL::Web::Timer;
use EnsEMBL::Web::Tools::Encryption;

use constant 'DEFAULT_RENDERER'   => 'Apache';
use constant 'DEFAULT_OUTPUTTYPE' => 'HTML';
use constant 'DEFAULT_DOCUMENT'   => 'Dynamic';

our @ISA = qw(EnsEMBL::Web::Root Exporter);
our @EXPORT_OK = qw(redirect simple_self simple_with_redirect wrapper_self);
our @EXPORT    = @EXPORT_OK;

sub factory   :lvalue { $_[0]->{'factory'}; }
sub page      :lvalue { $_[0]->{'page'};    }
sub command   :lvalue { $_[0]->{'command'}; }

sub timer_push   { my $self = shift; $self->timer->push( @_ ); }
sub timer        { return $_[0]{'timer'}; }
sub format       { return $_[0]->{'format'}; }
sub species_defs { return $ENSEMBL_WEB_REGISTRY->species_defs; }

# Wrapper functions around factory and page
sub has_fatal_problem { my $self = shift; return $self->factory->has_fatal_problem;       }
sub has_a_problem     { my $self = shift; return $self->factory->has_a_problem(@_);       }
sub has_problem_type  { my $self = shift; return $self->factory->has_problem_type( @_ );  }
sub problem           { my $self = shift; return $self->factory->problem(@_);             }
sub dataObjects       { my $self = shift; return $self->factory->DataObjects;             }

# Object Instantiation
# Arg[1]: hash of parameters, keys include;
#  scriptname : name of the calling script (def $ENV{'ENSEMBL_SCRIPT'})
#  cgi        : CGI object (def CGI->new) 
#  renderer   : E::W::Document::Renderer::<module> to use (def Apache)
#  doctype    : E::W::Document::<doctype> to use (def Dynamic)
#  outputtype : The output type, e.g. XML, DAS (def HTML). the doctype
#               module needs an _initialise_<outputtype> method.
#  outputtype_version : e.g. XML/HTML version for page headers, passed to 
#               _initialise_<outputtype>, often refers to a DTD.
#  objecttype : E::W::Object::<objecttype>
#  fast       : Hint to the object factory to use fastCreateObjects method.
# Certain CGI object pamams can also affect object instantiation;
#  _format    : see <outputtype>
#  _format_version : see <outputtype_version>
sub new {
  my $class = shift;
  
  my $self = {
    page         => undef,
    factory      => undef,
    command      => undef,
    filters      => undef,
    configurable => undef,
    cache        => undef,
    r            => undef,
    timer        => $ENSEMBL_WEB_REGISTRY->timer,
    species_defs => $ENSEMBL_WEB_REGISTRY->species_defs
  };
  
  bless $self, $class;
  
  my %parameters = @_;
  my $input = $parameters{'cgi'} || new CGI;
  
  $| = 1;
  
  $self->{'cache'}  = $parameters{'cache'};
  $self->{'r'}      = $parameters{'r'};  
  $self->{'script'} = $parameters{'scriptname'} || $ENV{'ENSEMBL_SCRIPT'}; # Input module
  $self->{'parent'} = $self->_parse_referer($input->param('_referer') || $ENV{'HTTP_REFERER'});
  
  $ENSEMBL_WEB_REGISTRY->get_session->set_input($input);
  $self->timer_push('Parameters initialised from input');

  # Page module. Compile and create renderer [ Apache, File, ... ]
  my $renderer_type = $parameters{'renderer'} || DEFAULT_RENDERER;
  my $render_module = "EnsEMBL::Web::Document::Renderer::$parameters{'renderer'}";
  
  # If fails to compile try default rendered
  unless ($self->dynamic_use($render_module)) {
    $render_module = 'EnsEMBL::Web::Document::Renderer::' . DEFAULT_RENDERER;
    $self->dynamic_use($render_module); 
  }
  
  $self->timer_push('Renderer object compiled');

  my $rend = new $render_module(
    r     => $self->{'r'},
    cache => $self->{'cache'},
  );
  
  $self->timer_push('Renderer initialized');

  # Compile and create "Document" object [ Dynamic, Popup, ... ]
  $self->{'doctype'} = $parameters{'doctype'} || DEFAULT_DOCUMENT;
  
  my $doc_module = "EnsEMBL::Web::Document::$self->{'doctype'}";

  unless ($self->dynamic_use($doc_module)) {
    $doc_module = 'EnsEMBL::Web::Document::' . DEFAULT_DOCUMENT;
    $self->dynamic_use($doc_module); 
  }
  
  $self->timer_push('Page object compiled');
  $self->page = new $doc_module($rend, $self->{'timer'}, $self->{'species_defs'}, $input);          
  $self->timer_push('Page object initialized');

  # Initialize output type [ HTML, XML, Excel, Txt ]
  $self->{'format'} = $input->param('_format') || $parameters{'outputtype'} || DEFAULT_OUTPUTTYPE;
  
  my $method = '_initialize_' . ($self->{'format'});
  $self->{'format_version'} = $input->param('_format_version') || $parameters{'outputtype_version'} || undef;
  $self->page->$method($self->{'format_version'});
  $self->timer_push('Output method initialized');
  
  my $db_connection = new EnsEMBL::Web::DBSQL::DBConnection($ENV{'ENSEMBL_SPECIES'}, $ENSEMBL_WEB_REGISTRY->species_defs) if $ENV{'ENSEMBL_SPECIES'} ne 'common';
  $self->timer_push('DB connection created');
  
  my $core_objects = new EnsEMBL::Web::CoreObjects($input, $db_connection, undef);
  $self->timer_push('Core objects created');
  
  $self->factory = new EnsEMBL::Web::Proxy::Factory($parameters{'factorytype'} || $parameters{'objecttype'}, {
    _input         => $input,
    _apache_handle => $rend->r,
    _core_objects  => $core_objects,
    _databases     => $db_connection,
    _parent        => $self->{'parent'}
  });
  
  $self->factory->__data->{'timer'} = $self->{'timer'};
  $self->timer_push('Factory compiled and objects created');
  
  return $self if $self->factory->has_fatal_problem;
  
  eval {
    if ($parameters{'fast'}) {
      $self->factory->fastCreateObjects;
    } else {
      $self->factory->createObjects;
    }
  };
  
  if ($@) {
    $self->problem('fatal', "Unable to execute createObject on Factory of type $parameters{'objecttype'}.", $@);
    $self->timer_push('Object creation failed');
  } else {
    $self->timer_push('Objects created');
    $self->timer_push('Script config updated from input');
  }
  
  return $self;
}

sub configure {
  my ($self, $object, @functions) = @_;
  
  $object->get_viewconfig->form($object) if ref $object;
  
  my $objecttype;
  
  if (ref $object) { # Actual object
    $objecttype = $object->__objecttype;
  } elsif ($object =~ /^\w+$/) { # String (type of E::W object)
    $objecttype = $object;
  } else {
    $objecttype = 'Static';
  }
  
  $objecttype = 'DAS' if $objecttype =~ /^DAS::.+/;

  my $flag = 0;
  my @T = ('EnsEMBL::Web', '', @$ENSEMBL_PLUGINS);
  my @modules;
  my $FUNCTIONS_CALLED = {};
  my $common_conf = {
    'tree'           => EnsEMBL::Web::OrderedTree->new,
    'default'        => undef,
    'action'         => undef,
    'configurable'   => 0,
  };


  # Starting with the standard EnsEMBL module configure the script
  # Then loop through the plugins in order after that
  # First work out what the module name is - to see if it can be "used"  
  while (my ($module_root, $X) = splice @T, 0, 2) {
    $flag++;
    
    my $config_module_name = $module_root . "::Configuration::$objecttype";
    
    if ($self->dynamic_use($config_module_name)) { # Successfully used
      # If it has been successfully used then look for the functions named in the script "configure" line of the script.
      my $CONF = $config_module_name->new($self->page, $object, $flag, $common_conf);
      
      push @modules, [ $CONF, $config_module_name ];
      $CONF->{'doctype'} = $self->{'doctype'};
    } elsif ($self->dynamic_use_failure($config_module_name) !~ /^Can't locate/) {
      # Handle "use" failures gracefully
      # Firstly skip Can't locate errors o/w display a "compile time" error message.
      $self->page->content->add_panel(
        new EnsEMBL::Web::Document::Panel(
         'caption' => 'Configuration module compilation error',
         'content' => sprintf("
            <p>
              Unable to use Configuration module <strong>$config_module_name</strong> 
              due to the following error:
            </p>
            <pre>%s</pre>", 
            $self->_format_error($self->dynamic_use_failure($config_module_name))
          )
        )
      );
    }
  }
  
  $self->timer_push('configuration modules compiled');
  
  # Tree is now built, so we need to set the action
  $modules[0][0]->set_action($ENV{'ENSEMBL_ACTION'}, $ENV{'ENSEMBL_FUNCTION'});

  foreach my $T (@modules) {
    my ($CONF, $config_module_name) = @$T;
    
    # Loop through the functions to configure
    foreach my $FN (@functions) {
      # If this configuration module can perform this function do so
      if ($CONF->can($FN)) {
        eval { $CONF->$FN(); };
        
        # Catch any errors and display as a "configuration runtime error"
        if ($@) {
          $self->page->content->add_panel( 
            new EnsEMBL::Web::Document::Panel(
              'caption' => 'Configuration module runtime error',
              'content' => sprintf("
                <p>
                  Unable to execute configuration $FN from configuration module <strong>$config_module_name</strong>
                  due to the following error:
                </p>
                <pre>%s</pre>", 
                $self->_format_error($@)
              )
            )
          );
        } else {
          $FUNCTIONS_CALLED->{$FN} = 1;
          
          # Check if we've added any configurable components or if this is a command node
          my $node = $CONF->get_node($CONF->_get_valid_action($ENV{'ENSEMBL_ACTION'}, $ENV{'ENSEMBL_FUNCTION'}));
          
	        if ($node) {
            my @components = @{$node->data->{'components'}||[]};
            
            while (my($code, $module) = splice @components, 0, 2) {
              $module =~ s/\/\w+$//;
              
              if ($self->dynamic_use($module)) {
                my $component = $module->new;
                
                if ($component->configurable) {
                  $CONF->{'_data'}{'configurable'} = 1;
                  last;
                }
              }
            }
            
            $self->{'command'} = $node->data->{'command'};
            $self->{'filters'} = $node->data->{'filters'};
	        }
        }
        
        $self->timer_push("configuration function $FN called for @$T", 2);
      }
    }
    
    $self->timer_push("configuration functions called for @$T", 1);
  }
  
  $self->timer_push('configuration functions called');
  
  foreach my $FN (@functions) {
    unless($FUNCTIONS_CALLED->{$FN}) {
      if($objecttype eq 'DAS') {
        $self->problem('Fatal', 'Bad request', 'Unimplemented');
      } else {
        warn "Can't do configuration function $FN on $objecttype objects, or an error occurred when executing that function.";
      }
    }
  }

  $self->add_error_panels; # Add error panels to end of display
  $self->timer_push("Script configured ($objecttype)");
}   

# Is this in use?
sub restrict  { 
  my $self = shift;
  $self->{'restrict'} = shift if @_;
  return $self->{'restrict'}; # returns string   
}
sub groups  { 
  my $self = shift;
  $self->{'groups'} = shift if @_;
  return $self->{'groups'} || []; # returns array ref    
}

sub get_user_id {
  return $ENV{'ENSEMBL_USER_ID'};
}


sub redirect {
  my ($self, $url) = @_;
  
  CGI::redirect($url);
  alarm(0);
}

sub render {
  my $self = shift;
  
  if ($self->format eq 'Text') { 
    CGI::header('text/plain'); 
    $self->page->render_Text;
  } elsif ($self->format eq 'DAS') { 
    $self->page->{'subtype'} = $self->{'subtype'};
    CGI::header('text/xml');
    $self->page->render_DAS;
  } elsif ($self->format eq 'XML') { 
    CGI::header('text/xml');
    $self->page->render_XML;
  } elsif ($self->format eq 'Excel') { 
    CGI::header( -type => 'application/x-msexcel', -attachment => 'ensembl.xls' );
    $self->page->render_Excel;
  } elsif ($self->format eq 'TextGz') { 
    CGI::header( -type => 'application/octet-stream', -attachment => 'ensembl.txt.gz' );
    $self->page->render_TextGz;
  } else {
    CGI::header( -type => 'text/html', -charset => 'utf-8' );
    $self->timer_push('Static links generated');
    $self->page->render;
  }
}

sub render_popup {
  my $self = shift;
  
  if ($self->format eq 'Text') { 
    CGI::header('text/plain');
    $self->page->render_Text;
  } else { 
    CGI::header;
    $self->page->render;
  }
}

sub render_error_page { 
  my $self = shift;
  
  $self->add_error_panels(@_);
  $self->render;
}

sub add_error_panels {
  my ($self, @problems) = @_;
  @problems = @{$self->problem} if !@problems && $self->factory;

  if (@problems) {
    $self->{'format'} = 'HTML';
    $self->page->set_doc_type('HTML', '4.01 Trans');
  }

  foreach my $problem (sort { $b->isFatal <=> $a->isFatal } @problems) {
    next if $problem->isRedirect;
    next if !$problem->isFatal && $self->{'show_fatal_only'};
    
    my $desc = $problem->description;
    
    $desc = "<p>$desc</p>" unless $desc =~ /<p/;
    
    my @eg; # Find an example for the page
    my $view = uc $ENV{'ENSEMBL_SCRIPT'};
    my $ini_examples = $self->{'species_defs'}->SEARCH_LINKS;

    foreach (map { $_ =~/^$view(\d)_TEXT/ ? [$1, $_] : () } keys %$ini_examples) {
      my $url = $ini_examples->{"$view$_->[0]_URL"};
      
      push @eg, qq{ <a href="$url">$ini_examples->{$_->[1]}</a>};
    }

    my $eg_html = join ', ', @eg;
    $eg_html = '<p>Try an example: $eg_html or use the search box.</p>' if $eg_html;

    $self->page->content->add_panel(
      new EnsEMBL::Web::Document::Panel(
        caption => $problem->name,
        content => qq{
          $desc
          $eg_html
          <p>If you think this is an error, or you have any questions, please <a href="/Help/Contact" class="modal_link">contact our HelpDesk team</a></p>
        }
      )
    );
    
    $self->factory->clear_problems;
  }
}

sub DESTROY { Bio::EnsEMBL::Registry->disconnect_all; }

1;
