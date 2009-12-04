package EnsEMBL::Web::Apache::Handlers;

use strict;

use Exporter;

use Apache2::Const qw(:common :http :methods);
use Apache2::SizeLimit;
use Apache2::Connection ();
use Apache2::URI;
use APR::URI;
use CGI::Cookie;
use Data::Dumper;
use Fcntl ':flock';
use Sys::Hostname;
use Time::HiRes qw(time);
use URI::Escape;

use SiteDefs qw(:APACHE);

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::DBSQL::BlastAdaptor;
use EnsEMBL::Web::OldLinks qw(get_redirect);
use EnsEMBL::Web::Registry;
use EnsEMBL::Web::RegObj;
use Bio::EnsEMBL::Registry;

our $species_defs = new EnsEMBL::Web::SpeciesDefs;
our %species_lookup;
foreach ($species_defs->valid_species, qw(Multi multi das)) {
  $species_lookup{$_}++;
}

our $MEMD = new EnsEMBL::Web::Cache;
our $GEO;

if ($species_defs->ENSEMBL_MIRRORS) {
  eval q/
    use Geo::IP;
    $GEO = Geo::IP->new( GEOIP_MEMORY_CACHE | GEOIP_CHECK_CACHE );
  /;
  warn $@ if $@;
};

our $THIS_HOST;
our $LOG_INFO; 
our $LOG_TIME; 
our $BLAST_LAST_RUN;
our $BIOMART_REGISTRY;
our %LOOKUP_HASH;

our %OBJECT_TO_SCRIPT = qw(
  Config      config
  Component   component
  Zmenu       zmenu
  Blast       blast

  Gene        action
  Transcript  action
  Location    action
  Variation   action
  Regulation  action
  Server      action
  Info        action
  Search      action
  UniSearch   action
  Website     action
  Healthcheck action
  News        action
  
  Account     modal
  UserData    modal
  Help        modal
  Export      modal
);

#======================================================================#
# Set up apache-size-limit style load commands                         #
#======================================================================#

our $LOAD_COMMAND;
use Config;
BEGIN {
  $LOAD_COMMAND = $Config{'osname'} eq 'dec_osf' ? \&_load_command_alpha :
                  $Config{'osname'} eq 'linux'   ? \&_load_command_linux :
                                                   \&_load_command_null;
};

#======================================================================#
# Setting up the directory lists for Perl/webpage                      #
#======================================================================#
# %s will be replaced by species name                                  #
#======================================================================#
our @PERL_TRANS_DIRS;
our @HTDOCS_TRANS_DIRS;
our %SPECIES_MAP;
BEGIN {
  foreach my $dir (@SiteDefs::ENSEMBL_PERL_DIRS) {
    if (-d $dir) {
      if (-r $dir){
        push @PERL_TRANS_DIRS, "$dir/%s";
        push @PERL_TRANS_DIRS, "$dir/multi"   if -d "$dir/multi"   && -r "$dir/multi";
        push @PERL_TRANS_DIRS, "$dir/private" if -d "$dir/private" && -r "$dir/private";
        push @PERL_TRANS_DIRS, "$dir/default" if -d "$dir/default" && -r "$dir/default";
        push @PERL_TRANS_DIRS, "$dir/common"  if -d "$dir/common"  && -r "$dir/common";
      } else {
        warn "ENSEMBL_PERL_DIR $dir is not readable\n";
      }
    } else {
      # warn "ENSEMBL_PERL_DIR $dir does not exist\n";
    }
  }

  foreach my $dir (@SiteDefs::ENSEMBL_HTDOCS_DIRS) {
    if (-d $dir) {
      if (-r $dir) {
        push @HTDOCS_TRANS_DIRS, "$dir/%s";
      } else {
        warn "ENSEMBL_HTDOCS_DIR $dir is not readable\n";
      }
    } else {
      # warn "ENSEMBL_HTDOCS_DIR $dir does not exist\n";
    }
  }

  %SPECIES_MAP = (
    qw(
      common  common   Common  common
      Multi   Multi    multi   Multi
    ),
    ( 'perl' => $SiteDefs::ENSEMBL_PRIMARY_SPECIES ),
    map { lc($_) => $SiteDefs::ENSEMBL_SPECIES_ALIASES->{$_} } keys %{$SiteDefs::ENSEMBL_SPECIES_ALIASES}
  );

  $SPECIES_MAP{lc $_} = $_ for values %SPECIES_MAP; # Self-mapping
};

1;

#======================================================================#
# Perl apache handlers.... in order they get executed                  #
#======================================================================#

