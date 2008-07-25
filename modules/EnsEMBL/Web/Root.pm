package EnsEMBL::Web::Root;

use strict;
use Time::HiRes qw(gettimeofday);
use File::Path;
use File::Spec::Functions qw(splitpath);
use CGI qw( escapeHTML escape);
use POSIX qw(floor ceil);

our $failed_modules;

use Text::Wrap;
sub new {
### Constructor
### Constructs the class - as its a base class contains nothing.!
  my $class = shift;
  my $self  = {};
  bless $self,$class;
  return $class;
}

sub url { 
  ### Assembles a valid URL, adding the site's base URL
  ### and CGI-escaping any parameters
  ### returns a URL string
  my ($self, $script, $param) = @_;
  my $url = $script; # TO DO - add site base URL
  my $query_string = join ';', map { "$_=".escapeHTML($param->{$_}) } sort keys %$param;
  $url .= "?$query_string" if $query_string;

  return $url;
}

sub _format_error {
### Format an error message by wrapping text to 120 columns
  my $self = shift;
  $Text::Wrap::columns = 120;
  my $out = qq(\n      <pre class="syntax-error">\n).
            CGI::escapeHTML( join "\n", map { Text::Wrap::wrap( '        ', '        ... ', $_ ) } split /\n/, join '', @_ ).
            qq(\n      </pre>);
  $out =~ s/^(\.{3} )/$1/gm;
  return $out;
}

sub dynamic_use {
### Equivalent of USE - but used at runtime
  my( $self, $classname ) = @_;
  unless( $classname ) {
    my @caller = caller(0);
    my $error_message = "Dynamic use called from $caller[1] (line $caller[2]) with no classname parameter\n";
    warn $error_message;
    $failed_modules->{$classname} = $error_message;
    return 0;
  }
  if( exists( $failed_modules->{$classname} ) ) {
    #warn "EnsEMBL::Web::Root: tried to use $classname again - this has already failed $failed_modules->{$classname}";
    return 0;
  }
  my( $parent_namespace, $module ) = $classname =~/^(.*::)(.*)$/ ? ($1,$2) : ('::',$classname);
  no strict 'refs';
  return 1 if $parent_namespace->{$module.'::'} && %{ $parent_namespace->{$module.'::'}||{} }; # return if already used 
  eval "require $classname";
  if($@) {
    my $module = $classname; 
    $module =~ s/::/\//g;
    warn "EnsEMBL::Web::Root: failed to use $classname\nEnsEMBL::Web::Root: $@" unless $@ =~/^Can't locate $module/;
#    warn "DYNAMIC USE FAILURE: $@";
#    $parent_namespace->{$module.'::'} = {};
    $failed_modules->{$classname} = $@ || "Unknown failure when dynamically using module";
    return 0;
  }
  $classname->import();
  return 1;
}

sub dynamic_use_failure {
### Return error message cached if use previously failed!
  my( $self, $classname ) = @_;
  return $failed_modules->{$classname};
}

sub neat_sr_name {
### Returns seq-region name formatted neatly...
  my( $self, $type, $name ) = @_;
  return $name if $name =~ /^$type/;
  (my $neat_type = ucfirst(lc($type)) ) =~ s/contig/Contig/;
  return "$neat_type $name"; 
}

sub pretty_date {
### Converts a MySQL datestamp into something human-readable
  my ($self, $datetime) = @_;
  my ($date, $time) = split(' ', $datetime);
  my ($year, $mon, $day) = split('-', $date);
  my ($hour, $min, $sec) = split(':', $date);

  my @months = ('', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
                'September', 'October', 'November', 'December');

  $day =~ s/^0//;
  return $day.' '.$months[$mon].' '.$year;
}

sub thousandify {
### Retuns comma separated version of number...
  my( $self, $value ) = @_;
  local $_ = reverse $value;
  s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $_;
}

sub round_bp {
### Returns #bp formatted neatly as either m/k
  my( $self, $value ) = @_;
  if( $value > 2e6 ) { return sprintf '%0.2fm', $value/1e6; }
  if( $value > 2e3 ) { return sprintf '%0.2fk', $value/1e3; }
  return $self->thousandify( $value );
}

