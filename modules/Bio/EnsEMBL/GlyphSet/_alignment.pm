package Bio::EnsEMBL::GlyphSet::_alignment;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

#==============================================================================
# The following functions can be over-riden if the class does require
# something diffirent - main one to be over-riden is probably the
# features call - as it will need to take different parameters...
#==============================================================================
sub _das_link {
## Returns the 'group' that a given feature belongs to. Features in the same
## group are linked together via an open rectangle. Can be subclassed.
  my $self = shift;
  return de_camel( $self->my_config('object_type') || 'dna_align_feature' );
}

sub feature_group {
  my( $self, $f ) = @_;
  return $f->hseqname;    ## For core features this is what the sequence name is...
}

sub feature_title {
  my( $self, $f,$db_name ) = @_;
  $db_name ||= 'External Feature';
  return "$db_name ".$f->hseqname;
}

sub features {
  my ($self) = @_;
  my $method      = 'get_all_'.( $self->my_config('object_type') || 'DnaAlignFeature' ).'s';
  my $db          = $self->my_config('db');
  my @logic_names = @{ $self->my_config( 'logicnames' )||[] };
  $self->timer_push( 'Initializing don', undef, 'fetch' );
  my @results = map { $self->{'container'}->$method($_,undef,$db)||() } @logic_names;
  $self->timer_push( 'Retrieved features', undef, 'fetch' );
  my %results = ( $self->my_config('name') => [@results] );
  return %results;
}

sub href {
### Links to /Location/Genome
  my( $self, $f ) = @_;
  my $r = $f->seq_region_name.':'.$f->seq_region_start.'-'.$f->seq_region_end;
  return $self->_url({
    'action' => 'Genome',
    'ftype'  => $self->my_config('object_type') || 'DnaAlignFeature',
    'r'      => $r,
    'id'     => $f->display_id,
    'db'     => $self->my_config('db'),
  });
}

#==============================================================================
# Next we have the _init function which chooses how to render the
# features...
#==============================================================================

sub render_unlimited {
  my $self = shift;
  $self->render_normal( 1, 1000 );
}

sub render_stack {
  my $self = shift;
  $self->render_normal( 1, 40 );
}

sub render_half_height {
  my $self = shift;
  $self->render_normal( $self->my_config('height')/2 || 4);
}

