package Bio::EnsEMBL::GlyphSet::alignscalebar;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use POSIX qw(ceil floor);
use Sanger::Graphics::Glyph::Sprite;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use Data::Dumper;

sub init_label {
    my ($self) = @_;

    return if ($self->{strand} < 1);

    my $text =  $self->{'container'}->{_config_file_name_};

      my $label = new Sanger::Graphics::Glyph::Text({
	  'z'             => 10,
	  'x'             => -110,
	  'y'             => 2,
	  'text'      => "$text",	
	  'font'      => 'Small',
	  'absolutex'     => 1,
	  'absolutey' => 1,
      });


      $self->push($label);
      my $line = new Sanger::Graphics::Glyph::Rect({
	  'z' => 9,
	  'x' => -120,
	  'y' => 2,
	  'colour' => 'white', #'black',
	  'width' => 118,
	  'height' => 15,
	  'absolutex'     => 1,
	  'absolutewidth' => 1,
	  'absolutey'     => 1,
      });
      $self->push($line);
      return;

    return;
    my $compara = $self->{container}->{'compara'};
    my $species = $self->{container}->{'species'};
    if( $compara && $species ) {
	return if $self->strand < 0;
	if (0){
	my $label = new Sanger::Graphics::Glyph::Sprite({
	    'z'             => 10,
	    'x'             => -110,
	    'y'             => 0,
	    'sprite'        => lc($species),
	    'width'         => 100,
	    'height'        => 20,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	    'absolutey'     => 1,
	});
    }
	my $label = new Sanger::Graphics::Glyph::Text({
	    'z'             => 10,
	    'x'             => -110,
	    'y'             => 0,
	    'text'      => "$species",	
	    'font'      => 'Small',
	    'absolutex'     => 1,
	    'absolutey' => 1,
	});


	$self->push($label);
	my $line = new Sanger::Graphics::Glyph::Rect({
	    'z' => 9,
	    'x' => -120,
	    'y' => 0,
	    'colour' => 'white', #'black',
	    'width' => 118,
	    'height' => 15,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	    'absolutey'     => 1,
	});
	$self->push($line);
    } elsif( $species ) {
	my $label = new Sanger::Graphics::Glyph::Text({
	    'text'      => "$species",	
	    'font'      => 'Small',
	    'absolutey' => 1,
	});
	$self->label($label);
    }
}


