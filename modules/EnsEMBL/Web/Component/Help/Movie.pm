package EnsEMBL::Web::Component::Help::Movie;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Data::Movie;
use EnsEMBL::Web::Document::SpreadSheet;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $html;

  my @movies;
  if ($object->param('id')) {
    my @ids = $object->param('id');
    foreach my $id (@ids) {
      push @movies, EnsEMBL::Web::Data::Movie->new($id);
    }
  }
  else {
    @movies = sort {$a->title cmp $b->title} EnsEMBL::Web::Data::Movie->find_all;
  }

  if (scalar(@movies) == 1) {
    my $movie = $movies[0];
    $html .= '<h3>'.$movie->title."</h3>";

    ## Embedded flash movie
    my $file = $movie->filename;
    $file =~ s/\.swf$//;
    my $movie_server = ''; # $object->species_defs->ENSEMBL_MOVIE_SERVER;
    my $path = $movie_server.'/flash/'.$file;
    $html .= sprintf(qq(
<embed type="application/x-shockwave-flash" src="%s_controller.swf" width="%s" height="%s" id="%s_controller.swf" name="%s_controller.swf" bgcolor="#FFFFFF" quality="best" flashvars="csConfigFile=%s_config.xml&csColor=FFFFFF&csPreloader=%s_preload.swf"/>

      ),
                $path, $movie->width, $movie->height, $file, $path, $path, $path);
  }
  elsif (scalar(@movies) > 0) {

    $html .= qq(<p>The tutorials listed below are Flash animations of some of our training presentations, with added popup notes in place of a soundtrack. We are gradually adding to the list, so please check back regularly (the list will also be included in the Release Email, which is sent to the <a href="/info/about/contact/mailing.html">ensembl-announce mailing list</a>).</p>
<p>Please note that files are around 3MB per minute, so if you are on a dialup connection, playback may be jerky.</p>);
 
    my $table = EnsEMBL::Web::Document::SpreadSheet->new();

    $table->add_columns(
      {'key' => "title", 'title' => 'Title', 'width' => '60%', 'align' => 'left' },
      {'key' => "mins", 'title' => 'Running time (minutes)', 'width' => '20%', 'align' => 'left' },
    );

    foreach my $movie (@movies) {

      my $title_link = sprintf(qq(<a href="/Help/Movie?id=%s" class="cp_internal">%s</a>\n), $movie->help_record_id, $movie->title);
      $table->add_row( { 'title'  => $title_link, 'mins' => $movie->length } );

    }
    $html .= $table->render;

  }

  return $html;
}

1;