# Child Init Handler
# Sets up the web registry object - and initializes the timer
sub childInitHandler {
  my $r = shift;
  my $temp_hostname = hostname;
  my $temp_proc_id  = '' . reverse $$;
  my $temp_seed     = ($temp_proc_id + $temp_proc_id << 15) & 0xffffffff;
  
  while ($temp_hostname =~ s/(.{1,4})//) {
    $temp_seed = $temp_seed ^ unpack("%32L*", $1);
  }
  
  srand( time ^ $temp_seed );

  $THIS_HOST = `hostname`;

  # Create the Registry
  $ENSEMBL_WEB_REGISTRY = new EnsEMBL::Web::Registry;
  $ENSEMBL_WEB_REGISTRY->timer->set_process_child_count(0);
  $ENSEMBL_WEB_REGISTRY->timer->set_process_start_time(time);
  
  printf STDERR "Child %9d: - initialised at %30s\n", $$, '' . gmtime if $ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;
}

sub redirect_to_nearest_mirror {
  my $r = shift;

  if ($species_defs->ENSEMBL_MIRRORS) {
    my $unparsed_uri = $r->unparsed_uri();

    ## Check url
    if ($unparsed_uri =~ /redirect=mirror/) {
      ## Display the redirect message (but only if user comes from other mirror)
      if (my ($referer) = $unparsed_uri =~ /source=([\w\.-]+)/) {
       if (grep { $referer =~ /$_/ } values %{ $species_defs->ENSEMBL_MIRRORS }) {
        if ($referer ne $species_defs->ENSEMBL_SERVERNAME) {
            my $back = 'http://' . $referer . $unparsed_uri;
            $back =~ s/source=$referer//;

            my $user_message = qq| You've been redirected to your nearest mirror - | . $species_defs->ENSEMBL_SERVERNAME . "\n";
            $user_message   .= qq| <ul><li>Take me back to <a href="$back">$referer</a></li></ul> |;
            
            my $cookie = CGI::Cookie->new(
              -name    => 'user_message',
              -value   => uri_escape($user_message),
              -expires => '+1m',     
            );
            
            ## Redirecting to same page, but without redirect params in url
            $r->err_headers_out->add('Set-Cookie' => $cookie);
            $unparsed_uri =~ s/;?source=$referer//;
            $unparsed_uri =~ s/;?redirect=mirror//;
            $unparsed_uri =~ s/\?$//;
            $r->headers_out->set(Location => $species_defs->ENSEMBL_BASE_URL . $unparsed_uri);
            
            return Apache2::Const::REDIRECT;              
            
        }
       }
      }
      
      my $cookie = CGI::Cookie->new(
        -name    => 'redirect',
        -value   => 'mirror',
        -expires => 'Thu, 31-Dec-2037 22:22:22 GMT', ## End of time :)     
      );
      $r->err_headers_out->add('Set-Cookie' => $cookie);

      return DECLINED;
    }

    ## Check "don't redirect me" cookie
    my %cookies = CGI::Cookie->parse($r->headers_in->{'Cookie'});
    
    return DECLINED
      if $cookies{'redirect'} && $cookies{'redirect'}->value eq 'mirror';

    ## Ok, so which country you from
    if ($GEO) {
      
      my $ip = $r->headers_in->{'X-Forwarded-For'} || $r->connection->remote_ip;
      my $country  = $GEO->country_code_by_addr($ip);
  
      if (my $location = $species_defs->ENSEMBL_MIRRORS->{$country} || $species_defs->ENSEMBL_MIRRORS->{'MAIN'}) {
        return DECLINED
          if $location eq $species_defs->ENSEMBL_SERVERNAME;
  
        ## Deleting cookie for current site
        my $cookie = CGI::Cookie->new(
          -name    => 'redirect',
          -value   => '',
          -expires => '-1h',         
        );
  
        $unparsed_uri .= $unparsed_uri =~ /\?/ ? ';redirect=mirror' : '?redirect=mirror';
        $unparsed_uri .= ';source=' . $species_defs->ENSEMBL_SERVERNAME;
  
        $r->err_headers_out->add('Set-Cookie' => $cookie);
        $r->headers_out->set(Location => "http://$location$unparsed_uri");
        
        return Apache2::Const::REDIRECT;       
      }
      
    }
  }

  return DECLINED;
}