sub _init {
    my ($self) = @_;
    #return unless ($self->strand() == -1);

    my $Config         = $self->{'config'};

    my $Container      = $self->{'container'};
    my $contig_strand  = $Container->can('strand') ? $Container->strand : 1;
    my $h              = 0;
    my $highlights     = $self->highlights();
    my $fontname       = "Tiny";
    my $fontwidth_bp   = $Config->texthelper->width($fontname),
    my ($fontwidth, $fontheight)       = $Config->texthelper->px2bp($fontname),
    my $black          = 'black';
    my $highlights     = join('|',$self->highlights());
    $highlights        = $highlights ? "&highlight=$highlights" : '';
    my $object = $Config->{_object};
    if( $self->{'config'}->{'compara'} ) { ## this is where we have to add in the other species....
	my $C = 0;
	foreach( @{ $self->{'config'}{'other_slices'}} ) {
	    if( $C!= $self->{'config'}->{'slice_number'} ) {
		if( $C ) {
		    if( $_->{'location'} ) {
			$highlights .= sprintf( "&s$C=%s&c$C=%s:%s:%s&w$C=%s", $_->{'species'}, 
						$_->{'location'}->seq_region_name, $_->{'location'}->centrepoint, $_->{'ori'}, $_->{'location'}->length );
		    } else {
			$highlights .= sprintf( "&s$C=%s", $_->{'species'} ); 
		    }
		} else {
		    $highlights .= sprintf( "&c=%s:%s:1&w=%s", 
					    $_->{'location'}->seq_region_name, $_->{'location'}->centrepoint, $_->{'location'}->length );
		}
	    }
	    $C++;
	}
    }
    my $REGISTER_LINE  = $Config->get('_settings','opt_lines');
    my $feature_colour = $Config->get('scalebar', 'col');
    my $subdivs        = $Config->get('scalebar', 'subdivs');
    my $max_num_divs   = $Config->get('scalebar', 'max_divisions') || 12;
    my $navigation     = $Config->get('scalebar', 'navigation');
    my $abbrev         = $Config->get('scalebar', 'abbrev');
    (my $param_string   = $Container->seq_region_name()) =~ s/\s/\_/g;

    
    my $species =  $Container->{_config_file_name_};

    my $aslink = $Config->get('align_species',$ENV{ENSEMBL_SPECIES});
    my ($spe, $type) = split('_compara_', $aslink);
    my ($psp, $ssp) = (lc($ENV{ENSEMBL_SPECIES}), lc($species));

    if ($type eq 'pairwise') {
	if ($ssp ne $psp) {
	    $aslink =~ s/^.+_compara/${psp}_compara/;
	}
    } else {
	$aslink =~ s/^.+_compara/${ssp}_compara/;
    }

#    warn(join('*', 'A',$species, $Container->{'compara'}, $aslink, $ssp, $psp));

    my $main_width     = $Config->get('_settings', 'main_vc_width');
    my $len            = $Container->length();

    my $global_start   = $contig_strand < 0 ? -$Container->end() : $Container->start();
    my $global_end     = $contig_strand < 0 ? -$Container->start() : $Container->end();

    my $mp = $Container->{slice_mapper_pairs};

    $self->align_interval($mp, $global_start, $global_end, 5) if($self->{strand} < 0);
    $self->align_interval($mp, $global_start, $global_end, 5) if($self->{strand} > 0);

    my( $major_unit, $minor_unit );

    if( $len <= 51 ) {
       $major_unit = 10;
       $minor_unit = 1; 
    } else {
       my $exponent = 10 ** int( log($len)/log(10) );
       my $mantissa  = $len / $exponent;
       if( $mantissa < 1.2 ) {
          $major_unit = $exponent / 10 ;
          $minor_unit = $major_unit / 5 ;
       } elsif( $mantissa < 2.5 ) {
          $major_unit = $exponent / 5 ;
          $minor_unit = $major_unit / 4 ;
       } elsif( $mantissa < 5 ) {
          $major_unit = $exponent / 2 ;
          $minor_unit = $major_unit / 5 ;
       } else {
          $major_unit = $exponent;
          $minor_unit = $major_unit / 5 ;
       }
#    warn("T:".join('*', $len, $exponent, $mantissa, $major_unit, $minor_unit));
    }

    ## Now lets draw these....

    
    my $start = floor( $global_start / $minor_unit ) * $minor_unit;
    my $filled = 1;
    my $last_text_X = -1e20;
    my $yc = $self->{strand} > 0 ? 0 : 17;
    if ($param_string eq $ENV{ENSEMBL_SPECIES}) {
	if ($self->{strand} < 0) {
	    $start = $global_end  +1;
	}
    } else {
	if ($self->{strand} > 0) {
	    $start = $global_end  +1;
	}
    }


    while( $start <= $global_end ) { 
      my $end       = $start + $minor_unit - 1;
      $filled = 1 - $filled;
      my $box_start = $start < $global_start ? $global_start -1 : $start;
      my $box_end   = $end   > $global_end   ? $global_end      : $end;
#      warn("Z:".join('*', $start, $box_start, $box_end));

      ## Draw the glyph for this box!
      my $t = new Sanger::Graphics::Glyph::Rect({
         'x'         => $box_start - $global_start, 
         'y'         => $yc,
         'width'     => abs( $box_end - $box_start + 1 ),
         'height'    => 3,
         ( $filled == 1 ? 'colour' : 'bordercolour' )  => 'black',
         'absolutey' => 1,
         'alt'       => 'xxx'
      });
#      if ($navigation eq 'on' && $Config->{'compara'} ne 'secondary' ){
      if ($navigation eq 'on'){
        ($t->{'href'},$t->{'zmenu'}) = $self->interval( $species, $aslink, $mp, $start, $end, $contig_strand, $global_start, $global_end-$global_start+1, $highlights);
      }

#      warn("T^($self->{strand} * $navigation * $Config->{'compara'}): $t->{'href'} *** $t->{'zmenu'}");

      $self->push($t);
      if($start == $box_start ) { # This is the end of the box!
        $self->join_tag( $t, "ruler_$start", 0, 0 , $start%$major_unit ? 'grey90' : 'grey80'  ) if($REGISTER_LINE && $Container->{compara} ne 'secondary');
      }
      if( ( $box_end==$global_end ) && !( ( $box_end+1) % $minor_unit ) ) {
        $self->join_tag( $t, "ruler_$end", 1, 0 , ($global_end+1)%$major_unit ? 'grey90' : 'grey80'  ) if($REGISTER_LINE &&  $Container->{compara} ne 'secondary');
      }

      unless( $box_start % $major_unit ) { ## Draw the major unit tick 
        $self->push(new Sanger::Graphics::Glyph::Rect({
            'x'         => $box_start - $global_start,
            'y'         => $yc, 
            'width'     => 0,
            'height'    => 5,
            'colour'    => 'black',
            'absolutey' => 1,
        }));
        my $LABEL = $minor_unit < 250 ? $object->thousandify($box_start * $contig_strand ): $self->bp_to_nearest_unit( $box_start * $contig_strand, 2 );
        if( $last_text_X + length($LABEL) * $fontwidth * 1.5 < $box_start ) {
          $self->push(new Sanger::Graphics::Glyph::Text({
            'x'         => $box_start - $global_start,
            'y'         => $yc - 9,
            'height'    => $fontheight,
            'font'      => $fontname,
            'colour'    => $feature_colour,
            'text'      => $LABEL,
            'absolutey' => 1,
          }));
          $last_text_X = $box_start;
        }
      } 
      $start += $minor_unit;
    }
    unless( ($global_end+1) % $major_unit ) { ## Draw the major unit tick 
      $self->push(new Sanger::Graphics::Glyph::Rect({
        'x'         => $global_end - $global_start + 1,
        'y'         => $yc,
        'width'     => 0,
        'height'    => 5,
        'colour'    => 'black',
        'absolutey' => 1,
      }));
  }


    if ($self->{strand} > 0 && $Container->{compara} ne 'primary') {
	my $line = new Sanger::Graphics::Glyph::Rect({
	    'x' => -120,
	    'y' => 0, # 22,
	    'colour' => 'black',
	    'width' => 20000,
	    'height' => 0,
	    'absolutex'     => 1,
	    'absolutewidth' => 1,
	    'absolutey'     => 1,
	});
      
	$self->push($line);
    }

}

