package EnsEMBL::Web::Cache;

## This module overwrites several subroutines from Cache::Memcached
## to be able to track and monitor memcached statistics better
## this applies only when debug mode is on

use strict;
use Data::Dumper;
use SiteDefs;
use base 'Cache::Memcached';
use fields qw(default_exptime flags);

no warnings;

sub new {
  my $class  = shift;
  my $caller = caller;
  my $memcached    = $SiteDefs::ENSEMBL_MEMCACHED;
  
  return undef
    unless $memcached && %$memcached;

  my $flags = $memcached->{flags} || [ qw(PLUGGABLE_PATHS TMP_IMAGES) ];

  my %flags = map { $_ => 1 } @$flags;
     
  return undef if $caller->isa('EnsEMBL::Web::Apache::Handlers')
                  && !$flags{PLUGGABLE_PATHS};
  return undef if $caller->isa('EnsEMBL::Web::Apache::SendDecPage')
                  && !$flags{STATIC_PAGES_CONTENT};
  return undef if $caller->isa('EnsEMBL::Web::DBSQL::UserDBConnection')
                  && !$flags{USER_DB_DATA};
  return undef if $caller->isa('EnsEMBL::Web::DBSQL::WebDBConnection')
                  && !$flags{WEBSITE_DB_DATA};
  return undef if $caller->isa('EnsEMBL::Web::File::Driver::Memcached')
                  && !$flags{TMP_IMAGES};
  return undef if $caller->isa('EnsEMBL::Web::Apache::Image')
                  && !$flags{TMP_IMAGES};
  return undef if $caller->isa('EnsEMBL::Web::Magic')
                  && !$flags{DYNAMIC_PAGES_CONTENT};
  return undef if $caller->isa('EnsEMBL::Web::Configuration')
                  && !$flags{ORDERED_TREE};
  return undef if $caller->isa('EnsEMBL::Web::Object')
                  && !$flags{OBJECTS_COUNTS};
  return undef if $caller->isa('EnsEMBL::Web::ImageConfig')
                  && !$flags{IMAGE_CONFIG};

  my %args = (
    servers         => $memcached->{servers},
    debug           => $memcached->{debug},
    default_exptime => $memcached->{default_exptime},
    namespace       => $SiteDefs::ENSEMBL_BASE_URL,
    @,
  );

  my $default_exptime = delete $args{default_exptime};

  my $self = $class->SUPER::new(\%args);
  $self->enable_compress(0) unless $args{enable_compress};

  $self->{default_exptime} = $default_exptime;
  $self->{flags}          = \%flags;
  
  return $self;
}

sub flags :lvalue { $_[0]->{'flags'}; }

sub add_tags {
  my $self = shift;
  my $key  = shift;
  my @tags = @_;

  _warn("MEMCACHED->add_tags( $key, ".join(', ', @tags).')');

  my $sock = $self->get_sock($key);
  foreach my $tag (@tags) {
    my $cmd = "tag_add $tag $self->{namespace}$key\r\n";
    my $res = $self->_write_and_read($sock, $cmd);
    return 0 unless $res eq "TAG_STORED\r\n";
  }

  return 1;
}


##
## delete_by_tags(@tags)
## deletes all and only items which have ALL tags specified
##
sub delete_by_tags {
  my $self = shift;
  my @tags = (@_, $self->{namespace});

  _warn('MEMCACHED->delete_by_tags( '.join(', ', @tags).')');

  my $cmd = 'tags_delete '.join(' ', @tags)."\r\n";
  my $items_deleted = 0;

  my @hosts = @{$self->{'buckets'}};
  foreach my $host (@hosts) {
      my $sock = $self->sock_to_host($host);
      my $res = $self->_write_and_read($sock, $cmd);
      if ($res =~ /^(\d+) ITEMS_DELETED/) {
        $items_deleted += $1;
      }
  }

  _warn("MEMCACHED: $items_deleted items deleted");
  
  return $items_deleted;

  #  } else { ## just 1 tag, better use tag_delete (faster)
  #    my $cmd = 'tag_delete '.$tags[0]."\r\n";
  #    my $res = $self->_write_and_read($sock, $cmd);
  #    return $res eq "TAG_DELETED\r\n";
  #  }
}

sub set {
  my $self = shift;
  my ($key, $value, $exptime, @tags) = @_;
  return unless $value;
  
  _warn("MEMCACHED->set($self->{namespace}$key)");
  
  ## TMP workaround: add extra tag for everything except user upload data
  push @tags, 'no_user_upload'
    unless 'EnsEMBL::Web::File::Driver::Memcached' eq caller;
  
  my $result = $self->SUPER::set($key, $value, $exptime || $self->{default_exptime});
  $self->add_tags($key, $self->{namespace}, @tags);

  return $result;
}

sub get {
  my $self = shift;
  my $key  = shift;

  _warn("MEMCACHED->get($key)");
  
  return $self->SUPER::get($key);
}

sub delete {
  my $self = shift;
  my $key  = shift;

  _warn("MEMCACHED->delete($key)");

  return $self->SUPER::remove($key, @_);
}

*remove = \&delete;

## Warn only if debug flags are on
sub _warn {
  warn @_
    if $SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_MEMCACHED;
}

1;