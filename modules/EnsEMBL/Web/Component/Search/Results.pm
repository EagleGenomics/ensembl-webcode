package EnsEMBL::Web::Component::Search::Results;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $exa_obj = $object->Obj;
  my $html;

  my @groups;
  foreach my $group ( $exa_obj->groups ) {
    my $name = $group->name;
    $name =~ s/answergroup\.//;
    next if ($name eq 'Source');
    push @groups, $group;
  }
  my $group_count = @groups;

  if (@groups) {
    my @group_classes = ('one-col');
    if ($group_count > 1) {
      @group_classes = $group_count > 2 
        ? ('threecol-left', 'threecol-middle', 'threecol-right') 
        : ('twocol-left', 'twocol-right');
    }

    my $i = 0;
    foreach my $group ( @groups ) {
      my $name = $group->name;
      $name =~ s/answergroup\.//;

      my $url = '/'.$object->species.'/Search/Details?species='.$object->param('species')
                .';idx='.$object->param('idx').';q='.$object->param('q');

      my $c;
      foreach ($group->children) {
        $c += $_->count;
      }

      my $index = ($i % 3) - 1;
      my $class = $group_classes[$i];
      $html .= qq(<div class="$class">
<table class="search_results">
<tr><th colspan="2">By $name</th></tr>
<tr><td><a href="$url">Total</a></td><td><a href="$url">$c</a></td></tr>
      );

      foreach my $child ( sort {$a->name cmp $b->name} $group->children ) {
        my $c_name = $child->name;
        my $c_count    = $child->count;
        my $c_url;
        if ($child->link( 'refine' )) {
          $c_url = $child->link( 'refine' )->URL;
        }
        $c_url =~ s#search#Search/Details#;
        $html .= qq(<tr>
<td>);

        if ($child->children) {
          $html .= qq(<a href="$c_url" class="collapsible"><img src="/i/list_shut.gif" alt="&gt;" style="padding-right:4px" />$c_name</a>
<ul class="shut">\n);

          foreach my $grandchild ( sort {$a->name cmp $b->name} $child->children ) {
            my $g_name  = $grandchild->name;
            my $g_count = $grandchild->count;
            my $g_url;
            if ($grandchild->link( 'refine' )) {
              $g_url = $grandchild->link( 'refine' )->URL;
            }
            $g_url =~ s#search#Search/Details#;
            $html .= qq#<li><a href="$g_url">$g_name ($g_count)</a></li>#;
          }
          $html .= "</ul>\n";
        }
        else {
          $html .= qq(<a href="$c_url" class="no_arrow">$c_name</a>);
        }

        $html .= qq(</td>
<td style="width:5em"><a href="$c_url">$c_count</a>
</tr>\n);
      }

      $html .= qq(</table>\n</div>\n\n);
      $i++;
    }
  }
  else {
    $html = $self->re_search;
  }
  return $html;
}


sub re_search {
  my $self = shift;
  my $object = $self->object;
  my $exa_obj = $object->Obj;
  my $html;

  my $species = $object->param('species');
  my $species_name = $species eq 'all' ? 'all species' : $species;
  my $q = $object->param('q');
  my $q_name = $q;

  my $do_search = 0;
  if ($q =~ /^(\S+?)(\d+)/) {
    my $ENS = $1;
    my $dig = $2;
    if ( ($ENS =~ /ENS|OTT/) && ($ENS !~ /[ENSFM|ENSSNP]/ ) && (length($dig) != 11) ) {
      $do_search = 1;
      my $newq = $ENS.sprintf("%011d",$dig);
      (my $newq_name = $newq) =~ s/(\d+)/<strong>$1<\/strong>/;
      $q_name =~ s/(\d+)/<strong>$1<\/strong>/;
      $html = qq(<p>Your search of $species_name with $q_name returned no results</p>);
      my $url = '/'.$object->species."/Search/Results?species=$species;idx=".$object->param('idx').';q='.$newq;
      $html .= sprintf qq(<p><br />Would you like to <a href="%s"> search using $newq_name</a> ?<p>),$url;
      return $html;
    }
  }
  if (! $do_search && ($species ne 'all') ) {
    $species =~ s/_/ /g;
    $html = qq(<p>Your search of <strong>$species</strong> returned no results</p>);
    my $url = '/'.$object->species.'/Search/Results?species=all;idx='.$object->param('idx').';q='.$q;
    $html .= sprintf qq(<p><br />Would you like to <a href="%s"> search <strong>all</strong> species</a> with this term ?<p>),$url;
    return $html;
  }

  $html = qq(<p>Your search of <strong>$species_name</strong> with <strong>$q</strong> returned no results</p>);
  return $html;
}


1;

