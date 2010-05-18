package EnsEMBL::Web::Component::Location::NavigateHomology;

### Module to replace part of the former SyntenyView, in this case 
### the 'navigate homology' links

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;

  ## Don't show this component if the slice covers or exceeds the whole chromosome!
  if ( 
    $object->chromosome->length < 1e6 ||
    ($object->param('r') =~ /:/ &&
    $object->seq_region_start < 2 && 
    $object->seq_region_end > ($object->chromosome->end - 1))
  ) {
    return;
  } 
  
  my $max_len        = $object->seq_region_end < 1e6 ? $object->seq_region_end : 1e6;
  my $seq_region_end = $object->param('r') =~ /:/ ? $object->seq_region_end : $max_len;
  my $chr            = $object->seq_region_name; 
  my $sliceAdaptor   = $object->get_adaptor('get_SliceAdaptor');
  my $max_index      = 15;
  my $max_minus      = -15;
  my $start          = $object->seq_region_start || 100;
  my $end            = $seq_region_end || ($object->chromosome->end - 100);
  my $upstream       = $sliceAdaptor->fetch_by_region('chromosome', $chr, 1, $object->seq_region_start - 1 );
  my $downstream     = $sliceAdaptor->fetch_by_region('chromosome', $chr, $seq_region_end + 1, $object->chromosome->end );
  my @up_genes       = $upstream ?   reverse @{$object->get_synteny_local_genes($upstream)} : ();
  my @down_genes     = $downstream ? @{$object->get_synteny_local_genes($downstream)}       : ();
  my $up_count       = @up_genes;
  my $down_count     = @down_genes;
  my ($up_link, $down_link, $gene_text);
  
  if ($up_count) {
    my @up_sample;
    
    for (my $i = -1; $i >= $max_minus; $i--) {
      next if !$up_genes[$i];
      push @up_sample, $up_genes[$i];
    }
    
    $up_count  = @up_sample;
    $gene_text = $up_count > 1 ? 'genes' : 'gene';
    
    my $up_start  = @up_sample ? $object->seq_region_start - $up_sample[-1]->end  : 0;
    my $up_end    = @up_sample ? $object->seq_region_start - $up_sample[0]->start : 0;
    
    $up_link = sprintf('
      <a href="%s"><img src="/i/nav-l2-old.gif" class="zoom" alt="<<"/> %s upstream %s</a>',
      $object->_url({ type => 'Location', action => 'Synteny', otherspecies =>  $object->param('otherspecies'), r => "$chr:$up_start-$up_end" }), $up_count, $gene_text
    );
  } else {
    $up_link = 'No upstream homologues';
  }

  
  
  if ($down_count) {
    my @down_sample;
    
    for (my $j = 0; $j < $max_index; $j++) {
      next if !$down_genes[$j];
      push @down_sample, $down_genes[$j];
    }
    
    $down_count = @down_sample;
    $gene_text  = $down_count > 1 ? 'genes' : 'gene';
    
    my $down_start = @down_sample ? $down_sample[0]->start + $seq_region_end : 0;
    $down_start    = -$down_start if $down_start < 0;
    my $down_end   = @down_sample ? $down_sample[-1]->end + $seq_region_end : 0;
    
    $down_link = sprintf('
      <a href="%s">%s downstream %s <img src="/i/nav-r2-old.gif" class="zoom" alt="<<"/></a>',
      $object->_url({ type => 'Location', action => 'Synteny', otherspecies =>  $object->param('otherspecies'), r => "$chr:$down_start-$down_end" }), $down_count, $gene_text
    );
  } else {
    $down_link = 'No downstream homologues';
  }
  
  return qq{
    <div class="autocenter_wrapper">
      <div class="navbar autocenter">
        <table style="width:100%">
          <tr>
            <td class="left" style="padding:0px 2em">$up_link</td>
            <td class="center" style="font-size:1.2em;padding:0px 2em">Navigate homology</td>
            <td class="right" style="padding:0px 2em">$down_link</td>
          </tr>
        </table>
      </div>
    </div>
  };
}

1;
