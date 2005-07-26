package EnsEMBL::Web::Object;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Proxiable;
use EnsEMBL::Web::Document::Image;
use Bio::EnsEMBL::DrawableContainer;
use Bio::EnsEMBL::VDrawableContainer;

our @ISA =qw(EnsEMBL::Web::Proxiable);
 
sub EnsemblObject   {
  my $self = shift;
  warn "EnsemblObject - TRY TO AVOID - THIS NEEDS TO BE REMOVED... Use Obj instead...";
  warn "@{[caller(0)]}";
  warn "@{[caller(1)]}";
  $self->{'data'}{'_object'}    = shift if @_;
  return $self->{'data'}{'_object'};
}

sub Obj {
  return $_[0]{'data'}{'_object'};
}

sub dataobj { 
  warn "dataobj - TRY TO AVOID - THIS NEEDS TO BE REMOVED... Use Obj instead...";
  return $_[0]->Obj;
}

sub highlights {
  my $self = shift;
  unless( exists( $self->{'data'}{'_highlights'}) ) {
    my @highlights = $self->param('h');
    push @highlights, $self->param('highlights');
    my %highlights = map { ($_ =~ /^(URL|BLAST_NEW):/ ? $_ : lc($_)) =>1 } grep {$_} map { split /\|/, $_ } @highlights;
    $self->{'data'}{'_highlights'} = [grep {$_} keys %highlights];
  }
  if( @_ ) {
    my %highlights = map { ($_ =~ /^(URL|BLAST_NEW):/ ? $_ : lc($_)) =>1 } @{$self->{'data'}{'_highlights'}||[]}, map { split /\|/, $_ } @_;
    $self->{'data'}{'_highlights'} = [grep {$_} keys %highlights];
  }
  return $self->{'data'}{'_highlights'};
}

sub highlights_string { return join '|', @{$_[0]->highlights}; }

## Object support functions...

sub mapview_link {
  my( $self, $feature ) = @_;
  my $coords = $feature->coord_system_name; 
  my $name   = $feature->seq_region_name;
  my %real_chr = map { $_, 1 } @{$self->species_defs->ENSEMBL_CHROMOSOMES};
  
  return $real_chr{ $name } ?
    sprintf( '<a href="%s">%s</a>', $self->URL( 'script' => 'mapview', 'chr' => $name ), $name ) : 
    $name;
}

sub location_URL {
  my( $self, $feature, $script, $context ) = @_;
  my $name  = $feature->seq_region_name;
  my $start = $feature->start;
  my $end   = $feature->end;
  return $self->URL( 'script' => $script||'contigview', 'l'=>"$name:$start-$end", 'context' => $context || 0 );
}

sub      URL { my $self = shift; return $self->_URL( 0,@_ ); }
sub full_URL { my $self = shift; return $self->_URL( 1,@_ ); }

sub _URL { 
  my( $self, $full, %details ) = @_;
  my $URL = '';
  if( $full ) {
    $URL = sprintf "%s://%s%s", $self->species_defs->ENSEMBL_PROTOCOL, $self->species_defs->ENSEMBL_SERVERNAME,
                   ($self->species_defs->ENSEMBL_PROXY_PORT ne 80 ? ":".$self->species_defs->ENSEMBL_PROXY_PORT : '' );
  }
  my $SPECIES = $ENV{'ENSEMBL_SPECIES'}; $SPECIES = $details{'species'} if exists $details{'species'};
  my $SCRIPT  = '';                      $SCRIPT  = $details{'script'}  if exists $details{'script'};

 
  $URL .=  "/".(exists $details{'species'} ? $details{'species'} : $self->species);
  $URL .=  exists $details{'script'}  ? "/$details{'script'}"  : '';
  my $extra = join( ";", map { /^(script|species)$/ ? () : sprintf('%s=%s', $_, $details{$_}) } keys %details );
  $URL .= "?$extra" if $extra;
  return $URL;
}

sub seq_region_type_human_readable { return ucfirst( $_[0]->seq_region_type ); }

sub seq_region_type_and_name {
  my $self = shift;
  my $coord = $self->seq_region_type_human_readable;
  my $name  = $self->seq_region_name;
  if( $name =~/^$coord/i ) {
    return $name;
  } else {
    return "$coord $name";
  }
}

sub generate_query_url {
  my $self = shift;
  my $q_hash = $self->generate_query_hash;
  return join ';', map { "$_=$q_hash->{$_}" } keys %$q_hash;
}

sub new_image {
  my $self  = shift;
  my $image = EnsEMBL::Web::Document::Image->new();
     $image->drawable_container = Bio::EnsEMBL::DrawableContainer->new( @_ );
     $image->set_extra( $self );
  return $image;
}

sub new_vimage {
  my $self  = shift;
  my $image = EnsEMBL::Web::Document::Image->new();
     $image->drawable_container = Bio::EnsEMBL::VDrawableContainer->new( @_ );
     $image->set_extra( $self );
  return $image;
}

sub new_karyotype_image {
  my $self = shift;
  my $image = EnsEMBL::Web::Document::Image->new();
     $image->set_extra( $self );
     $image->{'object'} = $self;
  return $image;
}

sub fetch_homologues_of_gene_in_species {
    my $self = shift;
    my ($gene_stable_id, $paired_species) = @_;
    return [] unless ($self->database('compara'));

    my $ma = $self->database('compara')->get_MemberAdaptor;
    my $qy_member = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$gene_stable_id);
    return [] unless (defined $qy_member); 

    my $ha = $self->database('compara')->get_HomologyAdaptor;
    my @homologues;
    foreach my $homology (@{$ha->fetch_by_Member_paired_species($qy_member, $paired_species)}){
      foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
        my ($member, $attribute) = @{$member_attribute};
        next if ($member->stable_id eq $qy_member->stable_id);
        push @homologues, $member;  
      }
    }    
    return \@homologues;
}

sub bp_to_nearest_unit {
    my $self = shift ;
    my ($bp,$dp) = @_;
    $dp = 2 unless defined $dp;
    
    my @units = qw( bp Kb Mb Gb Tb );
    
    my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
    my $unit = $units[$power_ranger];
    my $unit_str;

    my $value = int( $bp / ( 10 ** ( $power_ranger * 3 ) ) );
      
    if ( $unit ne "bp" ){
    $unit_str = sprintf( "%.${dp}f%s", $bp / ( 10 ** ( $power_ranger * 3 ) ), " $unit" );
    }else{
    $unit_str = "$value $unit";
    }
    return $unit_str;
}


sub referer { return $_[0]->param('ref')||$ENV{'HTTP_REFERER'}; }
sub _help_URL {
  my( $self, $kw ) = @_;
  my $ref = CGI::escape( $self->referer );
  return "/@{[$self->species]}/helpview?se=1;ref=$ref;kw=$kw";
}

sub _help_link {
  my( $self, $kw, $text ) = @_;
  return qq(<a href="javascript:open('@{[$self->_help_URL($kw)]}','helpview','width=750,height=550,resizable,scrollbars')">@{[ CGI::escapeHTML( $text )]}</a>);
}

1;
