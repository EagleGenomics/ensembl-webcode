# $Id$

package EnsEMBL::Web::Document::HTML::DataBugs;

### This module outputs a selection of news headlines for the home page, 
### based on the user's settings or a default list

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Bug;
use EnsEMBL::Web::Data::Species;
use EnsEMBL::Web::Data::Release;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $filtered = 0;
  my $html;

  my %species_lookup; 
  my @all_species = EnsEMBL::Web::Data::Species->find_all;
  foreach my $sp (@all_species) {
    $species_lookup{$sp->species_id} = $sp->name;
  }

  my $criteria; # = {'last_release' => };

  my @bugs = EnsEMBL::Web::Data::Bug->fetch_bugs($criteria);

  foreach my $bug (@bugs) {

    ## sort out species names
    my @species = $bug->species; 
    my (@sp_ids, $sp_id, $sp_name, $sp_count);
    if (!scalar(@species)) {
      $sp_name = 'all species';
    }
    elsif (scalar(@species) > 5) {
      $sp_name = 'multiple species';
    }
    else {
      my @names;
      foreach my $sp (@species) {
        if ($sp->common_name =~ /\./) {
          push @names, '<i>'.$sp->common_name.'</i>';
        }
        else {
          push @names, $sp->common_name;
        } 
      }
      $sp_name = join(', ', @names);
    }
## generate HTML
  $html .= sprintf(qq(<h2>%s (%s)</h2>), $bug->title, $sp_name);
    my $release_info = 'In releases: ';
    if ($bug->first_release && $bug->last_release) {
      if ($bug->first_release == $bug->last_release) {
        $release_info = 'In release: '.$bug->first_release;
      }
      else {
        $release_info .= $bug->first_release.' - '.$bug->last_release;
      }
    }
    elsif (!$bug->first_release) {
      $release_info .= 'Up to and including '.$bug->last_release;
    }
    elsif (!$bug->last_release) {
      $release_info .= $bug->first_release.' - '.$species_defs->ENSEMBL_VERSION;
    }
    else {
      $release_info .= $species_defs->ENSEMBL_VERSION;
    }
    $html .= "<h3>$release_info</h3>\n<p>".$bug->content.'</p>';


  return $html;
}

1;
