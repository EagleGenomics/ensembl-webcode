package Bio::EnsEMBL::GlyphSet::contig;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

use constant MAX_VIEWABLE_ASSEMBLY_SIZE => 5e6;

sub _init {
  my ($self) = @_;
  # only draw contigs once - on one strand
   
  if( $self->species_defs->NO_SEQUENCE ) {
    my $msg = "Clone map - no sequence to display";
    $self->errorTrack($msg);
    return;
  }

  my $Container = $self->{'container'};
  $self->{'vc'} = $Container;
  my $length = $Container->length();
  my $module = ref($self);
     $module = $1 if $module=~/::([^:]+)$/;

  my $gline = $self->Rect({
    'x'         => 0,
    'y'         => 0,
    'width'     => $length,
    'height'    => 0,
    'colour'    => 'grey50',
    'absolutey' => 1,
  });
  $self->push($gline);

  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $h = $res[3];
  my $box_h = $self->my_config('h');
  if( !$box_h ) {
    $box_h = $h + 4;
  } elsif( $box_h < $h + 4 ) {
    $h = 0;
  }

  my $pix_per_bp = $self->scalex;

  my $gline = $self->Rect({
    'x'         => 0,
    'y'         => $box_h,
    'width'     => $length,
    'height'    => 0,
    'colour'    => 'grey50',
    'absolutey' => 1,
  });
  $self->push($gline);
  
  my @features = ();
  my @segments = ();

  @segments = @{$Container->project('seqlevel')||[]};

  my @coord_systems;
  if ( ! $Container->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice") && ($Container->{__type__} ne 'alignslice')) {
    @coord_systems = @{$Container->adaptor->db->get_CoordSystemAdaptor->fetch_all() || []};
  }

  my $threshold_navigation = ($self->my_config('threshold_navigation')|| 2e6)*1001;
  my $navigation           = $self->my_config( 'navigation') || 'on';
  my $show_navigation = ($length < $threshold_navigation) && ($navigation eq 'on');

  foreach my $segment (@segments) {
    my $start      = $segment->from_start;
    my $end        = $segment->from_end;
    my $ctg_slice  = $segment->to_Slice;
    my $ORI        = $ctg_slice->strand;
    my $feature = { 'start' => $start, 'end' => $end, 'name' => $ctg_slice->seq_region_name };
    if ($ctg_slice->coord_system->name eq "ancestralsegment") {
      ## This is a Slice of Ancestral sequences: display the tree instead of the ID
      $feature->{'name'} = $ctg_slice->{_tree};
    }

      $feature->{'locations'}{ $ctg_slice->coord_system->name } = [ $ctg_slice->seq_region_name, $ctg_slice->start, $ctg_slice->end, $ctg_slice->strand  ];

      #is it a haplotype contig ?
      my ($hap_name) = @{$ctg_slice->get_all_Attributes('hap_contig')};
      $feature->{'haplotype_contig'} = $hap_name->{'value'} if $hap_name;

      if( $show_navigation ) {
          if ( ! $Container->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice") && ($Container->{__type__} ne 'alignslice')) {
              foreach( @coord_systems ) {
                  my $path;
                  eval { $path = $ctg_slice->project($_->name); };
                  next unless $path;
                  next unless(@$path == 1);
                  $path = $path->[0]->to_Slice;
                  # get clone id out of seq_region_attrib for link to webFPC 
                  if ($_->{'name'} eq 'clone') {
                      my ($clone_name) = @{$path->get_all_Attributes('fpc_clone_id')};
                      $feature->{'internal_name'} = $clone_name->{'value'} if $clone_name;;
                  }

                  $feature->{'locations'}{$_->name} = [ $path->seq_region_name, $path->start, $path->end, $path->strand ];
              }
          }
      }
      $feature->{'ori'} = $ORI;
      push @features, $feature;
  }
  
  if( @features) {
      $self->_init_non_assembled_contig($h,$box_h,$fontname,$fontsize,\@features);
  } else {
      my $msg = "Golden path gap - no contigs to display!";
      if ($Container->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice") && $Container->{compara} ne 'primary') {
          $msg = "Alignment gap - no contigs to display!";
      }
      $self->errorTrack($msg);
  }
}

