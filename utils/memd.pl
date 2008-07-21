#!/usr/local/bin/perl

use strict;
use FindBin qw($Bin);
use Cache::Memcached;
use Data::Dumper;

BEGIN{
  unshift @INC, "$Bin/../conf";
  unshift @INC, "$Bin/../modules";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;

  eval{ require EnsEMBL::Web::Cache };
  if ($@){ die "Can't use EnsEMBL::Web::Cache - $@\n"; }
}

my $memd = new EnsEMBL::Web::Cache;

if ($memd) {

  if ($ARGV[0] =~ /get/i) {
    print $memd->get($ARGV[1])."\n";
  } elsif ($ARGV[0] =~ /(tags?)?_?delete/i) {
    shift @ARGV;
    print $memd->delete_by_tags(@ARGV)."\n";
  } elsif ($ARGV[0] =~ /flush_?all/i) {
    print "Flushing cache:\n";
    print $memd->delete_by_tags." cache items deleted\n";
  } elsif ($ARGV[0] =~ /stats/i) {
    shift @ARGV;
    print "Stats:\n";
    print Dumper($memd->stats(@ARGV))."\n";
  } else {
  
    my $debug_key_list = $memd->get('debug_key_list');
    my $key_list = {};
    
    if ($debug_key_list) {
      if (my $pattern = $ARGV[0]) {
    
        %$key_list = map { $_ => $debug_key_list->{$_} }
                       grep { /$pattern/ }
                          keys %$debug_key_list;
    
      } else {
        $key_list = $debug_key_list;
      }
      
      print Dumper($key_list);
    } else {
      print "No debug_key_list found \n";
    }
  
  }
} else {
   print "No memd server configured or can not connect\n";
}


1;