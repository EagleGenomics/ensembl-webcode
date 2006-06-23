package Bio::EnsEMBL::GlyphSet::snp_fake;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Rect;
use Bio::EnsEMBL::GlyphSet;
  
@Bio::EnsEMBL::GlyphSet::snp_fake::ISA = qw(Bio::EnsEMBL::GlyphSet);
sub _init {
  my ($self) = @_;

  my $Config        = $self->{'config'};
  my $colours       = $Config->get('snp_fake','colours' );

  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'A', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $w = $res[2];
  my $th = $res[3];
  my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};
  my $snps = $Config->{'snps'};
  return unless ref $snps eq 'ARRAY';

  my $length    = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'}->length : $self->{'container'}->length;
  my $tag2 = $Config->get( 'snp_fake', 'tag' ) + ($self->strand == -1 ? 1 : 0);

  foreach my $snp_ref ( @$snps ) { 
    my $snp = $snp_ref->[2];
    my( $start,$end ) = ($snp_ref->[0], $snp_ref->[1] );
    $start = 1 if $start < 1;
    $end = $length if $end > $length;

    my $label = $snp->allele_string;
    my @alleles = split "\/", $label;
    my  $h = 4 + ($th+2) * scalar @alleles;

    my @res = $self->get_text_width( ($end-$start+1)*$pix_per_bp, $label, 'A', 'font'=>$fontname, 'ptsize' => $fontsize );
    if( $res[0] eq $label ) {
      $h = 8 + $th*2;
      my $tmp_width = ($w*2+$res[2]) / $pix_per_bp;
      if ( ($end - $start + 1) > $tmp_width ) {
	$start = ( $end + $start-$tmp_width )/2;
	$end =  $start+$tmp_width ;
      }
      my $textglyph = new Sanger::Graphics::Glyph::Text({
        'x'          => ( $end + $start - 1 )/2,
        'y'          => ($h-$th)/2,
        'width'      => 0,
        'height'     => $th,
        'font'       => $fontname,
        'ptsize'     => $fontsize,
        'colour'     => 'black',
        'text'       => $label,
        'absolutey'  => 1,
      });
      $self->push( $textglyph );
    } elsif( $res[0] eq 'X' && $label =~ /^[-\w](\/[-\w])+$/ ) {
      for (my $i = 0; $i < 3; $i ++ ) {
	my $textglyph = new Sanger::Graphics::Glyph::Text({
          'x'          => ( $end + $start - 1 )/2,
          'y'          => 3 + ($th+2) * $i,
          'width'      => 0,
          'height'     => $th,
        'font'       => $fontname,
        'ptsize'     => $fontsize,
          'colour'     => 'black',
          'text'       => $alleles[$i],
          'absolutey'  => 1,
							  });
	$self->push( $textglyph );
      }
    }
    my $type = $snp->get_consequence_type();
    my $colour = $colours->{$type}->[0];
    my $tglyph = new Sanger::Graphics::Glyph::Rect({
      'x' => $start-1,
      'y' => 0,
      'bordercolour' => $colour,
      'absolutey' => 1,
      'href' => $self->href($snp),
      'zmenu' => $self->zmenu($snp),
      'height' => $h,
      'width'  => $end-$start+1,
    });

    my $tag_root = $snp->dbID;
    $self->join_tag( $tglyph, "X:$tag_root=$tag2", .5, 0, $colour,'',-3 );
    $self->push( $tglyph );


    # Colour legend stuff
    unless($Config->{'variation_types'}{$type}) {
      push @{ $Config->{'variation_legend_features'}->{'variations'}->{'legend'}}, $colours->{$type}->[1],   $colours->{$type}->[0];
      $Config->{'variation_types'}{$type} = 1;
    }
  }
  push @{ $Config->{'variation_legend_features'}->{'variations'}->{'legend'}}, $colours->{"SARA"}->[1],   $colours->{"SARA"}->[0];
}

sub zmenu {
    my ($self, $f ) = @_;
    my $start = $f->start() + $self->{'container'}->start() - 1;
    my $end   = $f->end() + $self->{'container'}->start() - 1;

    my $allele = $f->allele_string;
    my $pos =  $start;
    if($f->{'range_type'} eq 'between' ) {
       $pos = "between&nbsp;$start&nbsp;&amp;&nbsp;$end";
    } elsif($f->{'range_type'} ne 'exact' ) {
       $pos = "$start&nbsp;-&nbsp;$end";
   }
    my %zmenu = ( 
        'caption'           => "SNP: ".$f->variation_name(),
        '01:SNP properties' => $self->href( $f ),
        "02:bp: $pos" => '',
        "04:class: ".$f->var_class() => '',
        "03:status: ".join(', ', @{$f->get_all_validation_states||[]} ) => '',
        "06:mapweight: ".$f->map_weight => '',
        "05:ambiguity code: ".$f->ambig_code => '',
        "08:alleles: ".(length($allele)<16 ? $allele : substr($allele,0,14).'..') => '',
        "09:source: ".$f->source() => '',
   );

    my %links;
    
    my $source = $f->source; 
    my $type = $f->get_consequence_type;
    $zmenu{"57:type: $type"} = "" unless $type eq '';  
    return \%zmenu;
}

sub href {
    my ($self, $f ) = @_;
    my $start = $self->{'container'}->start()+$f->start;
    my $snp_id = $f->variation_name;
    my $source = $f->source;
    my $seq_region_name = $self->{'container'}->seq_region_name();

    return "/@{[$self->{container}{_config_file_name_}]}/snpview?snp=$snp_id;source=$source;chr=$seq_region_name;vc_start=$start";
}

1;