sub align_interval {
    my $self = shift;
    my ($mp, $global_start, $global_end, $yc) = @_;

    my $Config          = $self->{'config'};
    my $pix_per_bp     = $Config->transform()->{'scalex'};
    my $last_end = -1;
    my $last_chr = -1;
    my $last_s2e = -1;
    my %colour_map = ();
    my %colour_map2 = ();
    my @colours2 = qw(antiquewhite3 brown gray rosybrown1 blue green red gray yellow);
#    my @colours = qw(seashell1 bisque1 azure1 );

    my @colours = qw(antiquewhite1 mistyrose1 burlywood1 khaki1 cornsilk1 lavenderblush1 lemonchiffon2 darkseagreen2  lightcyan1 papayawhip seashell1);

    foreach my $s (@$mp) {
#	warn("c2:".join('*', keys(%$s)));	
	my $s2 = $s->{slice};

	my $ss = $s->{start};
	my $sst = $s->{strand};
	my $se = $s->{end};

	my $s2s = $s2->{start};
	my $s2e = $s2->{end};
	my $s2st = $s2->{strand};
	my $s2t = $s2->{seq_region_name};

#	warn("S:". join('*', $ss, $se, $sst, $s2s, $s2e, $s2t, $s2st, $last_end));
	my $box_start = $ss;
	my $box_end   = $se;
	my $filled = $sst;
	my $s2l = abs($s2e - $s2s)+1;
	my $sl = abs($se - $ss)+1;

	my $zmenu = {
	    'caption' => "AlignSlice",
	    "01:Chromosome: $s2t" => "",
	    "05:Strand: $s2st" => "",
	    "10:Start: $s2s" => "", 
	    "15:End: $s2e" => "", 
	    "20:Length: $s2l" => '', 
	    "25:----------------" => '',
	    "30:Interval Start:$ss" => '', 
	    "35:Interval End: $se" => '', 
	    "40:Interval Length: $sl" => '', 
	};
    
	$colour_map{$s2t} or $colour_map{$s2t} = shift (@colours) || 'grey';
	$colour_map2{$s2t} or $colour_map2{$s2t} =  'darksalmon' ;#shift (@colours2) || 'grey';

#	warn("$box_start : $box_end");
	my $col2 = $colour_map2{$s2t};
	my $t = new Sanger::Graphics::Glyph::Rect({
	    'x'         => $box_start - $global_start, 
	    'y'         => $yc,
	    'width'     => abs( $box_end - $box_start + 1 ),
	    'height'    => 3,
	    ( $filled == 1 ? 'colour' : 'bordercolour' )  => $col2,
	    'absolutey' => 1,
	    'alt'       => 'xxx', 
	    'zmenu' => $zmenu
	    });

	$self->push($t);

	my $col = $colour_map{$s2t};

	if ($self->{strand} < 0) {
	    $self->join_tag( $t, "alignslice_${box_start}", 0,0, $col, 'fill', -40 );
	    $self->join_tag( $t, "alignslice_${box_start}", 1,0, $col, 'fill', -40 );
	} else {
	    $self->join_tag( $t, "alignslice_${box_start}", 1,1, $col, 'fill', -40 );
	    $self->join_tag( $t, "alignslice_${box_start}", 0,1, $col, 'fill', -40 );
	}

	if (($last_chr == $s2t) && ($last_end == $ss - 1)) {
	    my $s3l = abs($s2s - $last_s2e);
	    my $zmenu2 = {
		'caption' => "AlignSlice Break",
		"00:Info: There is a gap in the original slice"=>"",
		"01:Chromosome: $s2t" => "",
		"02:Length: $s3l" => ""
	    };

	    my $xc = $box_start - $global_start;
	    my $h = $yc - 2;
	    
	    $self->push( new Sanger::Graphics::Glyph::Poly({
		'points'    => [ $xc - 2/$pix_per_bp, $h,
				 $xc, $h+6,
				 $xc+ 2/$pix_per_bp, $h  ],
		'colour'    => 'red',
		'absolutey' => 1,
		'zmenu' => $zmenu2
	    }));
	}
	$last_end = $se;
	$last_s2e = $s2e;
	$last_chr = $s2t;
    }

}

