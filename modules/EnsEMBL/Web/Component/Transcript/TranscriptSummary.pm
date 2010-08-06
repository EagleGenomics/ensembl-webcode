package EnsEMBL::Web::Component::Transcript::TranscriptSummary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use EnsEMBL::Web::Document::HTML::TwoCol;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $hub = $self->hub;
  my $table  = new EnsEMBL::Web::Document::HTML::TwoCol;
  my $sp     = $hub->species_defs->DISPLAY_NAME;

## add transcript stats
  my $exons     = @{ $object->Obj->get_all_Exons };
  my $basepairs = $object->thousandify( $object->Obj->seq->length );
  my $residues  = $object->Obj->translation ? $object->thousandify( $object->Obj->translation->length ): 0;

  my $HTML = "
	  <strong>Exons:</strong> $exons 
	  <strong>Transcript length:</strong> $basepairs bps";
  $HTML .= "
          <strong>Translation length:</strong> $residues residues" if $residues;
  $table->add_row('Statistics',
		  "<p>$HTML</p>",
		  1 );

## add CCDS info
  if(my @CCDS = grep { $_->dbname eq 'CCDS' } @{$object->Obj->get_all_DBLinks} ) {
    my %T = map { $_->primary_id,1 } @CCDS;
     @CCDS = sort keys %T;
     $table->add_row('CCDS',
		     "<p>This transcript is a member of the $sp CCDS set: @{[join ', ', map {$object->get_ExtURL_link($_,'CCDS', $_)} @CCDS] }</p>",
		     1, );
  }

  my $db    = $object->get_db ;

## add some Vega info
  if ($db eq 'vega') {
    # class
    my $class = $object->transcript_class;
    $table->add_row('Class',
		    qq(<p>$class [<a href="http://vega.sanger.ac.uk/info/about/gene_and_transcript_types.html" target="external">Definition</a>]</p>),
		    1);
    # date
    my $version = $object->version;
    my $c_date = $object->created_date;
    my $m_date = $object->mod_date;
    $table->add_row('Version & date',
		    qq(<p>Version $version</p><p>Modified on $m_date (<span class="small">Created on $c_date</span>)<span></p>),
		    1);
    # author
    my $auth  = $object->get_author_name;
    $table->add_row('Author',
		    "This transcript was annotated by $auth");
  }

## type for core genes
  else {
    my $type = $object->transcript_type;
    $table->add_row('Type',$type) if $type;
  }
  ## add prediction method
  my $label = ( ($db eq 'vega' or $object->species_defs->ENSEMBL_SITETYPE eq 'Vega') ? 'Curation' : 'Prediction' ).' Method';
  my $text  = "No $label defined in database";
  my $o     = $object->Obj;
  eval {
    if( $o && $o->can( 'analysis' ) && $o->analysis && $o->analysis->description ) {
      $text = $o->analysis->description;
    } elsif( $object->can('gene') && $object->gene->can('analysis') && $object->gene->analysis && $object->gene->analysis->description ) {
      $text = $object->gene->analysis->description;
    } else {
      my $logic_name = $o->can('analysis') && $o->analysis ? $o->analysis->logic_name : '';
      if( $logic_name ){
        my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($logic_name);
        $text = "<strong>FROM CONFIG:</strong> ".$object->species_defs->$confkey;
      }
      if( ! $text ){
        my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($db);
        $text   = "<strong>FROM DEFAULT CONFIG:</strong> ".$object->species_defs->$confkey;
      }
    }
  };
  $table->add_row($label,
		  $text,
		  1 );

  ## add alternative transcript info
  my $temp =  $self->_matches( 'alternative_transcripts', 'Alternative transcripts', 'ALT_TRANS' );
  if ($temp) {
    $table->add_row('Alternative transcripts',
		    "<p>$temp</p>",
		    1 );
  }
  ## add frameshift introns info
  my $frameshift_introns = $object->get_frameshift_introns;
  if ($frameshift_introns){
    $table->add_row('Frameshift introns',
        '<p>'.$self->glossary_mouseover('Frameshift intron', 'Frameshift introns').' occur at intron number(s)  '. $frameshift_introns.'.</p>',  
        1 );
  }

  ## add stop gained/lost variation info
  my @attrib_codes= ('StopLost','StopGained');
  my $codons;
  foreach my $code (@attrib_codes) {
    my $transcript_attribs = $object->Obj->get_all_Attributes($code);
    my $description;

    #find which populations are affected by each snp (rsid)
    my %unique;
    foreach my $transc_att (@{$transcript_attribs}) {
      my ($rsid,$pop) = split(/,/, $transc_att->value());
      $unique{$rsid}{$pop} = 1;
    }

    # print the popukations for each rsid
    foreach my $id (keys %unique) {
      my $population_string = join(", ", keys %{$unique{$id}});
      my $link = $object->_url({
        'type'    => 'Variation',
        'action'  => 'Summary',
        'v'       => $id,
      }); 
      my $id_link = "<a href=$link>$id</a>"; 
      if ($code eq 'StopLost') {
        $description = "This transcript has a variant, $id_link, that causes a stop codon ".
                      "to be lost in at least 10% of HapMap population(s) $population_string.";
      } elsif ($code eq 'StopGained') {
        $description = "This transcript has a variant, $id_link, that causes a stop codon ".
                      "to be gained in at least 10% of HapMap population(s) $population_string.";
      } 
      $codons .= $description ."<br />";
    }
  }
  if ($codons =~/^\w/){
    $table->add_row('Stop codons',
      "<p>$codons</p>",
      1
    );  
  }
  return $table->render;
}

1;

