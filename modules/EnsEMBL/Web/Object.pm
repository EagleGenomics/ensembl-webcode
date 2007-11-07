package EnsEMBL::Web::Object;

### Base object class - all Ensembl web objects are derived from this class,
### this class is derived from proxiable - as it is usually proxied through an
### {{EnsEMBL::Web::Proxy}} object to handle the dynamic multiple inheritance 
### functionality.

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Proxiable;
use EnsEMBL::Web::Document::Image;
use Bio::EnsEMBL::DrawableContainer;
use Bio::EnsEMBL::VDrawableContainer;

our @ISA =qw(EnsEMBL::Web::Proxiable);
 
sub EnsemblObject   {
### Deprecated
### Sets/gets the underlying Ensembl object wrapped by the web object
  my $self = shift;
  warn "EnsemblObject - TRY TO AVOID - THIS NEEDS TO BE REMOVED... Use Obj instead...";
  $self->{'data'}{'_object'}    = shift if @_;
  return $self->{'data'}{'_object'};
}

sub prefix {
  ### a
  my ($self, $value) = @_;
#  warn "PREFIX: $value";
  if ($value) {
    $self->{'prefix'} = $value;
  }
  return $self->{'prefix'};
}

sub Obj {
### a 
### Gets the underlying Ensembl object wrapped by the web object
  return $_[0]{'data'}{'_object'};
}

sub dataobj { 
### Deprecated
### a 
### Gets the underlying Ensembl object wrapped by the web object
  warn "dataobj - TRY TO AVOID - THIS NEEDS TO BE REMOVED... Use Obj instead...";
  return $_[0]->Obj;
}