sub real_location {
    my ($self, $mpairs, $coord) = @_;
#    warn("FIND $coord");
    my ($chr, $x) = (0, 0);

    foreach my $region (@$mpairs) {
	if ($region->{start} <= $coord && $region->{end} >= $coord) {
	    my $slice = $region->{slice};
	    my $offset = ($slice->end - $slice->start) * $coord / ($region->{end} - $region->{start});
	    $x = $slice->start + int($offset);
	    $chr =  $slice->seq_region_name;
#	    warn("FOUND: ".join('*', $region->{start}, $region->{end}, $slice->seq_region_name, $slice->start, $slice->end, $slice->seq_region_length,  $offset, $x));
	    last;

	}
    }
    
    return ($chr, $x);
}
sub interval {
  # Add the recentering imagemap-only glyphs
  my ( $self, $species, $aslink, $mpairs, $start, $end, $contig_strand, $global_offset, $width, $highlights) = @_;
  my ($chr, $interval_middle) = $self->real_location($mpairs, $contig_strand * ($start+1));
 
  return if (!$chr);

  return( $self->zoom_URL($species, $aslink, $chr, $interval_middle, $width,  1  , $highlights, $self->{'config'}->{'slice_number'}, $contig_strand),
          $self->zoom_zmenu( $species, $aslink, $chr, $interval_middle, $width, $highlights, $self->{'config'}->{'slice_number'}, $contig_strand ) );
}

sub zoom_zmenu {
    my ($self, $species, $aslink, $chr, $interval_middle, $width, $highlights, $config_number, $ori ) = @_;
    $chr =~s/.*=//;

    $config_number or $config_number = 1;

    my $link = qq{/$species/$ENV{'ENSEMBL_SCRIPT'}?c=$chr:$interval_middle&w=$width&align=$aslink};
    my $zmenu = {
	'caption' => "Navigation",
	"10:Centre on this scale interval" => "$link", 

    };
		  
    return $zmenu;

    return qq(zn('/$species/$ENV{'ENSEMBL_SCRIPT'}', '$chr', '$interval_middle', '$width', '$highlights','$ori','$config_number', '@{[$self->{container}{_config_file_name_}]}' ));
}

sub zoom_URL {
  my( $self, $species, $aslink, $PART, $interval_middle, $width, $factor, $highlights, $config_number, $ori) = @_;
  my $extra = "";
#  warn("URL: $species, $PART");
  if( $config_number ) {
    $extra = "o$config_number=c$config_number=$PART:$interval_middle:$ori&w$config_number=$width"; 
  } else {
    $extra = "c=$PART:$interval_middle&w=$width";
  }

  $extra .= "&align=$aslink";

  return qq(/$species/$ENV{'ENSEMBL_SCRIPT'}?$extra$highlights);
}

sub bp_to_nearest_unit_by_divs {
  my ($self,$bp,$divs) = @_;

  return $self->bp_to_nearest_unit($bp,0) if (!defined $divs);

  my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
  my $value = $divs / ( 10 ** ( $power_ranger * 3 ) ) ;

  my $dp = $value < 1 ? length ($value) - 2 : 0; # 2 for leading "0."
  return $self->bp_to_nearest_unit ($bp,$dp);
}

sub bp_to_nearest_unit {
  my ($self,$bp,$dp) = @_;
  $dp = 1 unless defined $dp;
   
  my @units = qw( bp Kb Mb Gb Tb );
  my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
  my $unit = $units[$power_ranger];

  my $value = int( $bp / ( 10 ** ( $power_ranger * 3 ) ) );
    
  $value = sprintf( "%.${dp}f", $bp / ( 10 ** ( $power_ranger * 3 ) ) ) if ($unit ne 'bp');      

  return "$value $unit";
}


1;
