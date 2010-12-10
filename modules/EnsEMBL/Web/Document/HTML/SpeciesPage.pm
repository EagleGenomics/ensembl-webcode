package EnsEMBL::Web::Document::HTML::SpeciesPage;

### Renders the content of the  "Find a species page" linked to from the SpeciesList module

use strict;

use EnsEMBL::Web::RegObj;

sub render {

  my ($class, $request) = @_;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $sitename = $species_defs->ENSEMBL_SITETYPE;
  my $tree          = $species_defs->SPECIES_INFO;

  ## Get current Ensembl species
  my @valid_species = $species_defs->valid_species;
  my $species_check;
  foreach my $sp (@valid_species) {
    $species_check->{$sp}++;
  }

  my %species;
  foreach my $species (@valid_species) {
    my $common = $species_defs->get_config($species, "SPECIES_COMMON_NAME");
    my $info = {
          'dir'     => $species,
          'status'  => 'live',
    };
    $species{$common} = $info;
  }

  ## Add in pre species
  my $pre_species = $species_defs->get_config('MULTI', 'PRE_SPECIES');
  if ($pre_species) {
    while (my ($bioname, $common) = each (%$pre_species)) {
      my $status = $species{$common} ? 'both' : 'pre';
      $species{$common} = {
        'dir'     => $bioname,
        'status'  => $status,
      };
    }
  }
  

  my $total = scalar(keys %species);
  my $break = int($total / 3);
  $break++ if $total % 3;
  ## Reset total to number of cells required for a complete table
  $total = $break * 3;
  my $link_style = 'font-size:1.1em;font-weight:bold;text-decoration:none;';

  my $html = qq(
<div>
<h2>$sitename Species</h2>
<div class="threecol-left">
  );
  my @species = sort keys %species;
  for (my $i=0; $i < $total; $i++) {
    if ($i == int($total/3)) {
     $html .= qq(</div>\n<div class="threecol-middle">);
    }
    elsif ($i == int(($total/3)*2)) {
     $html .= qq(</div>\n<div class="threecol-right">);
    }
    $html .= '<div class="species-entry">';
    my $common = $species[$i];
    next unless $common;
    my $info = $species{$common};
    my $dir = $info->{'dir'};
    (my $name = $dir) =~ s/_/ /;
    my $link_text = $common =~ /\./ ? $name : $common;
    if ($dir) {
      $html .= qq(<img src="/img/species/thumb_$dir.png" alt="$name" class="species-entry">);
    }
    else {
    }
    if ($dir) {
      if ($info->{'status'} eq 'pre') {
        $html .= qq(<span style="$link_style">$link_text</span> (<a href="http://pre.ensembl.org/$dir/" rel="external">preview - assembly only</a>));
      }
      elsif ($info->{'status'} eq 'both') {
        $html .= qq#<span><a href="/$dir/Info/Index/" style="$link_style">$link_text</a></span> (<a href="http://pre.ensembl.org/$dir/" rel="external">preview new assembly</a>)#;
      }
      else {
        $html .= qq(<span><a href="/$dir/Info/Index/"  style="$link_style">$link_text</a></span>);
      }
      unless ($common =~ /\./) {
        $html .= "<br /><i>$name</i>";
      }
    }
    else {
      $html .= '&nbsp;';
    }
    ## Add links to static content, if any
    my $static = $tree->{$dir};

    if (keys %$static) {
      my @page_order = sort {
        $static->{$a}{'_order'} <=> $static->{$b}{'_order'} ||
        $static->{$a}{'_title'} cmp $static->{$b}{'_title'} ||
        $static->{$a} cmp $static->{$b}
      } keys %$static;

      $html .= '<ul>';

      foreach my $filename (@page_order) {
        if ($static->{$filename}{'_title'}) {
          $html .= sprintf '<li style="margin-left:25px"><a href="/%s/Info/Content?file=%s">%s</a></li>',
                    $dir, $filename, $static->{$filename}{'_title'};
        }
      }
      $html .= '</ul>';
    }
    $html .= '<p class="invisible">.</p></div>';
  }
  $html .= qq(
  </div>
  <p class="invisible">.</p></div>);
  return $html;
}

1;
