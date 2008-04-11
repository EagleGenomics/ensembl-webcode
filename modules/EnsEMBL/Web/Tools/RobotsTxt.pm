package EnsEMBL::Web::Tools::RobotsTxt;

sub create {
  ### This is to try and stop search engines killing e! - it gets created each
  ### time on server startup and gets placed in the first directory in the htdocs
  ### tree.
  ### Returns: none
  my $root = $ENSEMBL_HTDOCS_DIRS[0];
  my %allowed = map { ($_,1) } @{$SiteDefs::ENSEMBL_EXTERNAL_SEARCHABLE||[]};
  if( open FH, ">$root/robots.txt" ) {
    print FH qq(
User-agent: *
Disallow: /Multi/
Disallow: /BioMart/
);
    foreach( @$ENSEMBL_SPECIES ) {
      print FH qq(Disallow: /$_/\n);
      print FH qq(Allow: /$_/geneview\n) if $allowed{'gene'};
      print FH qq(Allow: /$_/sitemap.xml.gz\n);
    }
    print FH qq(

User-Agent: W3C-checklink
Disallow:
);
    close FH;
  } else {
    warn "Unable to creates robots.txt file in $root-robots";
  }
}

1;
