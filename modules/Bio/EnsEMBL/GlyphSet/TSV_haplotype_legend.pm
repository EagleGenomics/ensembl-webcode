package Bio::EnsEMBL::GlyphSet::TSV_haplotype_legend;

use strict;
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
our @ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
  my ($self) = @_;
  my $Config        = $self->{'config'};
  return if( defined $Config->{'_no_label'} );
  $self->init_label_text( 'Haplotype legend' );
}

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);

  my $BOX_WIDTH     = 20;
  my $NO_OF_COLUMNS = 3;

  my $vc            = $self->{'container'};
  my $Config        = $self->{'config'};
  my $im_width      = $Config->image_width();
  my $type          = $Config->get('variaion_legend', 'src');

  my @colours;
  return unless $Config->{'TSV_haplotype_legend_features'};
  my %features = %{$Config->{'TSV_haplotype_legend_features'}};
  return unless %features;

  my ($x,$y) = (0,0);
  my( $fontname, $fontsize ) = $self->get_font_details( 'legend' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $th = $res[3];
  my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};

  my $FLAG = 0;
  foreach (sort { $features{$b}->{'priority'} <=> $features{$a}->{'priority'} } keys %features) {
    @colours = @{$features{$_}->{'legend'}};
    $y++ unless $x==0;
    $x=0;
    while( my ($legend, $colour) = splice @colours, 0, 2 ) {
      $FLAG = 1;
      my $tocolour='';
      ($tocolour,$colour) = ($1,$2) if $colour =~ /(.*):(.*)/;

      # Heterozygotes should be stripey
      my @stripes;
      if ($colour eq 'stripes') {
	my $Config        = $self->{'config'};
	my $conf_colours  = $Config->get('TSV_haplotype_legend','colours' );
	$colour = $conf_colours->{'SAME'}[0];
	@stripes = ( 'pattern'       => 'hatch_thick',
		     'patterncolour' => $conf_colours->{'DIFFERENT'}[0],
		   );
      }

      $self->push(new Sanger::Graphics::Glyph::Rect({
        'x'         => $im_width * $x/$NO_OF_COLUMNS,
        'y'         => $y * ( $th + 3 ) + 2,
        'width'     => $BOX_WIDTH,
        'height'    => $th-2,
        $tocolour.'colour'    => $colour,
        'absolutey' => 1,
        'absolutex' => 1,'absolutewidth'=>1,
	@stripes,
      }));
      $self->push(new Sanger::Graphics::Glyph::Text({
        'x'         => $im_width * $x/$NO_OF_COLUMNS + $BOX_WIDTH,
        'y'         => $y * ( $th + 3 ),
        'height'    => $th,
        'valign'    => 'center',
        'halign'    => 'left',
        'ptsize'    => $fontsize,
        'font'      => $fontname,
        'colour'    => 'black',
        'text'      => " $legend",
        'absolutey' => 1,
        'absolutex' => 1,'absolutewidth'=>1
      }));
      $x++;
      if($x==$NO_OF_COLUMNS) {
        $x=0;
        $y++;
      }
    }
  }
# Set up a separating line...
  my $rect = new Sanger::Graphics::Glyph::Rect({
    'x'         => 0,
    'y'         => 0,
    'width'     => $im_width,
    'height'    => 0,
    'colour'    => 'grey50',
    'absolutey' => 1,
    'absolutex' => 1,'absolutewidth'=>1,
  });
  $self->push($rect);
  unless( $FLAG ) {
    $self->errorTrack( "No SNPs in this panel" );
  }
}

1;
      
