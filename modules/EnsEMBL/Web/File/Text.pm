package EnsEMBL::Web::File::Text;

use strict;
use Digest::MD5 qw(md5_hex);
use EnsEMBL::Web::Root;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;

our $TMP_IMG_FORMAT     = 'XXX/X/X/XXXXXXXXXXXXXXX';
our @ISA =qw(EnsEMBL::Web::Root);

#  ->cache   = G/S 0/1
#  ->ticket  = G/S ticketname (o/w uses random date stamp)

sub new {
  my $class = shift;
  my $self = {
    'cache'     => 0,
    'species_defs' => shift,
    'token'     => '',
    'filename'  => '',
    'file_root' => '',
    'URL_root'  => '',
  };
  bless $self, $class;
  return $self;
}


sub set_cache_filename {
  my ($self, $filename) = @_;
  
  $self->{'cache'}      = 1;
  my $MD5 = hex(substr( md5_hex($filename), 0, 6 )); ## Just the first 6 characters will do!
  my $c1  = $EnsEMBL::Web::Root::random_ticket_chars[($MD5>>5)&31];
  my $c2  = $EnsEMBL::Web::Root::random_ticket_chars[$MD5&31];
  
  $self->{'token'}      = "$c1$c2$filename";
  $self->{'filename'}   = "$c1/$c2/$filename";
warn "File will be ".$self->{'filename'};
  $self->{'file_root' } = $self->{'species_defs'}->ENSEMBL_TMP_DIR;
}


sub filename { 
  my $self = shift;
  return $self->{'file_root'}.'/'.$self->{'filename'};
}


sub save {
  my( $self, $object, $param ) = @_;
  my $out = $self->filename;
  my (%result, $fh);
  return unless $object;
  return unless $param;

  ## what kind of data do we have?
  if ($param =~ /^upload/) {
    ## open data file 
    my $cgi = $object->[1]->{'_input'};
    my $in = $cgi->tmpFileName($object->param($param));
    my $open = open (IN, '<', $in) || warn qq(Cannot open CGI temp file for caching: $!);
    if( $open ) {
      $fh = $self->_prep_output($out);
      if ($fh) {
        while (<IN>) {
          print $fh $_;
        }
        close(IN);
        $result{'file'} = $out;
      } 
    } 
    else {
      $result{'error'} = 'no_upload';
      warn $@;
    }
  }
  elsif ($param =~ /^url/) { 
    my $useragent = LWP::UserAgent->new();
    $useragent->proxy( 'http', $object->species_defs->ENSEMBL_WWW_PROXY ) if( $object->species_defs->ENSEMBL_WWW_PROXY );
    my $request = new HTTP::Request( 'GET', $object->param($param) );
    $request->header( 'Pragma'           => 'no-cache' );
    $request->header( 'Cache-control' => 'no-cache' );
    my $response = $useragent->request($request);
    if( $response->is_success && $response->content) {
      $fh = $self->_prep_output($out);
      print $fh $response->content if $fh;
      $result{'file'} = $out;
    }
    else {
      $result{'error'} = 'no_online';
      warn $@;
    }
  }
  else {
    my $data = $object->param($param);
    if ($data) {
      $fh = $self->_prep_output($out);
      print $fh $data if $fh;
      $result{'file'} = $out;
    }
    else {
      $result{'error'} = 'no_paste';
      warn $@;
    }
  }

  if ($fh) {
    close($fh);
  }
  else {
    $result{'error'} = 'no_cache';
  }
  return \%result;
}

sub _prep_output {
  my ($self, $out) = @_;
  my $fh;
  $self->make_directory( $out );
  open($fh, ">$out") || warn qq(Cannot open local cache file for saving: $!);
  return $fh;
}

sub retrieve {
  my( $self, $cache ) = @_;
  
  my $open = open (IN, '<', $cache) || warn qq(Cannot open cached upload for parsing: $!);
  my $data;
  if( $open ) {
    while (<IN>) {
      $data .= $_;
    }
    close(IN);
  }
  return $data;
}

__END__

=head1 Ensembl::Web::File::Text

=head2 SYNOPSIS

Simple caching and retrieval of uploaded text files.

Caching:

  my $tmpfilename = $cgi->tmpFileName($filename);
  my $cache = new EnsEMBL::Web::File::Data($species_defs);
  $cache->set_cache_filename($tmpfilename);
  $cache->save($tmpfilename);
  my $cachename = $cache->filename;

Retrieval:

  my $cache = new EnsEMBL::Web::File::Data($species_defs);
  $data = $cache->retrieve($cachename);


=head2 DESCRIPTION

Some wizards, e.g. Karyoview, need to be able to able to upload a file at one step and then use it at a later point in the wizard process. Unfortunately CGI throws away temporary files when a script exits, so the upload needs to be cached elsewhere.

Note: this module is designed to handle only simple text-based genomic files such as GTF format.

=head2 METHOD

=head3 B<new>

Description: Simple constructor method

=head3 B<set_cache_filename>

Assigns a random output directory in the Ensembl tmp directory - at the moment, the CGI-assigned tmp filename is retained.
 
=head3 B<filename>

Retrieves the path assigned by set_cache_filename
 
=head3 B<save>

Reads the text file in and writes it out to the assigned location
 
=head3 B<retrieve>

Reads the cached file and returns it as a string
 
=head2 BUGS AND LIMITATIONS

=head3 Bugs

None known

=head3 Limitations

Currently assumes that CGI.pm stores its temporary files in /usr/tmp

=head2 AUTHOR

Anne Parker, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org

=head2 COPYRIGHT

See http://www.ensembl.org/info/about/code_licence.html

=cut

1;