sub colour_key {
  my( $self, $feature_key ) = @_;
  return $self->my_config( 'sub_type' );
}
sub render_normal {
  my $self = shift;
  my $tfh    = $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'});
  my $h      = @_ ? shift : ($self->my_config('height') || 8);
  my $dep    = @_ ? shift : ($self->my_config('dep'   ) || 6);
  my $gap    = $h<2 ? 1 : 2;   
## Information about the container...
  my $strand = $self->strand;
  my $strand_flag    = $self->my_config('strand');

  my $length = $self->{'container'}->length();
## And now about the drawing configuration
  my $pix_per_bp     = $self->scalex;
  my $DRAW_CIGAR     = ( $self->my_config('force_cigar') eq 'yes' )|| ($pix_per_bp > 0.2) ;
## Highlights...
  my %highlights = map { $_,1 } $self->highlights;
  my $hi_colour = 'highlight1';

  if( $self->{'extras'} && $self->{'extras'}{'height'} ) {
    $h = $self->{'extras'}{'height'};
  }

## Get array of features and push them into the id hash...
  my %features = $self->features;

  #get details of external_db - currently only retrieved from core since they should be all the same
  my $db = 'DATABASE_CORE';
#  my $db = 'DATABASE_'.uc($self->my_config('db'));
  my $extdbs = $self->species_defs->databases->{$db}{'tables'}{'external_db'}{'entries'};

  my $y_offset = 0;

  my $features_drawn = 0;
  my $features_bumped = 0;
  foreach my $feature_key ( $strand < 0 ? sort keys %features : reverse sort keys %features ) {
    $self->_init_bump( undef, $dep );
    my %id             = ();
    $self->{'track_key'} = $feature_key;
    foreach my $features ( @{$features{$feature_key}} ) {
      foreach my $f (
        map { $_->[2] }
        sort{ $a->[0] <=> $b->[0] }
        map { [$_->start,$_->end, $_ ] }
        @{$features || []}
      ){
        my $hstrand  = $f->can('hstrand')  ? $f->hstrand : 1;
        my $fgroup_name = $self->feature_group( $f );
        my $s =$f->start;
        my $e =$f->end;
        my $db_name = $f->can('external_db_id') ? $extdbs->{$f->external_db_id}{'db_name'} : 'OLIGO';
        next if $strand_flag eq 'b' && $strand != ( ($hstrand||1)*$f->strand || -1 ) || $e < 1 || $s > $length ;
        push @{$id{$fgroup_name}}, [$s,$e,$f,int($s*$pix_per_bp),int($e*$pix_per_bp),$db_name];
      }
    }
## Now go through each feature in turn, drawing them
    my $y_pos;
    my $colour_key     = $self->colour_key( $feature_key );
    my $feature_colour = $self->my_colour( $self->my_config( 'sub_type' ), undef  );
    my $join_colour    = $self->my_colour( $self->my_config( 'sub_type' ), 'join' );
  
    my $regexp = $pix_per_bp > 0.1 ? '\dI' : ( $pix_per_bp > 0.01 ? '\d\dI' : '\d\d\dI' );
  
    foreach my $i ( sort {
      $id{$a}[0][3] <=> $id{$b}[0][3]  ||
      $id{$b}[-1][4] <=> $id{$a}[-1][4]
    } keys %id){
      my @F          = @{$id{$i}}; # sort { $a->[0] <=> $b->[0] } @{$id{$i}};
      my $START      = $F[0][0] < 1 ? 1 : $F[0][0];
      my $END        = $F[-1][1] > $length ? $length : $F[-1][1];
      my $db_name    = $F[0][5];
      my $bump_start = int($START * $pix_per_bp) - 1;
      my $bump_end   = int($END * $pix_per_bp);
      my $row        = $self->bump_row( $bump_start, $bump_end );
      if( $row > $dep ) {
        $features_bumped++;
        next;
      }
      $y_pos = $y_offset - $row * int( $h + $gap ) * $strand;
  
      my $Composite = $self->Composite({
        'href'  => $self->href( $F[0][2] ),
        'x'     => $F[0][0]> 1 ? $F[0][0]-1 : 0,
        'width' => 0,
        'y'     => 0,
        'title' => $self->feature_title($F[0][2],$db_name)
      });
      my $X = -1e8;
      foreach my $f ( @F ){ ## Loop through each feature for this ID!
        my( $s, $e, $feat ) = @$f;
        next if int($e * $pix_per_bp) <= int( $X * $pix_per_bp );
        $features_drawn++;
        my $cigar;
        eval { $cigar = $feat->cigar_string; };
        if($DRAW_CIGAR || $cigar =~ /$regexp/ ) {
           my $START = $s < 1 ? 1 : $s;
           my $END   = $e > $length ? $length : $e;
           $X = $END;
           $Composite->push($self->Space({
             'x'          => $START-1,
             'y'          => 0, # $y_pos,
             'width'      => $END-$START+1,
             'height'     => $h,
             'absolutey'  => 1,
          }));
          $self->draw_cigar_feature($Composite, $feat, $h, $feature_colour, 'black', $pix_per_bp, $strand_flag eq 'r'  );
        } else {
          my $START = $s < 1 ? 1 : $s;
          my $END   = $e > $length ? $length : $e;
          $X = $END;
          $Composite->push($self->Rect({
            'x'          => $START-1,
            'y'          => 0, # $y_pos,
            'width'      => $END-$START+1,
            'height'     => $h,
            'colour'     => $feature_colour,
            'absolutey'  => 1,
          }));
        }
      }
      if( $h > 1 ) {
        $Composite->bordercolour($feature_colour);
      } else {
        $Composite->unshift( $self->Rect({
          'x'         => $Composite->{'x'},
          'y'         => $Composite->{'y'},
        	'width'     => $Composite->{'width'},
        	'height'    => $h,
        	'colour'    => $join_colour,
        	'absolutey' => 1
        }));
      }
      $Composite->y( $Composite->y + $y_pos );
      $self->push( $Composite );
      if(exists $highlights{$i}) {
        $self->unshift( $self->Rect({
          'x'         => $Composite->{'x'} - 1/$pix_per_bp,
          'y'         => $Composite->{'y'} - 1,
          'width'     => $Composite->{'width'} + 2/$pix_per_bp,
          'height'    => $h + 2,
          'colour'    => 'highlight1',
          'absolutey' => 1,
        }));
      }
    }
    $y_offset -= $strand * ( ($self->_max_bump_row + 1) * ( $h + $gap ) + 6 );
  }
  $self->errorTrack( "No features from '".$self->my_config('name')."' in this region" )
    unless( $features_drawn || $self->get_parameter( 'opt_empty_tracks')==0 );

  if( $self->get_parameter( 'opt_show_bumped') && $features_bumped ) {
    my $y_pos = $strand < 0
              ? $y_offset
              : 2 + $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'})
              ;
    $self->errorTrack( sprintf( q(%s features from '%s' omitted), $features_bumped, $self->my_config('name')), undef, $y_offset );
  }
  $self->timer_push( 'Features drawn' );
## No features show "empty track line" if option set....
}