sub postReadRequestHandler {
  my $r = shift; # Get the connection handler

  # Nullify tags
  $ENV{'CACHE_TAGS'} = {};

  # Manipulate the Registry
  $ENSEMBL_WEB_REGISTRY->timer->new_child;
  $ENSEMBL_WEB_REGISTRY->timer->clear_times;
  $ENSEMBL_WEB_REGISTRY->timer_push('Handling script', undef, 'Apache');
  
  my $user_cookie = new EnsEMBL::Web::Cookie({
    host    => $ENSEMBL_COOKIEHOST,
    name    => $ENSEMBL_USER_COOKIE,
    value   => '',
    env     => 'ENSEMBL_USER_ID',
    hash    => {
      offset  => $ENSEMBL_ENCRYPT_0,
      key1    => $ENSEMBL_ENCRYPT_1,
      key2    => $ENSEMBL_ENCRYPT_2,
      key3    => $ENSEMBL_ENCRYPT_3,
      expiry  => $ENSEMBL_ENCRYPT_EXPIRY,
      refresh => $ENSEMBL_ENCRYPT_REFRESH
    }
  });
  
  # Initialize the user (and possibly group) objects
  # Unlikely to go to db - just store the IDs
  $ENSEMBL_WEB_REGISTRY->initialize_user({
    cookie => $user_cookie,
    r      => $r
  });
  
  ## Ajax cookie
  my %cookies = CGI::Cookie->parse($r->headers_in->{'Cookie'});
  $ENSEMBL_WEB_REGISTRY->check_ajax($cookies{'ENSEMBL_AJAX'});

  $r->subprocess_env->{'ENSEMBL_AJAX_VALUE'}  = $cookies{'ENSEMBL_AJAX'}  ? $cookies{'ENSEMBL_AJAX'}->value  : 'none';
  $r->subprocess_env->{'ENSEMBL_IMAGE_WIDTH'} = $cookies{'ENSEMBL_WIDTH'} ? $cookies{'ENSEMBL_WIDTH'}->value : ($SiteDefs::ENSEMBL_IMAGE_WIDTH || 800);
  
  $ENSEMBL_WEB_REGISTRY->timer_push('Post read request handler comoleted', undef, 'Apache');
  
  # Ensembl DEBUG cookie
  $r->headers_out->add('X-MACHINE' => $SiteDefs::ENSEMBL_SERVER) if $cookies{'ENSEMBL_DEBUG'};
  
  return;
}

sub headerParserHandler {
  my $r = shift;
}

sub transHandler_das {
  my ($r, $session_cookie, $path_segments, $querystring) = @_;
  my $DSN     = $path_segments->[0];
  my $command = '';

  # These are static content files due to the time to generate...
  # These files are created by utils/initialized_das.pl
#  warn "... ", $SiteDefs::ENSEMBL_SERVERROOT . "/htdocs/das/$DSN/entry_points";
  
   # Fall through - this is a static page
  if ($path_segments->[1] eq 'entry_points' && (-e $SiteDefs::ENSEMBL_SERVERROOT . "/htdocs/das/$DSN/entry_points") || $DSN =~  /^(sources|dsn)$/) {
    return undef;
  }

  # We have a DAS URL of the form...
  # /das/{species}.{assembly}.{feature_type}/command
  # 
  # feature_type consists of type and subtype separated by a -
  # e.g. gene-core-ensembl
  #
  # command is e.g. features, ...
  my @dsn_fields  = split /\./, $DSN;
  my $das_species = shift @dsn_fields;
  my $type        = pop @dsn_fields;
  my $assembly    = join '.', @dsn_fields;
  my $subtype;
  
  ($type, $subtype) = split /-/, $type, 2;
  $command = $path_segments->[1];
  
  my $FN = $SiteDefs::ENSEMBL_SERVERROOT . "/perl/das/$command";

  # Map the species to its real value
  $das_species = $SPECIES_MAP{lc($das_species)} || '';
 
# DAS sources based on ensembl gene ids are species-independent
# We will have a DAS URL of the form...
# /das/Multi.Ensembl-GeneID.{feature_type}/command  but you can still call
# /das/Homo_sapiens.Ensembl-GeneID.{feature_type}/command
# then the request will be restricted to Human db

  if ($assembly =~ /geneid/i) {
      if ($das_species =~ /multi/i) {
# this a site-wide request - try to figure out the species from the ID
	  $das_species = '';
	  if ($querystring =~ /segment=([^\;]+)(\;)?(.+)?$/) {
	      my $identifier = $1;
	      my $reg = "Bio::EnsEMBL::Registry";
	      my ( $s, $ot, $dbt ) = $reg->get_species_and_object_type($identifier);
	      $das_species = $s if ($s);
	  }
# in case no macth was found go to the default site species to report the page with no features
	  $das_species ||= $SiteDefs::ENSEMBL_PRIMARY_SPECIES;
      }
  }
  

  if (!$das_species) {
    $command = 'das_error';
    $r->subprocess_env->{'ENSEMBL_DAS_ERROR'} = 'unknown-species';
  }
  
  # Initialize session and set various environment variables...
  $ENSEMBL_WEB_REGISTRY->initialize_session({
    r       => $r, 
    cookie  => $session_cookie, 
    species => $das_species, 
    script  => $command
  });
  
  $r->subprocess_env->{'ENSEMBL_SPECIES'}      = $das_species;
  $r->subprocess_env->{'ENSEMBL_DAS_ASSEMBLY'} = $assembly;
  $r->subprocess_env->{'ENSEMBL_DAS_TYPE'}     = $type;
  $r->subprocess_env->{'ENSEMBL_TYPE'}         = 'DAS';
  $r->subprocess_env->{'ENSEMBL_DAS_SUBTYPE'}  = $subtype;
  $r->subprocess_env->{'ENSEMBL_SCRIPT'}       = $command;

  # Now look for the appropriate DAS script
  my $error_filename = '';
  
  foreach my $dir (@PERL_TRANS_DIRS) {
    my $filename          = sprintf($dir, 'das') . "/das/$command";
    my $t_error_filename  = sprintf($dir, 'das') . '/das/das_error';
    
    $error_filename ||= $t_error_filename if -r $t_error_filename;
    
    next unless -r $filename;
    
    $r->filename($filename);
    
    $r->uri("/perl/das/$DSN/$command");
    
    push_script_line('das', "$DSN/$command", $querystring) if $ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;
    
    $r->push_handlers(PerlCleanupHandler => \&cleanupHandler_script);
    $r->push_handlers(PerlCleanupHandler => \&Apache2::SizeLimit::handler);
    
    return OK;
  }

  # It's not there anymore
  # If not handle this as an "unknown command response".... if that script exists
  if (-r $error_filename) {
    $r->subprocess_env->{'ENSEMBL_DAS_ERROR'} = 'unknown-command';
    $r->filename($error_filename);
    $r->uri("/perl/das/$DSN/$command");
    
    push_script_line('das', "$DSN/$command", $querystring) if $ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;
    
    $r->push_handlers(PerlCleanupHandler => \&cleanupHandler_script);
    $r->push_handlers(PerlCleanupHandler => \&Apache2::SizeLimit::handler);
    
    return OK;
  }

  # Otherwise panic!
  return DECLINED;
}

