=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 NAME

Bio::Tools::Run::Search::blat_gfclient - Search runnable for BLAT gfClient

=head1 SYNOPSIS

  # Do not use this object directly - it is used as part of the
  # Bio::Tools::Run::Search system.
  use Bio::Tools::Run::Search;
  my $runnable = Bio::Tools::Run::Search(-method=>'blat_gfclient');
  $runnable->database( $database ); #DB string, eg localhost:60001:/nibdir
  $runnable->seq( $seq );           #Bio::SeqI object for query
  $runnable->run; # Launch the query

  my $result = $runnable->next_result; #Bio::Search::Result::* object

=head1 DESCRIPTION

This object extends Bio::Tools::Run::Search (sequence database
searching framework) to encompass BLAT's gfClient executable. Read
the L<Bio::Tools::Run::Search> docs for more information about how to
use this.

=cut

# Let the code begin...
package Bio::Tools::Run::Search::blat_gfclient;

use strict;
use Data::Dumper;
use vars qw( @ISA 
	     $ALGORITHM $VERSION $SEARCHIO_FORMAT $PROGRAM_NAME);

use Bio::Tools::Run::Search;
use IO::Socket;

@ISA = qw( Bio::Tools::Run::Search );

BEGIN{
  $SEARCHIO_FORMAT   = 'blast';
  $ALGORITHM  = 'BLAT';
  $VERSION    = 'Unknown';
  $PROGRAM_NAME  = 'gfClient';
}

#----------------------------------------------------------------------
sub program_name{ 
  my $self = shift;
  my $pname = $self->SUPER::program_name(@_);
  return defined( $pname ) ?  $pname : $PROGRAM_NAME;
}
sub algorithm   { return $ALGORITHM }
sub format      { return $SEARCHIO_FORMAT }
sub parameter_options { return {} }

#----------------------------------------------------------------------

=head2 _initialise_search

  Arg [1]   : 
  Function  : Bypass Apache/HTTP environment vars that may affect blat
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _initialise_search {
  my $self = shift;
  $self->environment_variable('CONTENT_TYPE',undef);
  $self->environment_variable('CONTENT_LENGTH',undef);
  $self->environment_variable('QUERY_STRING',undef);
  $self->environment_variable('HTTP_COOKIE',undef);
  return $self->SUPER::_initialise_search(@_);
}

#----------------------------------------------------------------------

=head2 command

  Arg [1]   : None
  Function  : generates the shell command to run
              the blat query
  Returntype: String: $command
  Exceptions:
  Caller    :
  Example   :

=cut

sub command{
  my $self = shift;

  if( ! -f $self->fastafile ){ $self->throw("Need a query sequence!") }

#  my $exe = $self->executable;
  my $exe = '/localsw/bin/gfClient';
  -e $exe || $self->throw( "$exe does not exist" );
  -X $exe || $self->throw( "$exe is not executable bu UID/GID" );

  my( $host, $port, $nib_dir ) = $self->_get_server();

  my $command = join( ' ',
		      $exe,
		      "-out=wublast -minScore=0 -minIdentity=0",
		      $host,
		      $port,
		      $nib_dir,
		      $self->fastafile,
		      $self->reportfile, 
		    );

  my @Q        = gmtime();
  my $log_file = sprintf '/ensemblweb/www/server/seq-logs/%04d-%02d-%02d.log', $Q[5]+1900, $Q[4]+1, $Q[3];
open O, ">>$log_file";
printf O qq(
=== %-64.64s ===
Method:   BLAT
Host:     %s
Port:     %s
Nib dir:  %s
Datetime: %s
IP:       %s
Command:  %s
Fasta:    %s
========================================================================
), "COMMAND BLAT ".$self->fastafile, $host, $port, $nib_dir, "".gmtime, $ENV{'REMOTE_ADDR'}.', '.$ENV{'HTTP_X_FORWARDED_FOR'}, $command,  $self->fastafile;
close O;

  warn "$command 2> ".$self->errorfile;
  return $command." 2>".$self->errorfile;

}

#----------------------------------------------------------------------
=head2 _get_server

  Arg [1]   : None
  Function  : Internal method to convert the database string into a 
              BLAT host and port. Database string must be in format of:
              host:port:nib_dir
  Returntype: array - $host, $port, $nib_dir
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _get_server{
  my $self = shift;
  
  my $database = $self->database;

  my ($host, $port, $nib_dir) = split( ':', $database, 3 ); 
  $port ||  
    $self->throw("Bad format for blat search DB: ".$database.
		 ". Use host:port:nib_path" );

  $nib_dir ||= '/';

  # Test to see whether the server is responding
  my $status = 1;
  my $error  = '';
  for( my $i=0; $i<5; $i++ ){ # Allow up to 5 attempts to contact the server
    eval{
      my $socket = IO::Socket::INET->new( PeerAddr => $host,
					  PeerPort => $port,
					  Timeout  => 1     ) 
	or die( "$@ $host:$port" );
    };
    if( $@ ){ $status = 0; alarm(0); $error=$@; $self->debug($@) }
    else{     $status = 1; last; }
  }
  if( ! $status ){
    $self->throw( "BLAT server unavailable: $error" )
  }

  # Check for nib dir
  -e $nib_dir || $self->throw( "Nib dir $nib_dir does not exists" );
  -d $nib_dir || $self->throw( "Nib dir $nib_dir is not a directory" );
  
  return( $host, $port, $nib_dir );
}

#----------------------------------------------------------------------

1;