sub _init_non_assembled_contig {
  my ($self, $h, $box_h, $fontname, $fontsize, $contig_tiling_path) = @_;
  my $Container = $self->{'vc'};
  my $length = $Container->length();
  my $ch = $Container->seq_region_name;

  my $pix_per_bp = $self->scalex;

  my $module               = ref($self);
     $module               = $1 if $module=~/::([^:]+)$/;
  my $threshold_navigation = ($self->my_config( 'threshold_navigation')|| 2e6)*1001;
  my $navigation           = $self->my_config( 'navigation') || 'on';
  my $show_navigation      = ($length < $threshold_navigation) && ($navigation eq 'on');
  my $show_href            = ($length < 1e8 ) && ($navigation eq 'on');

########
# Vars used only for scale drawing
#
  my $black    = 'black';
  my $red      = 'red';
  my $highlights = join('|', $self->highlights());
     $highlights = $highlights ? ";highlight=$highlights" : '';
  if( $self->{'config'}->{'compara'} ) { ## this is where we have to add in the other species....
    my $C = 0;
    foreach( @{ $self->{'config'}{'other_slices'}} ) {
      if( $C!= $self->{'config'}->{'slice_number'} ) {
        if( $C ) {
          if( $_->{'location'} ) {
            $highlights .= sprintf( ";s$C=%s;c$C=%s:%s:%s;w$C=%s", $_->{'location'}->species,
                         $_->{'location'}->seq_region_name, $_->{'location'}->centrepoint, $_->{'ori'}, $_->{'location'}->length );
          } else {
            $highlights .= sprintf( ";s$C=%s", $_->{'species'} );
          }
        } else {
          $highlights .= sprintf( ";c=%s:%s:1;w=%s",
                       $_->{'location'}->seq_region_name, $_->{'location'}->centrepoint,
                       $_->{'location'}->length );
        }
      }
      $C++;
    }
 } ##

  my $contig_strand  = $Container->can('strand') ? $Container->strand : 1;
  my $clone_based    = $self->get_parameter( 'clone_based') eq 'yes';
  my $global_start   = $clone_based ? $self->get_parameter( 'clone_start') : $Container->start();
  my $global_end     = $global_start + $length - 1;
  my $im_width = $self->image_width();
#
########

#######
# Draw the Contig Tiling Path
#
  my $i = 1;
  my @colours  = ( [qw(contigblue1 contigblue2)] , [qw(lightgoldenrod1 lightgoldenrod3)] ) ;
  my @label_colours = qw(white black);

  foreach my $tile ( sort { $a->{'start'} <=> $b->{'start'} } @{$contig_tiling_path} ) {
    my $strand = $tile->{'ori'};
    my $rend   = $tile->{'end'};
    my $rstart = $tile->{'start'};

# AlignSlice segments can be on different strands - hence need to check if start & end need a swap

    ($rstart, $rend) = ($rend, $rstart) if $rstart > $rend ;
    my $rid    = $tile->{'name'};
    $rstart = 1 if $rstart < 1;
    $rend   = $length if $rend > $length;

    #if this is a haplotype contig then need a different pair of colours for the contigs
    my $i = 0;
    if( exists($tile->{'haplotype_contig'}) ) {
      $i = $tile->{'haplotype_contig'} ? 1 : 0;
    }

    my $action = 'View';#$ENV{'ENSEMBL_ACTION'};
    my $region = $tile->{'name'};
    my $dets = {
      'x'         => $rstart - 1,
      'y'         => 0,
      'width'     => $rend - $rstart+1,
      'height'    => $box_h,
      'colour'    => $colours[$i]->[0],
      'absolutey' => 1,
    };
    if ($show_navigation) {
      my $url = $self->_url({
	'type'     => 'Location',
	'action'   => $action,
	'region_n' => $region,
	'r'        => undef,
      });
      $dets->{'href'} = $url;
    }
    my $glyph = $self->Rect($dets);

    push @{$colours[$i]}, shift @{@colours[$i]};
    my $label = $tile->{'name'};

##This section will be usefull when we come to put vega on new web code, when the
##time comes put it in vega plugin and remove from here
#          my $species_sr7= $self->species_defs->SPECIES_COMMON_NAME;
#          if($species_sr7 eq 'Zebrafish'){
#            if($label=~/(.+\.\d+)\.\d+\.\d+/){
#              $label= $1;
#            }
#          }
#          (my $T=ucfirst($_))=~s/contig/Contig/g;
#add links to Ensembl and FPC (vega danio)
#          if( /clone/) {
#            my $ens_URL = $self->ID_URL('EGB_ENSEMBL', $name);
#            $glyph->{'zmenu'}{"$POS:View in Ensembl"} = $ens_URL if $ens_URL;
#            $POS++;
#            my $internal_clone_name = $tile->{'internal_name'};
#            my $fpc_URL = $self->ID_URL('FPC',$internal_clone_name); 
#            $glyph->{'zmenu'}{"$POS:View in WebFPC"} = $fpc_URL if $fpc_URL && $internal_clone_name;
#            $POS++;
#          }

    $self->push($glyph);

    if( $h ) {
      my @res = $self->get_text_width(
        ($rend-$rstart)*$pix_per_bp,
        $strand > 0 ? "$label >" : "< $label",
        $strand > 0 ? '>' : '<',
        'font'=>$fontname, 'ptsize' => $fontsize
      );
      if( $res[0] ) {
        $self->push($self->Text({
          'x'          => ($rend + $rstart - $res[2]/$pix_per_bp)/2,
          'height'     => $res[3],
          'width'      => $res[2]/$pix_per_bp,
          'textwidth'  => $res[2],
          'y'          => ($h-$res[3])/2,
          'font'       => $fontname,
          'ptsize'     => $fontsize,
          'colour'     => $label_colours[$i],
          'text'       => $res[0],
          'absolutey'  => 1,
        }));
      }
    }
  }
}



1;