sub highlights {
### a
### The highlights array is passed between web-requests to highlight selected items (e.g. Gene around
### which contigview had been rendered. If any data is passed this is stored in the highlights array
### and an arrayref of (unique) elements is returned.
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

sub highlights_string {
### Returns the highlights area as a | separated list for passing in URLs.
  return join '|', @{$_[0]->highlights};
}

sub mapview_link {
### Parameter $feature
### Returns name of seq_region $feature is on. If the passed features is
### on a "real chromosome" then this is encapsulated in a link to mapview.
  my( $self, $feature ) = @_;
  my $coords = $feature->coord_system_name; 
  my $name   = $feature->seq_region_name;
  my %real_chr = map { $_, 1 } @{$self->species_defs->ENSEMBL_CHROMOSOMES};
  
  return $real_chr{ $name } ?
    sprintf( '<a href="%s">%s</a>', $self->URL( 'script' => 'mapview', 'chr' => $name ), $name ) : 
    $name;
}

sub location_URL {
### Parameters: $feature, $script, $context
### Returns a link to a contigview style display, based on feature, with context
  my( $self, $feature, $script, $context ) = @_;
  my $name  = $feature->seq_region_name;
  my $start = $feature->start;
  my $end   = $feature->end;
     $script = $script||'contigview';
     $script = 'cytoview' if $script eq 'contigview' && $self->species_defs->NO_SEQUENCE;

  return $self->URL( 'script' => $script||'contigview', 'l'=>"$name:$start-$end", 'context' => $context || 0 );
}

sub      URL {
### (%params) Returns an absolute link to another script. %params hash is used as the parameters for the link.
### Note keys species and script are handled differently - as these are not passed as parameters but set the
### species and script name respectively in the URL
  my $self = shift; return $self->_URL( 0,@_ );
}

sub full_URL {
### Returns a full (http://...) link to another script. Wrapper around {{_URL}} function
  my $self = shift; return $self->_URL( 1,@_ );
}

sub _URL { 
### Returns either a full link or absolute link to a script
  my( $self, $full, %details ) = @_;
  my $URL  = $full ? $self->species_defs->ENSEMBL_BASE_URL : '';
     $URL .=  "/".(exists $details{'species'} ? $details{'species'} : $self->species);
     $URL .=  exists $details{'script'}  ? "/$details{'script'}"  : '';
  my $extra = join( ";", map { /^(script|species)$/ ? () : sprintf('%s=%s', $_, $details{$_}) } keys %details );
  $URL .= "?$extra" if $extra;
  return $URL;
}

sub seq_region_type_human_readable {
### Returns the type of seq_region in "human readable form" (in this case just first letter captialised)
  my $self = shift;
  unless( $self->can('seq_region_type') ) {
    $self->{'data'}->{'_drop_through_'} = 1;
    return;
  }
  return ucfirst( $self->seq_region_type );
}

sub seq_region_type_and_name {
### Returns the type/name of seq_region in human readable form - if the coord system type is part of the name this is dropped.
  my $self = shift;
  unless( $self->can('seq_region_name') ) {
    $self->{'data'}->{'_drop_through_'} = 1;
    return;
  }
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
  my $self = shift;
  my $image = EnsEMBL::Web::Document::Image->new( $self->species_defs );
     $image->drawable_container = Bio::EnsEMBL::DrawableContainer->new( @_ );
     $image->set_extra( $self );
     if ($self->prefix) {
       $image->prefix($self->prefix);
     }
  return $image;
}

sub new_vimage {
  my $self  = shift;
  my $image = EnsEMBL::Web::Document::Image->new( $self->species_defs );
     $image->drawable_container = Bio::EnsEMBL::VDrawableContainer->new( @_ );
     $image->set_extra( $self );
  return $image;
}

sub new_karyotype_image {
  my $self = shift;
  my $image = EnsEMBL::Web::Document::Image->new( $self->species_defs );
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
    foreach my $homology (@{$ha->fetch_all_by_Member_paired_species($qy_member, $paired_species, ['ENSEMBL_ORTHOLOGUES'])}){
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
  my( $self, $options ) = @_;
  my $ref = CGI::escape( $self->referer );
  my $URL = "/@{[$self->species]}/helpview?";
  my @params;
  while (my ($k, $v) = each (%$options)) {
    push @params, "$k=$v";
  } 
  push @params, "ref=$ref";
  $URL .= join(';', @params);
  return $URL;
}

sub _help_link {
  my( $self, $kw, $text ) = @_;
  return qq(<a href="javascript:open('@{[$self->_help_URL($kw)]}','helpview','width=750,height=550,resizable,scrollbars')">@{[ CGI::escapeHTML( $text )]}</a>);
}

sub getCoordinateSystem{
  my ($self, $cs) = @_;

  my $species = $self->species || $ENV{'ENSEMBL_SPECIES'};

  my %SpeciesMappings = (
    'Homo_sapiens' => { 'hgnc'         	=> 'HGNC ID' },
    'Mus_musculus' => { 'mgi' 		=> 'MGI Symbol',
                        'mgi_acc'       => 'MGI Accession ID' }
  );

  my %DASMapping = (
## Gene based entries...
    'ensembl_gene'                 => 'Ensembl Gene ID',
## Peptide based entries
    'ensembl_peptide'              => 'Ensembl Peptide ID',
    'ensembl_transcript'           => 'Ensembl Transcript ID',
    'uniprot/swissprot'            => 'UniProt/Swiss-Prot Name',
    'uniprot/swissprot_acc'        => 'UniProt/Swiss-Prot Acc',
    'uniprot/sptrembl'             => 'UniProt/TrEMBL',
    'entrezgene_acc'               => 'Entrez Gene ID',
    'ipi_acc'                      => 'IPI Accession',
    'ipi_id'                       => 'IPI ID',
## Additional species specific peptide based entries...
    %{ $SpeciesMappings{ $species } || {} },
## Sequence based entries
    'ensembl_location_chromosome'  => 'Ensembl Chromosome',
    'ensembl_location_supercontig' => 'Ensembl NT/Super Contig',
    'ensembl_location_clone'       => 'Ensembl Clone',
    'ensembl_location_group'       => 'Ensembl Group',
    'ensembl_location_contig'      => 'Ensembl Contig',
    'ensembl_location_scaffold'    => 'Ensembl Scaffold',
    'ensembl_location_toplevel'    => 'Ensembl Top Level',
#   'ensembl_location'             => 'Ensembl Location', ##Deprecated - use toplevel instead...
  );

  return  $cs ? ($DASMapping{$cs} || $cs) : # Either a single entry from the list if there is a param
                \%DASMapping;               # Or a hash reference if not....
}

=head2 get_DASCollection

  Arg [1]   : none
  Function  : PRIVATE: Lazy-loads the DASCollection object for this gene, translation or transcript
  Returntype: EnsEMBL::Web::DataFactory::DASCollectionFactory
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub get_DASCollection{
  my $self = shift;
  my $data = $self->__data;

  unless( $data->{_das_collection} ){
    my $dasfact = EnsEMBL::Web::Proxy::Factory->new( 'DASCollection', $self->__data );
    $dasfact->createObjects;
    if( $dasfact->has_a_problem ){
      my $prob = $dasfact->problem->[0];
      return;
    }

    $data->{_das_collection} = $dasfact->DataObjects->[0];

    foreach my $das( @{$data->{_das_collection}->Obj} ){
      if ($das->adaptor->active) {
        $self->DBConnection->add_DASFeatureFactory($das);
      }
    } 
  }
  return $data->{_das_collection};
}


sub alternative_object_from_factory {
### There may be occassions when a script needs to work with features of
### more than one type. in this case we create a new {{EnsEMBL::Web::Proxy::Factory}}
### object for the alternative data type and retrieves the data (based on the standard URL
### parameters for the new factory) attach it to the universal datahash {{__data}}

  my( $self,$type ) =@_;
  my $t_fact = EnsEMBL::Web::Proxy::Factory->new( $type, $self->__data );
  if( $t_fact->can( 'createObjects' ) ) {
    $t_fact->createObjects;
    $self->__data->{lc($type)} = $t_fact->DataObjects;
    $self->__data->{'objects'} = $t_fact->__data->{'objects'};
  }
}


1;
