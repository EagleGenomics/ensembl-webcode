package ExaLead::Renderer::HTML;
use strict;

## packages used to grab content of XML
use ExaLead::Renderer;
use ExaLead::Link;
use CGI;

@ExaLead::Renderer::HTML::ISA = qw(ExaLead::Renderer);

our $hit_maps = {
 qw(geneview   contigview
    transview  contigview
    protview   contigview
    contigview cytoview)
};

sub render_spelling {
  my $self = shift;
  return unless $self->exalead->spellingsuggestions;
  return '<div>Do you mean: '.
  join( '; ',
    map { '<a href="'.$self->exalead->rootURL.'?_q='.CGI::escape($_->query).'">'.
       $_->display.'</a>' } $self->exalead->spellingsuggestions
  )."?</div>";
}

sub render_navigation {
  my $self = shift;
  return unless $self->exalead->query;
  return if $self->exalead->nhits < 11;
  my $current_page = int( $self->exalead->start / 10 )   + 1;
  my $maxpage      = int( ($self->exalead->nhits-1) / 10 ) + 1;
  my $out = '<div class="paginate">';
  foreach my $i (1..$maxpage) {
    if( $i == $current_page ) {
      $out .= sprintf( '<strong>%s</strong> ', $i );
    } elsif( $i < 5 || ($maxpage-$i)<4 || abs($i-$current_page+1)<4 ) {
      my $T = new ExaLead::Link( "_s=".(($i-1)*10), $self->exalead );
      $out .= sprintf( '<a href="%s">%s</a> ', $T->URL, $i );
    } else {
      $out .= '..';
    }
  }
  $out =~ s/\.\.+/ ... /g;
  return "$out</div>";
}
sub render_form {
  my $self = shift;
  my $HIDDEN_FIELDS = '';
  my $QUERY_STRING  = '';
  if( $self->exalead->query ) {
    $QUERY_STRING = CGI::escapeHTML( $self->exalead->query->string );
    foreach my $query_par ( $self->exalead->query->parameters ) {
      next if $query_par->name eq '_f';
      next if $query_par->name eq '_q'; 
      # $HIDDEN_FIELDS .= sprintf '<input type="hidden" name="%s" value="%s" />', $query_par->{'name'}, $query_par->{'value'};
    }
  }
  return qq(
    <form action="@{[$self->exalead->rootURL]}" method="get" style="margin: 3px 1em;" >
      <input type="text" name="_q" value="$QUERY_STRING" style="width: 300px" />
        <input type="submit" value="Search" />
        $HIDDEN_FIELDS
    </form>
  );
}
sub _render_text {
  my( $self, $text ) = @_;
  return "<p>$text</p>";
}
sub _render_group {
  my( $self, $group ) = @_;
  if( $group->link( 'reset' ) ) {
    my $name = $group->name ;
    $name =~ s/answergroup\.//;
    return sprintf qq(<dt><a href="%s">%s</a></dt>\n),
      $group->link( 'reset' )->URL,
      CGI::escapeHTML( $name )

  } else {
    return sprintf '<dt>'.CGI::escapeHTML( $group->name )."</dt>\n";
  }
}

sub _render_category {
  my( $self, $category, $level ) = @_;
  my $out = '';
  if( $category->link( 'reset' ) ) {
    $out = sprintf qq(<dd style="margin-left: %fem"><a href="%s"><img align="top" src="/gfx/14-r.gif" height="14" width="14" alt="[R]" border="0" /></a> <a href="%s">%s</a>),
      $level * 2,
      $category->link( 'reset' )->URL,
      $category->link( 'reset' )->URL,
      CGI::escapeHTML( $category->name );
  } else { 
    $out = sprintf qq(<dd style="margin-left: %fem"><a href="%s"><img align="top" src="/gfx/14-m.gif" height="14" width="14" alt="[-]" border="0" /></a> <a href="%s">%s</a>),
      $level * 2,
      $category->link( 'exclude' )->URL,
      $category->link( 'refine' )->URL,
      CGI::escapeHTML( $category->name );
  } 
  if( $category->count > 0 ) {
    $out .= sprintf( " (%d)", $category->count );
  }
  return "$out</dd>\n";
}

sub _render_hit {
  my( $self,  $hit ) = @_;
  my $URL = $hit->URL;
  my $script = $URL =~ /(\w+)\?/ ? $1 : '';
  my $mapped_script = $hit_maps->{$script};
  my $extra = '';
  if( $mapped_script ) {
    $script = $URL;
    $script =~s/(\w+)\?/$mapped_script\?/g;
    $mapped_script = ucfirst($mapped_script);
    $mapped_script =~s/view/View/;
    $extra = sprintf( ' [<a href="%s">%s</a>]' , $script, $mapped_script );
  }
  return sprintf qq(
<p><strong><a href="%s">%s</a></strong>%s<br />
  %s
</p>
<blockquote>%s</blockquote>

),
    CGI::escapeHTML( $hit->URL ), 
    $hit->field('title')->getHighlighted, $extra,
    $hit->field('description')->getHighlighted,
    join( '&nbsp;&nbsp; ',
      map { '<strong>'.CGI::escapeHTML( $_->name =~ /answergroup\.(.*)/?$1:$_->name ).'</strong>: '.
            $self->_render_hitcats( $_->children ) } $hit->groups );
}

sub _render_hitcats {
  my( $self, @cats ) = @_;
  my $out = '';
  foreach my $cat ( @cats ) {
    $out .= $cat->name."; ". $self->_render_hitcats( $cat->children );
  }
  return $out;
}

1;