sub push_endscr_line {
  push_script_line(@_, 'ENDSCR');
}

sub push_script_line {
  my $species = shift;
  my $command = shift;
  my $qs      = shift;
  my $prefix  = @_ ? shift : 'SCRIPT';
  my @X       = localtime;
  
  $LOG_INFO = sprintf(
    "%s:%8s:%-10d %04d-%02d-%02d %02d:%02d:%02d /%s/%s?%s\n",
    $prefix, substr($THIS_HOST, 0, 8), $$,
    $X[5]+1900, $X[4]+1, $X[3], $X[2],$X[1],$X[0],
    $species, $command, $qs
  );
  
  warn $LOG_INFO;
  
  $LOG_TIME = time;
}

sub transHandler_no_species {
  my ($r, $session_cookie, $species, $path_segments, $querystring) = @_;
  
  my $real_script_name = $OBJECT_TO_SCRIPT{$species};
  
  return undef if $real_script_name =~ /^(component|zmenu)$/;
  
  $r->subprocess_env->{'ENSEMBL_SPECIES'} = 'common';
  $r->subprocess_env->{'ENSEMBL_SCRIPT' } = $real_script_name;
  
  my $script     = $real_script_name;
  my $to_execute = $MEMD ? $MEMD->get("::SCRIPT::$script") : '';

  $ENSEMBL_WEB_REGISTRY->initialize_session({
    r       => $r,
    cookie  => $session_cookie,
    species => $species,
    script  => $script,
  });
 
  unless ($to_execute) {
    foreach my $dir(@PERL_TRANS_DIRS) {
      last unless $script;
      
      my $filename = sprintf($dir, 'common') . "/$script";
      
      next unless -r $filename;
      
      $to_execute = $filename;
    }
    
    $MEMD->set("::SCRIPT::$script", $to_execute, undef, 'SCRIPT') if $MEMD;
  }
  
  if ($to_execute) {
    $r->subprocess_env->{'ENSEMBL_TYPE'}     = my $t1 = $species;
    $r->subprocess_env->{'ENSEMBL_ACTION'}   = my $t2 = shift @$path_segments;
    $r->subprocess_env->{'ENSEMBL_FUNCTION'} = my $t3 = shift @$path_segments;
    
    my $path_info = join '/', @$path_segments;
    
    $r->filename($to_execute);
    $r->uri("/perl/common/$script");
    $r->subprocess_env->{'PATH_INFO'} = "/$path_info" if $path_info;
    
    push_script_line($species, "$t1/$t2/$t3", $querystring) if $ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;
    
    $r->push_handlers(PerlCleanupHandler => \&cleanupHandler_script); 
    $r->push_handlers(PerlCleanupHandler => \&Apache2::SizeLimit::handler);
    
    return OK;
  }
  
  return;
}

