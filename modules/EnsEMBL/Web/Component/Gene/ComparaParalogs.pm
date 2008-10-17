package EnsEMBL::Web::Component::Gene::ComparaParalogs;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $gene   = $self->object;

## call table method here
  my $db              = $gene->get_db() ;
  my $paralogue = $gene->get_homology_matches('ENSEMBL_PARALOGUES', 'within_species_paralog');
  my $html;
  return qq(<p>No paralogues have been identified for this gene</p>) unless keys %$paralogue;

  my %paralogue_list = %{$paralogue};
  $html = qq(
    <p>
      The following gene(s) have been identified as putative paralogues (within species):
    </p>
    <table>);
  $html .= qq(
    <tr>
      <th>Taxonomy Level</th><th>Gene identifier</th>
    </tr>);
  my %paralogue_map = qw(SEED BRH PIP RHS);

  my $STABLE_ID = $gene->stable_id; my $C = 1;
  my $MCV_STUB  = $gene->_url({ 'type' => 'Location', 'action' => 'Comparison' });
  my $FULL_URL  = $MCV_STUB;
  my $ALIGNVIEW = 0;
  my $EXTRA2;
  my $matching_paralogues = 0;
  my $previous = '';
  foreach my $species (sort keys %paralogue_list){
    foreach my $stable_id (sort {$paralogue_list{$species}{$a}{'order'} <=> $paralogue_list{$species}{$b}{'order'}} keys %{$paralogue_list{$species}}){
      my $OBJ = $paralogue_list{$species}{$stable_id};
      my $matching_paralogues = 1;
      my $description = $OBJ->{'description'};
         $description = "No description" if $description eq "NULL";
      my $paralogue_desc = $paralogue_map{ $OBJ->{'homology_desc'} } || $OBJ->{'homology_desc'};
      my $paralogue_subtype = $OBJ->{'homology_subtype'};
         $paralogue_subtype = "&nbsp;" unless (defined $paralogue_subtype);
      my $paralogue_dnds_ratio = $OBJ->{'homology_dnds_ratio'};
      $paralogue_dnds_ratio = "&nbsp;" unless ( defined $paralogue_dnds_ratio);
      if($OBJ->{'display_id'}) {
        (my $spp = $OBJ->{'spp'}) =~ tr/ /_/ ;
        my $link = $gene->_url({
          'g' => $stable_id,
          'r' => undef
        });
        my $EXTRA = sprintf '<span class="small">[<a href="%s;s1=%s;g1=%s;context=1000">MultiContigView</a>]</span>',
          $MCV_STUB, $spp, CGI::escapeHTML( $stable_id );
        if( $paralogue_desc ne 'DWGA' ) {
          my $url = $gene->_url({ 'action' => 'Compara_Paralog/Alignment', 'g1' => $stable_id });
          $EXTRA .= sprintf '&nbsp;<span class="small">[<a href="%s">Align</a>]</span>', $url;
          $EXTRA2 = qq(<br /><span class="small">[Target &#37id: $OBJ->{'target_perc_id'}; Query &#37id: $OBJ->{'query_perc_id'}]</span>);
          $ALIGNVIEW = 1;
        }
        $FULL_URL .= ";s$C=$spp;g$C=$stable_id";$C++;
        if( $description =~ s/\[\w+:([-\w\/]+)\;\w+:(\w+)\]//g ) {
          my ($edb, $acc) = ($1, $2);
          if( $acc ) {
            $description .= "[".$gene->get_ExtURL_link("Source: $edb ($acc)", $edb, $acc)."]";
          }
        }
        $html .= qq(
    <tr>
      <td>).($paralogue_subtype eq $previous ? '&nbsp' : $paralogue_subtype).qq(</td>
      <td><a href="$link">$stable_id</a> (@{[ $OBJ->{'display_id'} ]}) $EXTRA<br />
      <span class="small">$description</span>$EXTRA2</td>
    </tr>);
       } else {
        $html .= qq(
    <tr>
      <td>).($paralogue_subtype eq $previous ? '&nbsp' : $paralogue_subtype).qq(</td>
      <td>$stable_id <br /><span class="small">$description</span>$EXTRA2</td>
    </tr>);
      }
      $previous = $paralogue_subtype;
    }
  }
  $html .= qq(</table>);
  if( $ALIGNVIEW && keys %paralogue_list ) {
    my $url = $gene->_url({ 'action' => 'Compara_Paralog/Alignment' });
    $html .= qq(\n      <p><a href="$url">View sequence alignments of all homologues</a>.</p>);
  }

  return $html;
}

1;