sub render_ungrouped {
  my $self        = shift;
  my $strand      = $self->strand;
  my $strand_flag = $self->my_config('strand');

  my $length      = $self->{'container'}->length();
  my $pix_per_bp  = $self->scalex;
  my $DRAW_CIGAR  = ( $self->my_config('force_cigar') eq 'yes' )|| ($pix_per_bp > 0.2) ;
  my $h           = $self->my_config('height')||8;
  my $regexp = $pix_per_bp > 0.1 ? '\dI' : ( $pix_per_bp > 0.01 ? '\d\dI' : '\d\d\dI' );
  my $features_drawn = 0;
  my $X             = -1e8; ## used to optimize drawing!
  my $feature_colour = $self->my_colour( $self->my_config( 'sub_type') );

## Grab all the features;
## Remove those not on this display strand
## Create an array of arrayrefs [start,end,feature]
## Sort according to start of feature....

  my $y_offset = 0;

  my %features  = $self->features;
  foreach my $feature_key ( $strand < 0 ? sort keys %features : reverse sort keys %features ) {
    $self->{'track_key'} = $feature_key;
    foreach my $f (
      sort { $a->[0] <=> $b->[0]      }
      map  { [$_->start, $_->end,$_ ] }
      grep { !($strand_flag eq 'b' && $strand != ( ( $_->can('hstrand') ? 1 : 1 ) * $_->strand||-1) || $_->start > $length || $_->end < 1) } 
      map  { @$_                      } @{$features{$feature_key}}
    ) {
      my($start,$end,$feat) = @$f;
      ($start,$end)         = ($end, $start) if $end<$start; # Flip start end YUK!
      $start                = 1 if $start < 1;
      $end                  = $length if $end > $length;
      ### This is where we now grab the colours
      next if( $end * $pix_per_bp ) == int( $X * $pix_per_bp );
      $X                    = $start;
      $features_drawn++;
      my $cigar;
      eval { $cigar = $feat->cigar_string; };
      if($DRAW_CIGAR || $cigar =~ /$regexp/ ) {
        $self->draw_cigar_feature( $self, $feat, $h, $feature_colour, 'black', $pix_per_bp, $strand_flag eq 'r' );
      } else {
        $self->push($self->Rect({
          'x'          => $X-1,
          'y'          => $y_offset, # $y_pos,
          'width'      => $end-$X+1,
          'height'     => $h,
          'colour'     => $feature_colour,
          'absolutey'  => 1,
        }));
      }
    }
    $y_offset -= $strand * ($h+2);
  }
  $self->errorTrack( "No ".$self->my_config('name')." features in this region" )
    unless( $features_drawn || $self->get_parameter( 'opt_empty_tracks')==0 );
}

1;