sub transHandler_species {
  my ($r, $session_cookie, $species, $raw_path_segments, $querystring, $file, $flag) = @_;

  my $redirect_if_different = 1;
  my @path_segments = map { s/\W//g; $_ } @$raw_path_segments; # clean up dodgy characters
  my $ajax      = '';
  my $plugin    = '';
  my $type      = '';
  my $action    = '';
  my $function  = '';

  # Parse the initial path segments, looking for valid ENSEMBL_TYPE values
  my $seg    = shift @path_segments;
  my $script = $OBJECT_TO_SCRIPT{$seg};
  
  if ($seg eq 'Component' || $seg eq 'Zmenu' || $seg eq 'Config') {
    $ajax   = $seg;
    $type   = shift @path_segments if $OBJECT_TO_SCRIPT{$path_segments[0]};
    $plugin = shift @path_segments if $ajax eq 'Component';
  } else {
    $type = $seg;
  }
  
  $action   = shift @path_segments;
  $function = shift @path_segments;

  $r->custom_response($_, "/$species/Info/Error/$_") for (NOT_FOUND, HTTP_BAD_REQUEST, FORBIDDEN, AUTH_REQUIRED);
    
  # Mess with the environment
  $r->subprocess_env->{'ENSEMBL_TYPE'}     = $type;
  $r->subprocess_env->{'ENSEMBL_ACTION'}   = $action;
  $r->subprocess_env->{'ENSEMBL_FUNCTION'} = $function;
  $r->subprocess_env->{'ENSEMBL_SPECIES'}  = $species;
  $r->subprocess_env->{'ENSEMBL_SCRIPT'}   = $script;

  if ($flag && $script) {
    if ($script eq 'action' || $script eq 'modal') {
      $r->subprocess_env->{'ENSEMBL_FACTORY'}   = 'MultipleLocation' if $type eq 'Location' && $action eq 'Multi';
    } elsif ($script eq 'component') {
      $r->subprocess_env->{'ENSEMBL_COMPONENT'} = join  '::', 'EnsEMBL', $plugin, 'Component', $type, $action;
      $r->subprocess_env->{'ENSEMBL_FACTORY'}   = 'MultipleLocation' if $type eq 'Location' && $action =~ /^Multi(Ideogram|Top|Bottom)$/;
      
      @path_segments = ();
    }
    
    $redirect_if_different  = 0;
  } else {
    $script = $seg;
  }
 
  my $path_info = join '/', @path_segments;
  
  $ENSEMBL_WEB_REGISTRY->initialize_session({
    r       => $r,
    cookie  => $session_cookie,
    species => $species,
    script  => $script,
    type    => $type,
    action  => $action,
  });

  # Search the mod-perl dirs for a script to run
  my $to_execute = $MEMD ? $MEMD->get("::SCRIPT::$script") : '';
  
  if (!$to_execute) {
    foreach my $dir (reverse @PERL_TRANS_DIRS){
      last unless $script;
      
      my $filename = sprintf($dir, $species) . "/$script";
      
      next unless -r $filename;
      
      $to_execute = $filename;
    }
    
    $MEMD->set("::SCRIPT::$script", $to_execute, undef, 'SCRIPT') if $MEMD;
  }

  if ($to_execute) {
    $r->filename($to_execute);
    $r->uri("/perl/$species/$script");
    $r->subprocess_env->{'PATH_INFO'} = "/$path_info" if $path_info;
    
    push_script_line($species, "$type/$action/$function", $querystring) if $ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;
    
    $r->push_handlers(PerlCleanupHandler => \&cleanupHandler_script);
    $r->push_handlers(PerlCleanupHandler => \&Apache2::SizeLimit::handler);
    
    return OK;
  }
  
  return;
}

sub cleanURI {
  my $r = shift;

  # Void call to populate ENV
  $r->subprocess_env;
  
  # Clean out the uri
  my $uri = $ENV{'REQUEST_URI'};
  
  if ($uri =~ s/time=\d+\.\d+;?//g + $uri =~ s!([^:])/{2,}!$1/!g) {
    $r->parse_uri($uri);
    $r->subprocess_env('REQUEST_URI' => $uri);
  }

  # Clean out the referrer
  my $referer = $ENV{'HTTP_REFERER'};
  
  if ($referer =~ s/time=\d+\.\d+;?//g + $referer =~ s!([^:])/{2,}!$1/!g) {
    $r->subprocess_env('HTTP_REFERER' => $referer);
  }

  return Apache2::Const::DECLINED;
}

sub transHandler {
  my $r = shift; # Get the connection handler
  
  $ENSEMBL_WEB_REGISTRY->timer->set_name('REQUEST ' . $r->uri);
  
  my $u           = $r->parsed_uri;
  my $file        = $u->path;
  my $querystring = $u->query;
  
  my $session_cookie = new EnsEMBL::Web::Cookie({
    host    => $ENSEMBL_COOKIEHOST,
    name    => $ENSEMBL_SESSION_COOKIE,
    value   => '',
    env     => 'ENSEMBL_SESSION_ID',
    hash    => {
      offset  => $ENSEMBL_ENCRYPT_0,
      key1    => $ENSEMBL_ENCRYPT_1,
      key2    => $ENSEMBL_ENCRYPT_2,
      key3    => $ENSEMBL_ENCRYPT_3,
      expiry  => $ENSEMBL_ENCRYPT_EXPIRY,
      refresh => $ENSEMBL_ENCRYPT_REFRESH
    }
  });

  my @raw_path = split m|/|, $file;
  shift @raw_path; # Always empty

  ## Identify the species element, if any
  my ($species, @path_segments);
 
  if (@raw_path == 1 && $raw_path[0] && $raw_path[0] !~ /\.\w{1,4}$/) {
    my $uri;
    ## Stable ID only, so rewrite URL
    my $stable_id = $raw_path[0];
    my ( $species, $object_type, $db_type ) =
                 Bio::EnsEMBL::Registry->get_species_and_object_type($stable_id);
    if ($species && $object_type) {
      $uri = '/'.$species.'/';
      if ($object_type eq 'Gene') {
        $uri .= 'Gene/Summary?g='.$stable_id;
      }
      elsif ($object_type eq 'Transcript') {
        $uri .= 'Transcript/Summary?t='.$stable_id;
      }
      elsif ($object_type eq 'Translation') {
        $uri .= 'Transcript/ProteinSummary?t='.$stable_id;
      }
      else {
        $uri .= 'psychic?q='.$stable_id;
      }
      $r->uri($uri);
      $r->headers_out->add('Location' => $r->uri);
      $r->child_terminate;
      $ENSEMBL_WEB_REGISTRY->timer_push('Transhandler "REDIRECT"', undef, 'Apache');
    
      return HTTP_MOVED_PERMANENTLY;
    }
  }

  foreach (@raw_path) {
    if ($species_lookup{$_}) {
      $species = $_;
    } else {
      push @path_segments, $_;
    }
  }

  @path_segments = @raw_path unless $species;
  
  # Some memcached tags (mainly for statistics)
  my $prefix = '';
  my @tags = map { $prefix = join '/', $prefix, $_; $prefix; } @path_segments;
  @tags = map {( "/$species$_", $_ )} @tags;
  push @tags, "/$species";
  
  $ENV{'CACHE_TAGS'}{$_} = 1 for @tags; # /memcached tags
    
  my $Tspecies  = $species;
  my $script    = undef;
  my $path_info = undef;
  my $species_name = $SPECIES_MAP{lc $species};
  
  $ENSEMBL_WEB_REGISTRY->set_species($species_name);

  if ($raw_path[0] eq 'das') {
    my $return = transHandler_das($r, $session_cookie, \@path_segments, $querystring);
    $ENSEMBL_WEB_REGISTRY->timer_push('Transhandler for DAS scripts finished', undef, 'Apache');
    
    return $return if defined $return;
  }
  
  if (!$species) { # Species-less script?
    my $return = transHandler_no_species($r, $session_cookie, $species, \@path_segments, $querystring);
    $ENSEMBL_WEB_REGISTRY->timer_push('Transhandler for non-species scripts finished', undef, 'Apache');
    
    return $return if defined $return;
  }
  
  if ($species && $species_name) { # species script
    my $return = transHandler_species(
      $r,
      $session_cookie,
      $species_name,
      \@path_segments,
      $querystring,
      $file,
      $species_name eq $species
    );
    
    $ENSEMBL_WEB_REGISTRY->timer_push('Transhandler for species scripts finished', undef, 'Apache');
    
    return $return if defined $return;
    
    shift @path_segments;
    shift @path_segments;
  }
  
  $species = $Tspecies;
  $script = join '/', @path_segments;

  # Permanent redirect for old species home pages:
  # e.g. /Homo_sapiens or Homo_sapiens/index.html -> /Homo_sapiens/Info/Index
  if ($species && $species_name && (!$script || $script eq 'index.html')) {
    $r->uri("/$species_name/Info/Index");
    $r->headers_out->add('Location' => $r->uri);
    $r->child_terminate;
    $ENSEMBL_WEB_REGISTRY->timer_push('Transhandler "REDIRECT"', undef, 'Apache');
    
    return HTTP_MOVED_PERMANENTLY;
  }

  # Search the htdocs dirs for a file to return
  return DECLINED if $species eq 'biomart' && $script =~ /^mart(service|results|view)/;

  my $path = join '/', $species || (), $script || (), $path_info || ();
  
  $r->uri("/$path");
  
  my $filename = $MEMD ? $MEMD->get("::STATIC::$path") : '';

  # Exclude static files (and no, html is not a static file in ensembl)
  if ($path !~ /\.(\w{2,3})$/) {
    if (!$filename) {
      foreach my $dir (@HTDOCS_TRANS_DIRS) {
        my $f = sprintf $dir, $path;
        
        if (-d $f) {
          $filename = '! '.$f;
          $MEMD->set("::STATIC::$path", $filename, undef, 'STATIC') if $MEMD;
          
          last;
        }
        
        if (-r $f) {
          $filename = $f;
          $MEMD->set("::STATIC::$path", $filename, undef, 'STATIC') if $MEMD;
          
          last;
        }
      }
    }
  }
  
  if ($filename =~ /^! (.*)$/) {
    $r->uri($r->uri . ($r->uri =~ /\/$/ ? '' : '/' ). 'index.html');
    $r->filename($1 . ($r->filename =~ /\/$/ ? '' : '/'). 'index.html');
    $r->headers_out->add('Location' => $r->uri);
    $r->child_terminate;
    $ENSEMBL_WEB_REGISTRY->timer_push('Transhandler "REDIRECT"', undef, 'Apache');
    
    return HTTP_TEMPORARY_REDIRECT;
  } elsif ($filename) {
    $r->filename($filename);
    $ENSEMBL_WEB_REGISTRY->timer_push('Transhandler "OK"', undef, 'Apache');
    
    return OK;
  }
  
  # Give up
  $ENSEMBL_WEB_REGISTRY->timer_push('Transhandler "DECLINED"', undef, 'Apache');
  return DECLINED;
}

sub logHandler {
  my $r = shift;
  my $T = time;
  
  $r->subprocess_env->{'ENSEMBL_CHILD_COUNT'}  = $ENSEMBL_WEB_REGISTRY->timer->get_process_child_count;
  $r->subprocess_env->{'ENSEMBL_SCRIPT_START'} = sprintf '%0.6f', $T;
  $r->subprocess_env->{'ENSEMBL_SCRIPT_END'}   = sprintf '%0.6f', $ENSEMBL_WEB_REGISTRY->timer->get_script_start_time;
  $r->subprocess_env->{'ENSEMBL_SCRIPT_TIME'}  = sprintf '%0.6f', $T - $ENSEMBL_WEB_REGISTRY->timer->get_script_start_time;
  
  return DECLINED;
}

sub cleanupHandler {
  my $r = shift;  # Get the connection handler
  
  return  if $r->subprocess_env->{'ENSEMBL_ENDTIME'};
  
  my $end_time    = time;
  my $start_time  = $ENSEMBL_WEB_REGISTRY->timer->get_script_start_time;
  my $length      = $end_time- $start_time;
  
  if ($length >= $ENSEMBL_LONGPROCESS_MINTIME) {
    my $u     = $r->parsed_uri;
    my $file  = $u->path;
    my $query = $u->query . $r->subprocess_env->{'ENSEMBL_REQUEST'};
    my $size  = &$Apache2::SizeLimit::HOW_BIG_IS_IT();
    
    $r->subprocess_env->{'ENSEMBL_ENDTIME'} = $end_time;
    
    if ($ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS) {
      print STDERR sprintf(
        "LONG PROCESS %10s DT: %24s Time: %10s Size: %10s\nLONG PROCESS %10s REQ: %s\nLONG PROCESS %10s IP:  %s  UA: %s\n", 
        $$,  scalar(gmtime($start_time)), $length, $size, 
        $$, "$file?$query", 
        $$, $r->subprocess_env->{'HTTP_X_FORWARDED_FOR'}, $r->headers_in->{'User-Agent'}
      );
    }
  }

  # Now we check if the die file has been touched...
  my $die_file = $ENSEMBL_SERVERROOT . '/logs/ensembl.die';
  
  if (-e $die_file) {
    my @temp = stat $die_file;
    my $file_mod_time = $temp[9];
    if ($file_mod_time >= $ENSEMBL_WEB_REGISTRY->timer->get_process_start_time) {
      print STDERR sprintf "KILLING CHILD %10s\n", $$;
      
      if ($Apache2::SizeLimit::WIN32) {
        CORE::exit(-2);
      } else {
        $r->child_terminate;
      }
    }
    
    return DECLINED;
  }
}

sub cleanupHandler_script {
  my $r = shift;
  my @X = localtime;
  
  $ENSEMBL_WEB_REGISTRY->timer_push('Cleaned up', undef, 'Cleanup');
  warn $ENSEMBL_WEB_REGISTRY->timer->render if $SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_PERL_PROFILER;

  my ($A, $B) = $LOG_INFO =~ /SCRIPT:(.{8}:\d+) +\d{4}-\d\d-\d\d \d\d:\d\d:\d\d (.*)$/;
  
  if ($SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS) {
    warn sprintf "ENDSCR:%-19s %04d-%02d-%02d %02d:%02d:%02d %10.3f %s\n", $A, $X[5]+1900, $X[4]+1, $X[3], $X[2],$X[1],$X[0], time-$LOG_TIME, $B;
  }
  
  cleanupHandler_blast($r) if $ENSEMBL_BLASTSCRIPT;
}

sub childExitHandler {
  my $r = shift;
  
  $ENSEMBL_WEB_REGISTRY->tidy_up if $ENSEMBL_WEB_REGISTRY; # Disconnect from the DB
  
  if ($ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS) {
    printf STDERR "Child %9d: - reaped at      %30s;  Time: %11.6f;  Req:  %4d;  Size: %8dK\n",
      $$, '' . gmtime, time-$ENSEMBL_WEB_REGISTRY->timer->get_process_start_time,
      $ENSEMBL_WEB_REGISTRY->timer->get_process_child_count,
      &$Apache2::SizeLimit::HOW_BIG_IS_IT()
  }
}

sub cleanupHandler_blast {
  my $r = shift;
  
  my $directory = $ENSEMBL_TMP_DIR_BLAST . '/pending';
  my $FLAG  = 0;
  my $count = 0;
  my $ticket;
  my $_process_blast_called_at = time;

  $ticket = $ENV{'ticket'};
  
  # Lets work out when to run this!
  my $run_blast;
  my $loads = _get_loads();
  my $seconds_since_last_run = (time - $BLAST_LAST_RUN);

  if ($ticket) {
    if (_run_blast_ticket($loads, $seconds_since_last_run)) {
      $FLAG = 1;
      $BLAST_LAST_RUN = time;
    }
  } else {
    # Current run blasts
    if (_run_blast_no_ticket($loads, $seconds_since_last_run)) {
      $BLAST_LAST_RUN = time;
      $FLAG = 1;
    }
  }
  
  while ($FLAG) {
    $count++;
    $FLAG = 0;
    
    if (opendir(DH, $directory)) {
      while (my $FN = readdir(DH)) {
        my $file = "$directory/$FN";
        
        next unless -f $file; # File
        next if -z $file;     # Contains something
        
        my @STAT = stat $file;
        
        next if $STAT[8]+5 > time; # Was last modified more than 5 seconds ago
        next if $ticket && $file !~ /$ticket/;
        
        # We have a ticket
        open  FH, $file;
        
        flock FH, LOCK_EX;
        my $blast_file = <FH>;
        chomp $blast_file;
        
        $blast_file = $1 if $blast_file =~ /^([\/\w\.-]+)/;
        
        (my $FILE2 = $file) =~ s/pending/parsing/;
        
        rename $file, $FILE2;
        
        (my $FILE3 = $file) =~ s/pending/sent/;
        
        unlink $FILE3;
        
        flock FH, LOCK_UN;
        
        my $COMMAND = "$ENSEMBL_BLASTSCRIPT $blast_file $FILE2";
        
        warn "BLAST: $COMMAND";
        
        `$COMMAND`; # NOW WE PARSE THE BLAST FILE.....
        
        if ($ticket && ($_process_blast_called_at + 30 > time)) {
          $loads = _get_loads();
          $FLAG = 1 if $count < 15;
        }
        
        last;
      }
      
      closedir(DH);
    }
  }
}

#======================================================================#
# BLAST Support functionality - TODO: update before implementing!      #
#======================================================================#

sub _run_blast_no_ticket {
  my ($loads, $seconds_since_last_run) = @_;
  return $loads->{'blast'} < 3 && rand $loads->{'httpd'} < 10 && rand $seconds_since_last_run > 1;
}

sub _run_blast_ticket {
  my ($loads, $seconds_since_last_run) = @_;
  return $loads->{'blast'} < 8;
}

sub  _load_command_null {
  return 1;
}

sub _load_command_alpha {
  my $command = shift;
  my $VAL = `ps -A | grep $command | wc -l`;
  
  return $VAL - 1;
}

sub _load_command_linux {
  my $command = shift;
  my $VAL = `ps --no-heading -C $command  | wc -l`;
  
  return $VAL + 0;
}

sub _get_loads {
  return {
    blast => &$LOAD_COMMAND('blast'),
    httpd => &$LOAD_COMMAND('httpd')
  };
}

sub queue_pending_blast_jobs {
  my $queue_class = 'EnsEMBL::Web::Queue::LSF';

  my $DB = {
    NAME => 'ensembl_blast',
    USER => 'ensadmin',
    PASS => 'ensembl',
    HOST => 'ensarc-1-08',
    PORT => '3306'
  }; 

  my $blast_adaptor = new EnsEMBL::Web::DBSQL::BlastAdaptor($DB);
  
  warn "Blast adaptor: $blast_adaptor";
  warn 'Species def databases: ' . $species_defs->databases->{'ENSEMBL_BLAST'};
  
  my $job_master = new EnsEMBL::Web::Object::BlastJobMaster($blast_adaptor, $queue_class);
  $job_master->queue_pending_jobs;
  $job_master->process_completed_jobs;
}

