# $Id$

package EnsEMBL::Web::Document::HTML::DocsMenu;

### Generates "local context" menu for documentation (/info/)

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $sd = $self->species_defs;
  my $you_are_here = $ENV{'SCRIPT_NAME'};
  (my $location = $you_are_here) =~ s/index\.html$//;

  my $tree = $sd->STATIC_INFO;
  my ($title, $class, $menu, $page_count);

  my @sortable_sections;
  foreach my $section (keys %$tree) {
    push (@sortable_sections, $section) if ref($tree->{$section}) eq 'HASH';  
  }
  my @section_order = sort {
        $tree->{$a}{_order} <=> $tree->{$b}{_order}
        || $tree->{$a}{_title} cmp $tree->{$b}{_title}
        || $tree->{$a} cmp $tree->{$b}
    }
    @sortable_sections;
  
  foreach my $section (@section_order) {
    next if $section =~ /^_/;
    $class = '';
    my $subsection = $tree->{$section};
    next unless keys %$subsection;
    $title = $subsection->{'_title'} || ucfirst($section);
    if ($location eq $subsection->{'_path'}) {
      $class = ' class="active"';
    }
    if ($subsection->{'_nolink'}) {
      $menu .= qq(<dd class="open"><strong>$title</strong>);
    }
    else {
      $menu .= sprintf(qq(<dd class="open"><strong><a href="%s" title="%s"%s>%s</a></strong>),
        $subsection->{'_path'}, $title, $class, $title
      );
    }
    $page_count++;
    next if $subsection->{'_no_follow'};
    my @sortable_subsections;
    foreach my $sub (keys %$subsection) {
      push (@sortable_subsections, $sub) if ref($subsection->{$sub}) eq 'HASH';  
    }

    if (scalar(@sortable_subsections)) { ## we have subpages/dirs, not just metadata
      my @sub_order = sort { 
        $subsection->{$a}{_order} <=> $subsection->{$b}{_order}
        || $subsection->{$a}{_title} cmp $subsection->{$b}{_title}
        || $subsection->{$a} cmp $subsection->{$b}
        } 
         @sortable_subsections;
      $menu .= sprintf(qq(
        <dl>
      ), );
      foreach my $sub (@sub_order) {
        next if $sub =~ /^_/;
        $class = '';
        my $pages = $subsection->{$sub};
        next unless keys %$pages;
        my $path = $pages->{'_path'} || $subsection->{'_path'}.$sub;
        $title = $pages->{'_title'} || ucfirst($sub);
        if ($location eq $path) {
          $class = ' class="active"';
        }
        $menu .= sprintf(qq(<dd><a href="%s" title="%s"%s>%s</a></dd>),
            $path, $title, $class, $title
        );
        $page_count++;
      }
      $menu .= qq(</dl>\n);
    }
    $menu .= '</dd>';
  }
 
  my $html = qq(
<input type="hidden" class="panel_type" value="LocalContext" />
<dl class="local_context">
<dt>Help &amp; Documentation</dt>
);
  if ($page_count > 5) {
    $html .= qq(
<dd><a href="/info/">Alphabetical List of Pages</a></dd>
  );
  }
  $html .= $menu;
  $html .= '</dl>'; 
  $self->print($html);
}

1;
