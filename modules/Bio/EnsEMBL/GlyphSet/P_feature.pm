package Bio::EnsEMBL::GlyphSet::P_feature;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );
  $self->label(new Sanger::Graphics::Glyph::Text({
    'text'    => $self->my_config('caption'),
    'font'    => 'Small',
    'absolutey' => 1,
  }));
}

sub _init {
  my ($self, $protein, $Config) = @_;
  my %hash;
  my $y      = 0;
  my $h      = 4;
  my $highlights = $self->highlights();

  return unless $self->check();
  $protein = $self->{'container'};
  $Config  = $self->{'config'}; 
  return unless $protein->dbID;
  my $logic_name    = $self->my_config( 'logic_name' );
  my $colours       = $self->my_config( 'colours'    )||{};
  my $caption       = $self->my_config('caption');
  my $colour        = $colours->{lc($logic_name)} || $colours->{'default'};

  foreach my $pf (@{$protein->get_all_ProteinFeatures($logic_name)}) {
    my $x = $pf->start();
    my $w = $pf->end - $x;
    $self->push(new Sanger::Graphics::Glyph::Rect({
      'x'       => $x,
      'y'       => $y,
      'width'   => $w,
      'height'  => $h,
      'zmenu' => {
         'caption' => "$caption Feature",
         "aa: ".$pf->start."-".$pf->end,
      },
      'title' => $pf->start.'-'.$pf->end,
      'colour'  => $colour,
    }));
  }
}
1;
