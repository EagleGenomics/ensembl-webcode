package EnsEMBL::Web::Factory::Gene;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects { 
  my $self = shift;
  my ($identifier, @fetch_calls, $geneobj);
  my $db        = $self->param('db')  || 'core'; 
     $db          = 'otherfeatures' if $db eq 'est';
  my $exonid    = $self->param('exon');

  # Get the 'central' database (core, est, vega)
  my $db_adaptor  = $self->database($db);
  unless ($db_adaptor){
    $self->problem( 'Fatal', 
		    'Database Error', 
		    "Could not connect to the $db database." ); 
    return ;
  }
	
  # Attach satellite databases
  if(0) {
  if( $self->species_defs->databases->{'ENSEMBL_DB'} ){
    my $adaptor  = $self->database('core');
    if( $adaptor ){ $db_adaptor->add_db_adaptor( 'core', $adaptor ) }
  }
  if( $self->species_defs->databases->{'ENSEMBL_OTHERFEATURES'} ){
    my $adaptor  = $self->database('otherfeatures');
    if( $adaptor ){ $db_adaptor->add_db_adaptor( 'otherfeatures', $adaptor ) }
  }
  if( $self->species_defs->databases->{'ENSEMBL_VEGA'} ){
    my $adaptor  = $self->database('vega');
    if( $adaptor ){ $db_adaptor->add_db_adaptor( 'vega', $adaptor ) }
  }
  if( $self->species_defs->databases->{'ENSEMBL_VARIATION'} ){
    my $adaptor  = $self->database('variation');
    if( $adaptor ){ $db_adaptor->add_db_adaptor( 'variation', $adaptor ) }
  }
  if( $self->species_defs->databases->{'ENSEMBL_ENSEMBL_VEGA'} ){
	my $adaptor  = $self->database('ensembl_vega');
    if( $adaptor ){ $db_adaptor->add_db_adaptor( 'core', $adaptor ) }
  }
  }
  my $adaptor = $db_adaptor->get_GeneAdaptor;
  my $KEY = 'gene';
  if( $identifier = $self->param( 'peptide' ) ){ 
    @fetch_calls = qw(fetch_by_Peptide_id fetch_by_transcript_stable_id);
  } elsif( $identifier = $self->param( 'transcript' ) ){ 
    @fetch_calls = qw(fetch_by_transcript_stable_id fetch_by_Peptide_id);
  } elsif( $identifier = $self->param( 'exon' ) ){ 
    @fetch_calls = qw(fetch_by_exon_stable_id);
  } elsif( $identifier = $self->param( 'gene' ) || $self->param( 'anchor1' ) ){
    $KEY = 'anchor1' unless $self->param('gene');
    @fetch_calls = qw(fetch_by_stable_id fetch_by_transcript_stable_id fetch_by_Peptide_id); 
  } else {
    $self->problem('fatal', 'Please enter a valid identifier',
		     "This view requires a gene, transcript or peptide 
                    identifier in the URL.")  ;
    return;
  }

  (my $T = $identifier) =~ s/^(\S+)\.\d*/$1/g ; # Strip versions
  (my $T2 = $identifier) =~ s/^(\S+?)(\d+)(\.\d*)?/$1.sprintf("%011d",$2)/eg ; # Strip versions
  foreach my $fetch_call(@fetch_calls) {  
    eval { $geneobj = $adaptor->$fetch_call($identifier) } unless $geneobj; 
    eval { $geneobj = $adaptor->$fetch_call($T2) } unless $geneobj;
    eval { $geneobj = $adaptor->$fetch_call($T) } unless $geneobj;
  }

  if(!$geneobj || $@) {
    $self->_archive( 'Gene', $KEY );
    return if( $self->has_a_problem );
    $self->_known_feature( 'Gene', $KEY );
    $self->clear_problems if $KEY eq 'anchor1';
    return ;    
  } elsif (defined $exonid ) {                
    eval { $geneobj = $adaptor->fetch_by_exon_stable_id($exonid); };
    eval { 
      (my $T = $exonid ) =~ s/^(\S+)\.\d*/$1/g;
      $geneobj = $adaptor->fetch_by_exon_stable_id($T) unless $geneobj; 
    };
  }

##  $self->param( 'gene',[ $geneobj->stable_id ] ); # Set gene param
  #warn( "FOO: ", $self->param( 'gene' ) );
  
  $self->DataObjects( EnsEMBL::Web::Proxy::Object->new( 'Gene', $geneobj, $self->__data ));
}

#----------------------------------------------------------------------

sub createGenesByDomain {
  my $self = shift;
  my $domain_id = shift || $self->param('domainentry');
  $self->DataObjects(
    map { EnsEMBL::Web::Proxy::Object->new( 'Gene', $_, $self->__data ) } 
    @{$self->database('core')->get_GeneAdaptor->fetch_all_by_domain( $domain_id )||[]}
  );
}

sub createGenesByFamily {
  my( $self, $family ) = @_;
  my $ga = $self->database( 'core' )->get_GeneAdaptor; 
  $self->DataObjects(
    map { EnsEMBL::Web::Proxy::Object->new( 'Gene', $_, $self->__data ) }   ## Store them
    grep { $_ }                                                             ## Filter any crap ones out!!!
    map { $ga->fetch_by_stable_id( $_->[0]->stable_id ) }                   ## Create Ensembl Genes of these...
    @{ $family->source_taxon( "ENSEMBLGENE", $family->taxonomy_id )||[] }   ## Get all Ensembl Gene members of Family
  );
}

sub geneSNPViewOptions {
  my $self = shift;
  $self->genericOptions( 'genesnpview_transcript', 'genesnpview', 'width', 'context' );
}
1;