sub evaluate_bp {
### Reverse of round BP - takes a value with a K/M/G at the end and converts to integer value...
  my( $self, $value ) = @_;
  $value =~ s/,//g;
  return $value * 1e3 if( $value =~ /K/i );
  return $value * 1e6 if( $value =~ /M/i );
  return $value * 1e9 if( $value =~ /G/i );
  return $value * 1;
} 

our %roman2arabic = qw(I 1 V 5 X 10 L 50 C 100 D 500 M 1000);

sub de_romanize {
### Converts a number from roman (IV...) format to number...
  my( $self, $string ) = @_;
  return 0 if $string eq '';
  return 0 unless $string =~ /^(?: M{0,3}) (?: D?C{0,3} | C[DM]) (?: L?X{0,3} | X[LC]) (?: V?I{0,3} | I[VX])$/ix;
  my $last_digit = 1000;
  my $arabic;
  foreach (split(//, uc $string)) {
    my $digit = $roman2arabic{$_};
    $arabic -= 2 * $last_digit if $last_digit < $digit;
    $arabic += ($last_digit = $digit);
  }
  return $arabic;
}

sub seq_region_sort {
### Used to sort chromosomes into a sensible order!
  my( $self, $chr_1, $chr_2 ) = @_;
  if( $chr_1 =~ /^\d+/ ) {
    return $chr_2 =~ /^\d+/ ? ( $chr_1 <=> $chr_2 || $chr_1 cmp $chr_2 ) : -1;
  } elsif( $chr_2 =~ /^\d+/ ) {
    return 1;
  } elsif( my $chr_temp_1 = $self->de_romanize($chr_1) ) {
    if( my $chr_temp_2 = $self->de_romanize( $chr_2 ) ) {
      return $chr_temp_1 <=> $chr_temp_2;
    } else {
      return $chr_temp_1;
    } 
  } elsif( $self->de_romanize( $chr_2 ) ) { 
    return 1;
  } else { 
    return $chr_1 cmp $chr_2;
  }
}

our @random_ticket_chars = ('A'..'Z','a'..'f');

sub ticket {
### Returns a random ticket string
  my $self = shift;
  my $date = time() + shift;
  my($sec, $msec) = gettimeofday;
  my $rand = rand( 0xffffffff );
  my $fn = sprintf "%08x%08x%06x%08x", $date, $rand, $msec, $$;
  my $fn2 = '';
  while($fn=~s/^(.....)//) {
    my $T = hex($1);
    $fn2 .= $random_ticket_chars[$T>>15].
            $random_ticket_chars[($T>>10)&31].
            $random_ticket_chars[($T>>5)&31].
            $random_ticket_chars[$T&31];
  }
  return $fn2;
}

# assuming a ticket generated above the top-level directory cycles
# every 4.5 hrs, 2nd level every 4.5 minutes, extra character means
# that there will be 64 directories created in any period...
# on average there will be approximately 25,000 directories around at
# any one time (or 400 if we drop the 3rd slash...)
#

sub temp_file_name {
### Creates a random filename
  my( $self, $extn, $template ) = @_;
  $template ||= 'XXX/X/X/XXXXXXXXXXXXXXX';
  return $self->templatize( $self->ticket, $template ).($extn?".$extn":'');
}

sub make_directory {
### Creates a writeable directory - making sure all parents exist!
  my( $self, $path ) = @_;
  my ($volume, $dir_path, $file) = splitpath( $path );
  mkpath( $dir_path, 0, 0777 );
  return ($dir_path,$file);
}

sub temp_file_create {
### Creates a temporary file name and makes sure its parent directory exists
  my $self = shift;
  my $FN = $self->temp_file_name( @_ );
  (my $path = $FN) =~ s/\/[^\/]*$//;
  mkpath( $self->species_defs->ENSEMBL_TMP_DIR.'/'.$path, 0, 0777 );
  return $FN;
}

sub templatize {
### Takes a string, and a template pattern and returns the string with "/" from the template inserted...
  my( $self, $ticket, $template ) = @_;
  $template =~ s/\/+/\//g;
  $ticket   =~ s/[^A-Za-z!_]//g;
  my @P = split //, $template ;
  my $fn = '';
  foreach( split //, $ticket ) {
    $_ ||= '_';
    my $P = shift @P;
    if( $P eq '/') {
      $fn.='/';
      $P = shift @P;
    }
    $fn .= $_;
  }
  return $fn;
}

1;
