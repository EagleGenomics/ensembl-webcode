package EnsEMBL::Web::Component::Transcript;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;
our @ISA = qw( EnsEMBL::Web::Component);

use Data::Dumper;
use strict;
use warnings;
use Exporter;
use EnsEMBL::Web::Form;
our @EXPORT = qw(_sort_similarity_links);  ##dunno if this is needed
no warnings "uninitialized";

## No sub stable_id   <- uses Gene's stable_id
## No sub name        <- uses Gene's name
## No sub description <- uses Gene's description
## No sub location    <- uses Gene's location call

sub tn_external {
  my( $panel, $object ) = @_;
  my $DO = $object->Obj;
  my $data_type;
  my $URL_KEY;
  my $type      = $DO->analysis->logic_name;
  if( $type eq 'GID' ) {
    $data_type = 'GeneID';
    $URL_KEY   = 'TETRAODON_ABINITIO';
  } elsif( $type eq 'GSC' ) {
    $data_type = 'Genscan';
    $URL_KEY   = 'TETRAODON_ABINITIO';
  } else {
    $data_type = 'Genewise';
    $URL_KEY   = 'TETRAODON_GENEWISE';
  }
  $panel->add_row( 'External links',
    qq(<p><strong>$data_type:</strong> @{[$object->get_ExtURL_link( $DO->stable_id, $URL_KEY, $DO->stable_id )]}</p>)
  );
  return 1;
}
sub information {
  my( $panel, $object ) = @_;
  my $label = "Transcript information";
  my $exons     = @{ $object->Obj->get_all_Exons }; 
  my $basepairs = $object->thousandify( $object->Obj->seq->length );
  my $residues  = $object->Obj->translation ? $object->thousandify( $object->Obj->translation->length ): 0;
   
  my $HTML = "<p><strong>Exons:</strong> $exons <strong>Transcript length:</strong> $basepairs bps";
     $HTML .= " <strong>Translation length:</strong> $residues residues" if $residues;
     $HTML .="</p>\n";
  if( $object->gene ) {
     my $gene_id   = $object->gene->stable_id;
     $HTML .= qq(<p>This transcript is a product of gene: <a href="/@{[$object->species]}/geneview?gene=$gene_id;db=@{[$object->get_db]}">$gene_id</a></p>\n);
  }
  $panel->add_row( $label, $HTML );
  return 1;
}

sub additional_info {
  my( $panel, $object ) = @_;
  my $label = "Transcript information";
  my $exons     = @{ $object->Obj->get_all_Exons };
  my $basepairs = $object->thousandify( $object->Obj->seq->length );
  my $residues  = $object->Obj->translation ? $object->thousandify( $object->Obj->translation->length ): 0;
  my $gene_id   = $object->gene->stable_id;

  my $HTML = "<p><strong>Exons:</strong> $exons <strong>Transcript length:</strong> $basepairs bps";
     $HTML .= " <strong>Protein length:</strong> $residues residues" if $residues;
     $HTML .="</p>\n";
  my $species = $object->species();
  my $query_string = "transcript=@{[$object->stable_id]};db=@{[$object->get_db]}";
     $HTML .=qq(<p>[<a href="/$species/transview?$query_string">Further Transcript info</a>] [<a href="/$species/exonview?$query_string">Exon information</a>]);
  if( $residues ) {
     $HTML .=qq( [<a href="/$species/protview?$query_string">Protein information</a>]);
  }
     $HTML .=qq(</p>);
  $panel->add_row( $label, $HTML );
  return 1;
}


sub gkb {
  my( $panel, $transcript ) = @_;
  my $label = 'Genome KnowledgeBase';
  unless ($transcript->__data->{'links'}){
    my @similarity_links = @{$transcript->get_similarity_hash($transcript->Obj)};
    return unless (@similarity_links);
    _sort_similarity_links($transcript, @similarity_links);
  }
  return unless $transcript->__data->{'links'}{'gkb'};
  my $GKB_hash = $transcript->__data->{'links'}{'gkb'};

  my $html =  qq( <strong>The following identifiers have been mapped to this entry via Genome KnowledgeBase:</strong><br />);

  my $urls = $transcript->ExtURL;
  $html .= qq(<table cellpadding="4">);
  foreach my $db (sort keys %{$GKB_hash}){
    $html .= qq(<tr><th>$db</th><td><table>);
    foreach my $GKB (@{$GKB_hash->{$db}}){
      my $primary_id = $GKB->primary_id;
      my ($t, $display_id) = split ':', $primary_id ;
      my $description = $GKB->description;
      $html .= '<tr><td>'.$transcript->get_ExtURL_link( $display_id, 'GKB', $primary_id) .'</td>
        <td>'.$description.'</td>
      </tr>';
    }
    $html .= qq(</table></td></tr>)
  }
  $html .= qq(</table>);
  $panel->add_row( $label, $html );
}

sub go {
  my( $panel, $object ) = @_;
  my $label = 'GO';
  unless ($object->__data->{'links'}){
    my @similarity_links = @{$object->get_similarity_hash($object->Obj)};
    return unless (@similarity_links);
    _sort_similarity_links($object, @similarity_links);
  }
  return unless $object->__data->{'links'}{'go'};
  my $databases = $object->DBConnection;
  my $goview    = $object->database('go') ? 1 : 0;

  my $go_hash  = $object->get_go_list();
  my $GOIDURL  = "/@{[$object->species]}/goview?acc=";
  my $QUERYURL = "/@{[$object->species]}/goview?depth=2;query=";
  my $URLS     = $object->ExtURL;

  return unless ($go_hash);
  my $html =  qq(<dl>
  <dt><strong>The following GO terms have been mapped to this entry via UniProt and/or RefSeq:</strong></dt>);

  foreach my $go (sort keys %{$go_hash}){
    my @go_data = @{$go_hash->{$go}||[]};
    my( $evidence, $description, $info_text ) = @go_data;
    my $link_name = $description;
    $link_name =~ s/ /\+/g;

    my $goidurl  = qq(<a href="$GOIDURL$go">$go</a>);
    my $queryurl = qq(<a href="$QUERYURL$link_name">$description</a>);
    unless( $goview ){
      $goidurl  = $object->get_ExtURL_link($go,'GO',$go);
      $queryurl = $object->get_ExtURL_link($description,'GOTERMNAME', $link_name);
    }
    my $info_text_html;
    my $info_text_url;
    my $info_text_gene;
    my $info_text_species;
    my $info_text_common_name;
                my $info_text_type;
    if($info_text){
  #create URL
     if($info_text=~/from ([a-z]+[ _][a-z]+) (gene|translation) (\w+)/i){
        $info_text_gene= $3;
        $info_text_type= $2;
        $info_text_common_name= ucfirst($1);
      } else{
        #parse error
        warn "regex parse failure in EnsEMBL::Web::Component::Transcript::go()";
      }
      $info_text_species= $object->species;
      (my $species = $info_text_common_name) =~ s/ /_/g;
      my $script = $info_text_type eq 'gene' ? 'geneview?gene=' : 'protview?peptide=';
      $info_text_url= "<a href='/$species/$script$info_text_gene'>$info_text_gene</a>";
      $info_text_html= "[from $info_text_common_name $info_text_url]";
    }
    else{
      $info_text_html= '';
    }

  $html .= qq(<dd>$goidurl $info_text_html [$queryurl] <code>$evidence</code></dd>\n);
  }
  $html .= qq(</dl>);
  $panel->add_row( $label, $html );
}

sub alternative_transcripts {
  my( $panel, $transcript ) = @_;
  _matches( $panel, $transcript, 'alternative_transcripts', 'Alternate transcripts', 'ALT_TRANS' );
}

sub oligo_arrays {
  my( $panel, $transcript ) = @_;
  _matches( $panel, $transcript, 'oligo_arrays', 'Oligo Matches', 'ARRAY' );
}

sub literature {
  my( $panel, $transcript ) = @_;
  _matches( $panel, $transcript, 'literature', 'References', 'LIT' );
}

sub similarity_matches {
  my( $panel, $transcript ) = @_;
  _matches( $panel, $transcript, 'similarity_matches', 'Similarity Matches', 'PRIMARY_DB_SYNONYM', 'MISC' );
}

sub _flip_URL {
  my( $transcript, $code ) = @_;
  return sprintf '/%s/%s?transcript=%s;db=%s;%s', $transcript->species, $transcript->script, $transcript->stable_id, $transcript->get_db, $code;
}

sub _matches {
  my( $panel, $transcript, $key, $caption, @keys ) = @_;
  my $label = $transcript->species_defs->translate( $caption );
  my $trans = $transcript->transcript;
  # Check cache

  unless ($transcript->__data->{'links'}){
    my @similarity_links = @{$transcript->get_similarity_hash($trans)};
    return unless (@similarity_links);
    _sort_similarity_links($transcript, @similarity_links);
  }

  my $URL = _flip_URL( $transcript, "status_$key" );
  if( $transcript->param( "status_$key" ) eq 'off' ) { 
    $panel->add_row( $label, '', "$URL=on" );
    return 0;
  }

  my @links = map { @{$transcript->__data->{'links'}{$_}||[]} } @keys; 
  return unless @links;

  my $db = $transcript->get_db();
  my $entry = $transcript->gene_type || 'Ensembl';

  # add table call here
  my $html;
  if ($transcript->species_defs->ENSEMBL_SITETYPE eq 'Vega') {
    $html = qq(<p></p>);
  }
  else {
    $html = qq(<p><strong>This $entry entry corresponds to the following database identifiers:</strong></p>);
  }
  $html .= qq(<table cellpadding="4">);
  if( $keys[0] eq 'ALT_TRANS' ) {
    @links = &remove_redundant_xrefs(@links);
  }

  my $old_key = '';
  foreach my $link (@links) {
    my ( $key, $text ) = @$link;
    if( $key ne $old_key ) {
      if($old_key eq "GO") {
        $html .= qq(<div class="small">GO mapping is inherited from swissprot/sptrembl</div>);
      }
      if( $old_key ne '' ) {
        $html .= qq(</td></tr>);
      }
      $html .= qq(<tr><th style="white-space: nowrap; padding-right: 1em">$key:</th><td>);
      $old_key = $key;
    }
    $html .= $text;
  }
  $html .= qq(</td></tr></table>);
  $panel->add_row( $label, $html, "$URL=off" );
}

#this is temporarily needed to delete duplicated and redundant database entries
#used for both core and ensembl-vega databases
sub remove_redundant_xrefs {
	my (@links) = @_;
	my %priorities;
	foreach my $link (@links) {
		my ( $key, $text ) = @$link;
		if ($text =~ />OTT|>ENST/) {
			$priorities{$key} = $text;
		}
	}
	foreach my $type (
		'Transcript having exact match between ENSEMBL and HAVANA',
		'Ensembl transcript having exact match with Havana',
		'Havana transcript having same CDS',
		'Ensembl transcript sharing CDS with Havana',
		'Havana transcripts') {
		if ($priorities{$type}) {
			my @munged_links;
			$munged_links[0] = [ $type, $priorities{$type} ];
			return @munged_links;;
		}
	}
	return @links;
}

sub _sort_similarity_links{
  my $object = shift;
  my @similarity_links = @_;
  my $database = $object->database;
  my $db       = $object->get_db() ;
  my $urls     = $object->ExtURL;
  my @links ;
  my (%affy, %exdb);
  # @ice names    
  foreach my $type (sort {
    $b->priority        <=> $a->priority ||
    $a->db_display_name cmp $b->db_display_name || 
    $a->display_id      cmp $b->display_id
  } @similarity_links ) { 
    my $link = "";
    my $join_links = 0;
    my $externalDB = $type->database();
    my $display_id = $type->display_id();
    my $primary_id = $type->primary_id();
    next if ($type->status() eq 'ORTH');               # remove all orthologs   
    next if lc($externalDB) eq "medline";              # ditch medline entries - redundant as we also have pubmed
    next if ($externalDB =~ /^flybase/i && $display_id =~ /^CG/ ); # Ditch celera genes from FlyBase
    next if $externalDB eq "Vega_gene";                # remove internal links to self and transcripts
    next if $externalDB eq "Vega_transcript";
    next if $externalDB eq "Vega_translation";
    if( $externalDB eq "GO" ){
      push @{$object->__data->{'links'}{'go'}} , $display_id;
      next;   
    } elsif ($externalDB eq "GKB") {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$object->__data->{'links'}{'gkb'}->{$key}} , $type ;
      next;
    }
    my $text = $display_id;
    (my $A = $externalDB ) =~ s/_predicted//;
    if( $urls and $urls->is_linked( $A ) ) {
      my $link;
      $link = $urls->get_url( $A, $primary_id );

      my $word = $display_id;
      if( $A eq 'MARKERSYMBOL' ) {
        $word = "$display_id ($primary_id)";
      }
      if( $link ) {
        $text = qq(<a href="$link">$word</a>);
      } else {
        $text = qq($word);
      }
    }
#    warn $externalDB;
#    warn $type->db_display_name;
    if( $type->isa('Bio::EnsEMBL::IdentityXref') ) {
      $text .=' <span class="small"> [Target %id: '.$type->target_identity().'; Query %id: '.$type->query_identity().']</span>';            
      $join_links = 1;    
    }
    if( ( $object->species_defs->ENSEMBL_PFETCH_SERVER ) && 
      ( $externalDB =~/^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i ) ) {  
      my $seq_arg = $display_id;
      $seq_arg = "LL_$seq_arg" if $externalDB eq "LocusLink";
      $text .= sprintf( ' [<a href="/%s/alignview?transcript=%s;sequence=%s;db=%s">align</a>] ',
                  $object->species, $object->stable_id, $seq_arg, $db );
    }
    if($externalDB =~/^(SWISS|SPTREMBL)/i) { # add Search GO link            
      $text .= ' [<a href="'.$urls->get_url('GOSEARCH',$primary_id).'">Search GO</a>]';
    }
    if( $type->description ) {
      ( my $D = $type->description ) =~ s/^"(.*)"$/\1/;
      $text .= "<br />".CGI::escapeHTML($D);
      $join_links = 1;    
    }
    if( $join_links  ) {
      $text = qq(\n  <div>$text</div>); 
    } else {
      $text = qq(\n  <div class="multicol">$text</div>); 
    }
    # override for Affys - we don't want to have to configure each type, and
    # this is an internal link anyway.
    if( $externalDB =~ /^AFFY_/i) {
      next if ($affy{$display_id} && $exdb{$type->db_display_name}); ## remove duplicates
      $text = "\n".'  <div class="multicol"><a href="' .$urls->get_url('AFFY_FASTAVIEW', $display_id) .'">'. $display_id. '</a></div>';
      $affy{$display_id}++;
      $exdb{$type->db_display_name}++;
    }
    push @{$object->__data->{'links'}{$type->type}}, [ $type->db_display_name || $externalDB, $text ] ;
#    warn $text;
  }
#  return $object->__data->{'similarity_links'};
}

sub family {
  my( $panel, $object ) = @_;
  my $pepdata  = $object->translation_object;
  return unless $pepdata;
  my $families = $pepdata->get_family_links($pepdata);
  return unless %$families;

  my $label = 'Protein Family';
  my $html;
  foreach my $family_id (keys %$families) {
    my $family_url   = "/@{[$object->species]}/familyview?family=$family_id";
    my $family_count = $families->{$family_id}{'count'};
    my $family_desc  = $families->{$family_id}{'description'};
    $html .= qq(<p>
      <a href="$family_url">$family_id</a> : $family_desc<br />
            This cluster contains $family_count Ensembl gene member(s) in this species.</p>);
  }
  $panel->add_row( $label, $html );
}

sub interpro {
  my( $panel, $object ) = @_;
  my $trans         = $object->transcript;
  my $pepdata       = $object->translation_object;
  return unless $pepdata;
  my $interpro_hash = $pepdata->get_interpro_links( $trans );
  return unless (%$interpro_hash);
  my $label = 'InterPro';
# add table call here
  my $html = qq(<table cellpadding="4">);
  for my $accession (keys %$interpro_hash){
    my $interpro_link = $object->get_ExtURL_link( $accession, 'INTERPRO',$accession);
    my $desc = $interpro_hash->{$accession};
    $html .= qq(
  <tr>
    <td>$interpro_link</td>
    <td>$desc - [<a href="/@{[$object->species]}/domainview?domainentry=$accession">View other genes with this domain</a>]</td>
  </tr>);
  }
  $html .= qq( </table> );
  $panel->add_row( $label, $html );
}

sub transcript_structure {
  my( $panel, $transcript ) = @_;
  my $label    = 'Transcript structure';
  my $transcript_slice = $transcript->Obj->feature_Slice;
     $transcript_slice = $transcript_slice->invert if $transcript_slice->strand < 1; ## Put back onto correct strand!
  my $wuc = $transcript->get_userconfig( 'geneview' );
     $wuc->{'_draw_single_Transcript'} = $transcript->Obj->stable_id;
     $wuc->{'_no_label'} = 'true';
     $wuc->set( 'ruler', 'str', $transcript->Obj->strand > 0 ? 'f' : 'r' );
     $wuc->set( $transcript->default_track_by_gene,'on','on');

  my $image    = $transcript->new_image( $transcript_slice, $wuc, [] );
  $panel->add_row( $label, '<div style="margin: 10px 0px">'.$image->render.'</div>' );
}

sub transcript_neighbourhood {
  my( $panel, $transcript ) = @_;
  my $label    = 'Transcript neigbourhood';
  my $transcript_slice = $transcript->Obj->feature_Slice;
     $transcript_slice = $transcript_slice->invert if $transcript_slice->strand < 1; ## Put back onto correct strand!
     $transcript_slice = $transcript_slice->expand( 10e3, 10e3 );
  my $wuc = $transcript->get_userconfig( 'transview' );
     $wuc->{'_no_label'} = 'true';
     $wuc->{'_add_labels'} = 'true';
     $wuc->set( 'ruler', 'str', $transcript->Obj->strand > 0 ? 'f' : 'r' );
     $wuc->set( $transcript->default_track_by_gene,'on','on');

  my $image    = $transcript->new_image( $transcript_slice, $wuc, [] );
     $image->imagemap = 'yes';
  $panel->add_row( $label, '<div style="margin: 10px 0px">'.$image->render.'</div>' );
}

sub protein_features_geneview {
  protein_features( @_, 'nosnps' );
}
sub protein_features {
  my( $panel, $transcript, $snps ) = @_;
  my $label    = 'Protein features';
  my $translation = $transcript->translation_object;
  return undef unless $translation;
  $translation->Obj->{'image_snps'}   = $translation->pep_snps unless $snps eq 'nosnps';
  $translation->Obj->{'image_splice'} = $translation->pep_splice_site( $translation->Obj );
  $panel->_prof( "Got snps and slices for protein_feature....", 1 );

  my $wuc = $transcript->get_userconfig( 'protview' );
  $wuc->container_width( $translation->Obj->length );
  my $image    = $transcript->new_image( $translation->Obj, $wuc, [], 1 );
     $image->imagemap = 'yes';
  $panel->add_row( $label, '<div style="margin: 10px 0px">'.$image->render.'</div>' );
  return 1;
}

sub exonview_options_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'exonview_options', "/@{[$object->species]}/exonview", 'get' );

  # make array of hashes for dropdown options
  $form->add_element( 'type' => 'Hidden', 'name' => 'db',   'value' => $object->get_db    );
  $form->add_element( 'type' => 'Hidden', 'name' => 'exon', 'value' => $object->param('exon') );
  $form->add_element( 'type' => 'Hidden', 'name' => 'transcript', 'value' => $object->stable_id );
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'no',
    'label' => "Flanking sequence at either end of transcript",  'name' => 'flanking',
    'value' => $object->param('flanking')
  );
  $form->add_element(
    'type' => 'NonNegInt', 'required' => 'no',
    'label' => "Intron base pairs to show at splice sites",  'name' => 'sscon',
    'value' => $object->param('sscon')
  );
  $form->add_element(
    'type' => 'CheckBox',
    'label' => "Show full intronic sequence",  'name' => 'fullseq',
    'value' => 'yes', 'checked' => $object->param('fullseq') eq 'yes'
  );
  $form->add_element(
    'type' => 'CheckBox',
    'label' => "Show exons only",  'name' => 'oexon',
    'value' => 'yes', 'checked' => $object->param('oexon') eq 'yes'
  );
  $form->add_element( 'type' => 'Submit', 'value' => 'Go', 'layout' => 'center' );
  return $form ;
}

sub exonview_options {
  my ( $panel, $object ) = @_;
  my $label = 'Rendering options';
  my $html = qq(
   <div>
     @{[ $panel->form( 'exonview_options' )->render() ]}
  </div>);

  $panel->add_row( $label, $html );
  return 1;
}

sub spreadsheet_exons {
  my( $panel, $object ) = @_;
  $panel->add_columns(
    {'key' => 'Number', 'title' => 'No.', 'width' => '5%', 'align' => 'center' },
    {'key' => 'exint',  'title' => 'Exon / Intron', 'width' => '20%', 'align' => 'center' },
    {'key' => 'Chr', 'title' => 'Chr', 'width' => '10%', 'align' => 'center' },
    {'key' => 'Strand',     'title' => 'Strand', 'width' => '10%', 'align' => 'center' },
    {'key' => 'Start', 'title' => 'Start', 'width' => '15%', 'align' => 'right' },
    {'key' => 'End', 'title' => 'End', 'width' => '15%', 'align' => 'right' },
    {'key' => 'StartPhase', 'title' => 'Start Phase', 'width' => '15%', 'align' => 'center' },
    {'key' => 'EndPhase', 'title' => 'End Phase', 'width' => '15%', 'align' => 'center' },
    {'key' => 'Length', 'title' => 'Length', 'width' => '10%', 'align' => 'right' },
    {'key' => 'Sequence', 'title' => 'Sequence', 'width' => '20%', 'align' => 'left' } 
  );
  
  my $sscon      = $object->param('sscon') ;            # no of bp to show either side of a splice site
  my $flanking   = $object->param('flanking') || 50;    # no of bp up/down stream of transcript
  my $full_seq   = $object->param('fullseq') eq 'yes';  # flag to display full sequence (introns and exons)
  my $only_exon  = $object->param('oexon')   eq 'yes';
  my $entry_exon = $object->param('exon');

  # display only exons flag
  my $trans = $object->Obj;
  my $coding_start = $trans->coding_region_start;
  my $coding_end = $trans->coding_region_end;
  my @el = @{$trans->get_all_Exons};
  my $strand   = $el[0]->strand;
  my $chr_name = $el[0]->slice->seq_region_name;
  my @exon_col = qw(blue black);
  my @back_col = qw(background1 background3);
  my $background = 'background1';
  my( $exonA, $exonB, $j, $upstream, $exon_info,$intron_info );
    $sscon = 25 unless $sscon >= 1;
# works out length needed to join intron ends with dots
  my $sscon_dot_length = 60-2*($sscon %30);
  my $flanking_dot_length = 60-($flanking%60);
# upstream flanking seq
  if( $flanking && !$only_exon ){
    my $exon = $el[0];
    if( $strand == 1 ){
      $upstream = $exon->slice()->subseq( ($exon->start)-($flanking),   ($exon->start)-1 , $strand);
    } else {
      $upstream = $exon->slice()->subseq( ($exon->end)+1,   ($exon->end)+($flanking),  $strand);
    }
    $upstream =  lc(('.'x $flanking_dot_length).$upstream);
    $upstream =~ s/([\.\w]{60})/$1<br \/>/g;
    $exon_info = { 'exint'    => qq(5\' upstream sequence),
                   'Sequence' => qq(<font face="courier" color="green">$upstream</font>) };
    $panel->add_row( $exon_info );
  }
  # Loop over each exon
  for( $j=1; $j<= scalar(@el); $j++ ) {
    my( $intron_start, $intron_end, $intron_len, $intron_seq );
    my $col = $exon_col[$j%2];                    #choose exon text colour
    $exonA = $el[$j-1];
    $exonB = $el[$j];

    my $intron_id = "Intron $j-".($j+1)  ;
    my $dots = '.'x $sscon_dot_length;
    my $seq       = uc($exonA->seq()->seq());
    my $seqlen    = length($seq);
    my $exonA_ID  = $exonA->stable_id;
    my $exonA_start   = $exonA->start;
    my $exonA_end     = $exonA->end;
    my $exonB_start   = $exonB->start if $exonB ;
    my $exonB_end     = $exonB->end if $exonB ;
    my $utrspan_start = qq(<span style="color: #9400d3">);  ##set colour of UTR
    my $count = 0;
    my $k = 0;

    # Is this exon entirely UTR?
    if( $coding_end < $exonA_start || $coding_start > $exonA_end ){
      $seq   =~ s/([\.\w]{60})/$1<\/span><br \/>$utrspan_start/g ;
      $seq   .= qq(</span>);
      $seq = "$utrspan_start"."$seq";
    } elsif( $strand eq '-1' ) {
    # Handle reverse strand transcripts.  Yes, this means we have a bunch of
    # duplicated code to handle forward strand.
      my @exon_nt  = split '', $seq;
      my $coding_len =  ($exonA_end) - $coding_start + 1 ;
      my $utr_len =  $exonA_end - $coding_end   ;

      # CDS is within this exon, and we have UTR start and end
      if( $coding_start > $exonA_start &&  $coding_end < $exonA_end ) {
        $seq = qq($utrspan_start);
        for (@exon_nt){
          if( $count == 60 && ($k < $coding_len && $k > $utr_len) ){
            $seq .= "<br />";
            $count =0;
          } elsif( $count == 60 && ($k > $coding_len || $k < $utr_len) ){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($k == $utr_len) {
            $seq .= "</span>";
            if( $count == 60 ) {
              $seq .= "<br />";
              $count = 0;
            }
          } elsif( $k == $coding_len ) {
            $seq .= "$utrspan_start";
            if( $count == 60 ) {
              $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif ($coding_start > $exonA_start ) { # exon starts with UTR
        $seq = "";
        for( @exon_nt ){
          if ($count == 60 && ($k > $coding_len)){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          }elsif ($count == 60 && $k < $coding_len){
            $seq .= "<br />";
            $count =0;
          }elsif ($k == $coding_len){
            if ($count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
            $seq .= qq($utrspan_start);
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif($coding_end < $exonA_end ) { # exon ends with UTR
        $seq = $utrspan_start;
        for( @exon_nt ){
          if ($count == 60 && $utr_len > $k ){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($count == 60 && $k > $utr_len){
            $seq .= "<br />";
            $count =0;
          } elsif ($k == $utr_len) {
            $seq .= qq(</span>);
            if ($count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
        $seq .= "</span>";
      } else{ # entirely coding exon
        $seq =~ s/([\.\w]{60})/$1<br \/>/g ;
      }
    } else { # Handle forward strand transcripts
      my @exon_nt  = split '', $seq;
      my $utr_len =  $coding_start - $exonA_start ;
      my $coding_len =  $seqlen - ($exonA_end - $coding_end)  ;

      # CDS is within this exon, and we have UTR start and end
      if ($coding_start > $exonA_start &&  $coding_end < $exonA_end){
        $seq = qq($utrspan_start);
        for (@exon_nt){
          if ($count == 60 && ($k > $utr_len && $k < $coding_len)){
            $seq .= "<br />";
            $count =0;
          } elsif ($count == 60 && ($k < $utr_len || $k > $coding_len)){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($k == $utr_len) {
            $seq .= "</span>";
            if ($count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
          } elsif ($k == $coding_len) {
            $seq .= "$utrspan_start";
            if ($count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif ($coding_start > $exonA_start ){# exon starts with UTR 
        $seq = qq($utrspan_start);
        for (@exon_nt){
          if ($count == 60 && ($k > $utr_len)){
            $seq .= "<br />";
            $count =0;
          } elsif ($count == 60 && $k < $utr_len){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          } elsif ($k == $utr_len){
            $seq .= "</span>";
            if( $count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
      } elsif($coding_end < $exonA_end ){ # exon ends with UTR
        $seq = '';
        for (@exon_nt){
          if ($count == 60 && $coding_len > $k ){
            $seq .= "<br />";
            $count =0;
          }elsif ($count == 60 && $k > $coding_len){
            $seq .= "</span><br />$utrspan_start";
            $count =0;
          }elsif ($k == $coding_len){
            if ($count == 60) {
              $seq .= "<br />";
              $count = 0;
            }
            $seq .= qq($utrspan_start);
          }
          $seq .= $_ ;
          $count++;
          $k++;
        }
        $seq .= "</span>";
      } else { # Entirely coding exon.
        $seq =~ s/([\.\w]{60})/$1<br \/>/g ;
      }
    }
    if ($entry_exon && $entry_exon eq $exonA_ID){
      $exonA_ID = "<b>$exonA_ID</b>" ;
    }
    $exon_info = {      'Number'    => $j,
                        'exint'     => qq(<a href="/@{[$object->species]}/contigview?l=$chr_name:$exonA_start-$exonA_end;context=100">$exonA_ID</a>),
                        'Chr'       => $chr_name,
                        'Strand'    => $strand,
                        'Start'     => $object->thousandify( $exonA_start ),
                        'End'       => $object->thousandify( $exonA_end ),
                        'StartPhase' => $exonA->phase    >= 0 ? $exonA->phase     : '-',
                        'EndPhase'  => $exonA->end_phase >= 0 ? $exonA->end_phase : '-',
                        'Length'    => $object->thousandify( $seqlen ),
                        'Sequence'  => qq(<font face="courier" color="black">$seq</font>) };
    $panel->add_row( $exon_info );
    if( !$only_exon && $exonB ) {
      eval{
        if($strand == 1 ) { # ...on the forward strand
          $intron_start = $exonA_end+1;
          $intron_end = $exonB_start-1;
          $intron_len = ($intron_end - $intron_start) +1;
          if (!$full_seq && $intron_len > ($sscon *2)){
            my $seq_start_sscon = $exonA->slice()->subseq( ($intron_start),   ($intron_start)+($sscon-1),  $strand);
            my $seq_end_sscon = $exonB->slice()->subseq( ($intron_end)-($sscon-1), ($intron_end), $strand);
            $intron_seq = "$seq_start_sscon$dots$seq_end_sscon";
          } else {
            $intron_seq = $exonA->slice()->subseq( ($intron_start),   ($intron_end),   $strand);
          }
        } else { # ...on the reverse strand
          $intron_start = $exonB_end+1;
          $intron_end = $exonA_start-1;
          $intron_len = ($intron_end - $intron_start) +1;
          if (!$full_seq && $intron_len > ($sscon *2)){
            my $seq_end_sscon = $exonA->slice()->subseq( ($intron_start), ($intron_start)+($sscon-1), $strand);
            my $seq_start_sscon = $exonB->slice()->subseq( ($intron_end)-($sscon-1), ($intron_end), $strand);
            $intron_seq = "$seq_start_sscon$dots$seq_end_sscon";
          } else {
            $intron_seq = $exonA->slice()->subseq( ($intron_start),   ($intron_end),   $strand);
          }
        }
      }; # end of eval
      $intron_seq =  lc($intron_seq);
      $intron_seq =~ s/([\.\w]{60})/$1<br \/>/g;

      $intron_info = {   'Number'    => "&nbsp;",
                         'exint'     => qq(<a href="/@{[$object->species]}/contigview?l=$chr_name:$intron_start-$intron_end;context=100">$intron_id</a>),
                         'Chr'       => $chr_name,
                         'Strand'    => $strand,
                         'Start'     => $object->thousandify( $intron_start ),
                         'End'       => $object->thousandify( $intron_end ),
                         'Length'    => $object->thousandify( $intron_len ),
                         'Sequence'  => qq(<font face="courier" color="blue">$intron_seq</font>)};
      $panel->add_row( $intron_info );
    }
  }     #finished foreach loop
  if( $flanking && !$only_exon ){
    my $exon = $exonB ? $exonB : $exonA;
    my $downstream;
    if( $strand == 1 ){
      $downstream = $exon->slice()->subseq( ($exon->end)+1,   ($exon->end)+($flanking),  $strand);
    } else {
      $downstream = $exon->slice()->subseq( ($exon->start)-($flanking),   ($exon->start)-1 , $strand);
    }
    $downstream =  lc($downstream). ('.'x $flanking_dot_length);
    $downstream =~ s/([\.\w]{60})/$1<br \/>/g;
    $exon_info = { 'exint'    => qq(3\' downstream sequence),
                   'Sequence' => qq(<font face="courier" color="green">$downstream</font>) };
    $panel->add_row( $exon_info );
  }
  return 1;

}


sub marked_up_seq_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'marked_up_seq', "/@{[$object->species]}/transview", 'get' );
  $form->add_element( 'type' => 'Hidden', 'name' => 'db',         'value' => $object->get_db    );
  $form->add_element( 'type' => 'Hidden', 'name' => 'transcript', 'value' => $object->stable_id );
  my $show = [
    { 'value' => 'plain',   'name' => 'Exons' },
#    { 'value' => 'revcom',  'name' => 'Reverse complement sequence' },
    { 'value' => 'codons',  'name' => 'Exons and Codons' },
    { 'value' => 'peptide', 'name' => 'Exons, Codons and Translation'},
  ];
  if( $object->species_defs->databases->{'ENSEMBL_VARIATION'} ||
      $object->species_defs->databases->{'ENSEMBL_GLOVAR'} ) {
    push @$show, { 'value' => 'snps', 'name' => 'Exons, Codons, Translations and SNPs' };
    push @$show, { 'value' => 'snp_coding', 'name' => 'Exons, Codons, Translation, SNPs and Coding sequence'};
  }
  else {
    push @$show, { 'value' => 'coding', 'name' => 'Exons, Codons, Translation and Coding sequence'};
  }
  push @$show, { 'value'=>'rna', 'name' => 'Exons, RNA information' } if $object->Obj->biotype =~ /RNA/;
  $form->add_element(
    'type' => 'DropDown', 'name' => 'show', 'value' => $object->param('show') || 'plain',
    'values' => $show, 'label' => 'Show the following features:', 'select' => 'select'
  );
  my $number = [{ 'value' => 'on', 'name' => 'Yes' }, {'value'=>'off', 'name'=>'No' }];
  $form->add_element(
    'type' => 'DropDown', 'name' => 'number', 'value' => $object->param('number') || 'off',
    'values' => $number, 'label' => 'Number residues:', 'select' => 'select'
  );
  $form->add_element( 'type' => 'Submit', value => 'Refresh' );
  return $form;
}

sub marked_up_seq {
  my( $panel, $object ) = @_;
  my $label = "Transcript sequence";
  my $HTML = "<pre>@{[ do_markedup_pep_seq( $object ) ]}</pre>";
  my $db        = $object->get_db() ;
  my $stable_id = $object->stable_id;
  my $trans_id  = $object->transcript->stable_id;
  my $show      = $object->param('show');

  if( $show eq 'codons' ) {
      $HTML .= qq(<img src="/img/help/transview-key1.gif" height="200" width="200" alt="[Key]" border="0" />);
  } elsif( $show eq 'snps' or $show eq 'snp_coding' ) {
      $HTML .= qq(<img src="/img/help/transview-key3.gif" height="350" width="300" alt="[Key]" border="0" />);
  } elsif( $show eq 'peptide' or $show eq 'coding' ) { 
    $HTML .= qq(<img src="/img/help/transview-key2.gif" height="200" width="200" alt="[Key]" border="0" />);
  }
  elsif ($show eq 'revcom') {
    $HTML .= "<p>Reverse complement sequence</p>";
  }
  $HTML .= "<div>@{[ $panel->form( 'markup_up_seq' )->render ]}</div>";
  $panel->add_row( $label, $HTML );
  return 1;
}

sub do_markedup_pep_seq {
  my $object = shift;
  my $show = $object->param('show');
  my $number = $object->param('number');

  if( $show eq 'plain' ) {
    my $fasta = $object->get_trans_seq;
    $fasta =~ s/([acgtn\*]+)/'<span style="color: blue">'.uc($1).'<\/span>'/eg;
    return $fasta;
  } 
  elsif( $show eq 'revcom' ) {
    my $fasta = $object->get_trans_seq("revcom");
    $fasta =~ s/([acgtn\*]+)/'<span style="color: blue">'.uc($1).'<\/span>'/eg;
    return $fasta;
  }
  elsif( $show eq 'rna' ) {
    my @strings = $object->rna_notation;
    my @extra_array;
    foreach( @strings ) {
      s/(.{60})/$1\n/g;
      my @extra = split /\n/;
      if( $number eq 'on' ) {
        @extra = map { "       $_\n" } @extra;
      } else {
        @extra = map { "$_\n" } @extra;
      }
      push @extra_array, \@extra;
    }

    my @fasta = split /\n/, $object->get_trans_seq;
    my $out = '';
    foreach( @fasta ) {
      $out .= "$_\n";
      foreach my $array_ref (@extra_array) {
        $out .= shift @$array_ref; 
      }
    }
    return $out; 
  }

  # If $show ne rna or plan
  my( $cd_start, $cd_end, $trans_strand, $bps ) = $object->get_markedup_trans_seq;
  my $trans  = $object->transcript;
  my $wrap = 60;
  my $count = 0;
  my ($pep_previous, $ambiguities, $previous, $coding_previous, $output, $fasta, $peptide)  = '';
  my $coding_fasta;
  my $pos = 1;
  my $SPACER = $number eq 'on' ? '       ' : '';
  my %bg_color = (  # move to constant MARKUP_COLOUR
    'utr'      => $object->species_defs->ENSEMBL_STYLE->{'BACKGROUND1'},
    'c0'       => 'ffffff',
    'c1'       => $object->species_defs->ENSEMBL_STYLE->{'BACKGROUND2'},
    'c99'      => 'ffcc99',
    'synutr'   => '7ac5cd',
    'sync0'    => '76ee00',
    'sync1'    => '76ee00',
    'indelutr' => '9999ff',
    'indelc0'  => '99ccff',
    'indelc1'  => '99ccff',
    'snputr'   => '7ac5cd',
    'snpc0'    => 'ffd700',
    'snpc1'    => 'ffd700',
  );

  foreach(@$bps) {
    if($count == $wrap) {
      my( $NUMBER, $PEPNUM ) = ('','');
      my $CODINGNUM;
      if($number eq 'on') {
        $NUMBER = sprintf("%6d ",$pos);
        $PEPNUM = ( $pos>=$cd_start && $pos<=$cd_end ) ? sprintf("%6d ",int( ($pos-$cd_start+3)/3) ) : $SPACER ;
        $CODINGNUM = ( $pos>=$cd_start && $pos<=$cd_end ) ? sprintf("%6d ", $pos-$cd_start+1 ) : $SPACER ;
      }
      $pos += $wrap;
      $output .=  "$SPACER$ambiguities\n" if $show =~ /^snp/;
      $output .= $NUMBER.$fasta. ($previous eq '' ? '':'</span>')."\n";
      $output .="$CODINGNUM$coding_fasta".($coding_previous eq ''?'':'</span>')."\n" if $show =~ /coding/;
      $output .="$PEPNUM$peptide". ($pep_previous eq ''?'':'</span>')."\n\n" if $show =~/^snp/ || $show eq 'peptide' || $show =~ /coding/;
  
      $previous='';
      $pep_previous='';
      $coding_previous='';
      $ambiguities = '';
      $count=0;
      $peptide = '';
      $fasta ='';
      $coding_fasta ='';
    }
    my $bg = $bg_color{"$_->{'snp'}$_->{'bg'}"};
    my $style = qq(style="color: $_->{'fg'};). ( $bg ? qq( background-color: #$bg;) : '' ) .qq(");
    my $pep_style = '';
    my $coding_style;

    # SNPs
    if( $show =~ /^snp/) {
      if($_->{'snp'} ne '') {
        if( $trans_strand == -1 ) {
          $_->{'alleles'}=~tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
          $_->{'ambigcode'} =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
        }
        $style .= qq( title="Alleles: $_->{'alleles'}");
      }
      if($_->{'aminoacids'} ne '') {
        $pep_style = qq(style="color: #ff0000" title="$_->{'aminoacids'}");
      }

      # Add links to SNPs in markup
      if ( my $url_params = $_->{'url_params'} ){ 
  $ambiguities .= qq(<a href="snpview?$url_params">).$_->{'ambigcode'}."</a>";
      } else {
        $ambiguities.= $_->{'ambigcode'};
      }
    }

    my $where =  $count + $pos;
    if($style ne $previous) {
      $fasta.=qq(</span>) unless $previous eq '';
      $fasta.=qq(<span $style>) unless $style eq '';
      $previous = $style;
    }
    if ($coding_style ne $coding_previous) {
      if ( $where>=$cd_start && $where<=$cd_end ) {
  $coding_fasta.=qq(<span $coding_style>) unless $coding_style eq '';
      }
      $coding_fasta.=qq(</span>) unless $coding_previous eq '';
      $coding_previous = $coding_style;
    }

    if($pep_style ne $pep_previous) {
      $peptide.=qq(</span>) unless $pep_previous eq '';
      $peptide.=qq(<span $pep_style>) unless $pep_style eq '';
      $pep_previous = $pep_style;
    }
    $count++;
    $fasta.=$_->{'letter'};
    $coding_fasta.=( $where>=$cd_start && $where<=$cd_end ) ? $_->{'letter'} :".";
    $peptide.=$_->{'peptide'};

  }# end foreach bp


  my( $NUMBER, $PEPNUM, $CODINGNUM)  = ("", "", "");
  if($number eq 'on') {
    $NUMBER = sprintf("%6d ",$pos);
    $CODINGNUM = ( $pos>=$cd_start && $pos<=$cd_end ) ? sprintf("%6d ", $pos-$cd_start +1 ) : $SPACER ;
    $PEPNUM = ( $pos>=$cd_start && $pos<=$cd_end ) ? sprintf("%6d ",int( ($pos-$cd_start-1)/3 +1) ) : $SPACER ;
    $pos += $wrap;
  }
      $output .=  "$SPACER$ambiguities\n" if $show =~ /^snp/;
      $output .= $NUMBER.$fasta. ($previous eq '' ? '':'</span>')."\n";
      $output .="$CODINGNUM$coding_fasta".($coding_previous eq ''?'':'</span>')."\n" if $show =~ /coding/;
      $output .="$PEPNUM$peptide". ($pep_previous eq ''?'':'</span>')."\n\n" if $show =~/^snp/ || $show eq 'peptide' || $show =~ /coding/;
#  $output .=  "$SPACER$ambiguities\n" if $show eq 'snps';
#  $output .= $NUMBER.$fasta. ($previous eq '' ? '':'</span>')."\n";
#  $output .="$CODINGNUM$coding_fasta".($coding_previous eq ''?'':'</span>')."\n" if $show eq 'coding';
#  $output .="$PEPNUM$peptide". ($pep_previous eq ''?'':'</span>')."\n\n" if $show eq 'snps' || $show eq 'peptide' || $show eq 'coding';

  return $output;
}

sub supporting_evidence_image {
  my( $panel, $object ) = @_;
  if (! defined $object->get_supporting_evidence) {
    my $type = $object->logic_name; 
    if ($type eq "otter" ){ 
      $panel->print( '
        <p id="evidence">
          Although this Vega Havana transcript has been manually annotated and
          it\'s structure is supported by experimental evidence, this evidence is
          currently missing from the database. We are adding the evidence back to
          the database as time permits
        </p>' );
    } elsif ($type eq "otter_external"){
      $panel->print( '
        <p id="evidence">
          Although this Vega External transcript has been manually annotated and
          it\'s structure is supported by experimental evidence, this evidence is
          missing from the database. This annotation is not being updated
        </p>' );
    }
    else {
      $panel->print( '
        <p id="evidence">
        </p>' );
    }
  } else {
  $panel->print( '
    <p id="evidence">
      The supporting evidence below consists of the sequence matches
      on which the exon predictions were based and are sorted by alignment score.
    </p>' );
  my $evidence   = $object->get_supporting_evidence;
  my $show       = $object->param('showall');
  my $exon_count = $evidence->{ 'transcript' }{'exon_count'};
  my $hits       = scalar(keys %{$evidence->{ 'hits' }});
  if( $exon_count > 100 && !$show ) {
    $panel->print( qq(
    <p>
      The supporting evidence image may take a while to load, please
      <a href="/@{[$object->species]}/exonview?transcript=@{[$object->stable_id]};db=@{[$object->get_db]};showall=1">click here
      to view supporting evidence<a/>.
    </p>) );
    return 1;
  }
  if( $hits > 10 && !$show ){
    $panel->print( qq(
    <p>
      There are a large number of supporting evidence hits for this transcript. Only the
      top ten 10 hits have been shown.
      <a href="/@{[$object->species]}/exonview?transcript=@{[$object->stable_id]};db=@{[$object->get_db]};showall=1">Click to view all $hits
      supporting evidence hits<a/>.
    </p>) );
    my @T = sort keys %{$evidence->{ 'hits' }};
    for(my $i=10;$i<$hits;$i++) {
      delete $evidence->{'hits'}{$T[$i]};
    }  
  }

  my $wuc = $object->get_userconfig( 'exonview' );
    $wuc->container_width( 1200 );
    $wuc->set( 'supporting_evidence', 'hide_hits', 'yes') if $object->param('showall');
    $wuc->set( '_settings', 'width', $object->param('image_width') );
  my $image    = $object->new_image( $evidence, $wuc );
  $image->imagemap = 'yes';

  my $T = $image->render;
  $panel->print( $T );
 }
  return 1;
}

sub spreadsheet_variationTable {
  my( $panel, $object ) = @_;
  my %snps = %{$object->__data->{'transformed'}{'snps'}||[]};
  my @gene_snps = @{$object->__data->{'transformed'}{'gene_snps'}||[]};
  my $tr_start = $object->__data->{'transformed'}{'start'};
  my $tr_end   = $object->__data->{'transformed'}{'end'};
  my $extent   = $object->__data->{'transformed'}{'extent'};
  my $cdna_coding_start = $object->Obj->cdna_coding_start;
  return unless %snps;

  $panel->add_columns(
    { 'key' => 'ID', },
    { 'key' => 'snptype', 'title' => 'Type', },
    { 'key' => 'chr' , 'title' => 'Chr: bp',  },
    { 'key' => 'Alleles', 'align' => 'center' },
    { 'key' => 'Ambiguity', 'align' => 'center', },
    { 'key' => 'aachange', 'title' => 'AA change', 'align' => 'center' },
    { 'key' => 'aacoord',  'title' => 'AA co-ordinate', 'align' => 'center' },
    { 'key' => 'class', 'title' => 'Class', 'align' => 'center' },
    { 'key' => 'Source', },
    { 'key' => 'status', 'title' => 'Validation', 'align' => 'center' },
  );

  foreach my $gs ( @gene_snps ) {
    my $raw_id = $gs->[2]->dbID;
    my $transcript_variation  = $snps{$raw_id};
    my @validation =  @{ $gs->[2]->get_all_validation_states || [] };

    if( $transcript_variation && $gs->[5] >= $tr_start-$extent && $gs->[4] <= $tr_end+$extent ) {

      my $ROW = {
        'ID'        =>  qq(<a href="/@{[$object->species]}/snpview?snp=@{[$gs->[2]->variation_name]};source=@{[$gs->[2]->source]};chr=$gs->[3];vc_start=$gs->[4]">@{[$gs->[2]->variation_name]}</a>),
        'class'     => $gs->[2]->var_class() eq 'in-del' ? ( $gs->[4] > $gs->[5] ? 'insertion' : 'deletion' ) : $gs->[2]->var_class(),
        'Alleles'   => $gs->[2]->allele_string(),
        'Ambiguity' => $gs->[2]->ambig_code(),
        'status'    => (join( ', ',  @validation ) || "-"),
        'chr'       => $gs->[3].": ".
                        ($gs->[4]==$gs->[5] ? $gs->[4] :  "$gs->[4]-$gs->[5]"),
        'snptype'   => (join ", ", @{ $transcript_variation->consequence_type || []}),
        $transcript_variation->translation_start ? (
           'aachange' => $transcript_variation->pep_allele_string,
           'aacoord'   => $transcript_variation->translation_start.' ('.(($transcript_variation->cdna_start - $cdna_coding_start )%3+1).')'
        ) : ( 'aachange' => '-', 'aacoord' => '-' ),
    'Source'      => (join ", ", @{$gs->[2]->get_all_sources ||[] } )|| "-",   
      };
      $panel->add_row( $ROW );
    }
  }
  return 1;
}

# Transcript SNP View ---------------------------------------###################

sub transcriptsnpview { 
  my( $panel, $object, $do_not_render ) = @_;

  # Params for context transcript expansion.
  my $db = $object->get_db();
  my $transcript = $object->stable_id;
  my $script = 'transcriptsnpview';
  my $base_URL = "/".$object->species."/$script?db=$db;transcript=$transcript;";

  # Get three slice - context (5x) gene (4/3x) transcripts (+-EXTENT)
  my $extent = tsv_extent($object);
  foreach my $slice_type (
    [ 'context',           'normal', '100%'  ],
    [ 'transcript',        'normal', '20%'  ],
    [ 'TSV_transcript',    'munged', $extent ],
  ) {
    $object->__data->{'slices'}{ $slice_type->[0] } =  $object->get_transcript_slices( $slice_type ) || warn "Couldn't get slice";
  }
  my $transcript_slice = $object->__data->{'slices'}{'TSV_transcript'}[1];
  my $sub_slices       =  $object->__data->{'slices'}{'TSV_transcript'}[2];
  my $fake_length      =  $object->__data->{'slices'}{'TSV_transcript'}[3];

  #SNPs
  my ($count_sample_snps, $sample_snps, $context_count) = $object->getFakeMungedVariationsOnSlice( $transcript_slice, $sub_slices  );
  my $start_difference =  $object->__data->{'slices'}{'TSV_transcript'}[1]->start - $object->__data->{'slices'}{'transcript'}[1]->start;

  my @transcript_snps;
  map { push @transcript_snps, 
    [ $_->[2]->start + $start_difference, 
      $_->[2]->end   + $start_difference, 
      $_->[2]] } @$sample_snps;

  # Taken out domains (prosite, pfam)

  # Tweak the configurations for the five sub images ------------------ 
  # Intronless transcript top and bottom (to draw snps, ruler and exon backgrounds)
  my @ens_exons;
  foreach my $exon (@{ $object->Obj->get_all_Exons() }) {
    my $offset = $transcript_slice->start -1;
    my $es     = $exon->start - $offset;
    my $ee     = $exon->end   - $offset;
    my $munge  = $object->munge_gaps( 'TSV_transcript', $es );
    push @ens_exons, [ $es + $munge, $ee + $munge, $exon ];
  }


  # General page configs -------------------------------------
  # Get 4 configs (one for each section) set width to width of context config
  my $Configs;
  my $image_width    = $object->param( 'image_width' );

  foreach (qw(context transcript transcripts_bottom transcripts_top)) {
    $Configs->{$_} = $object->user_config_hash( "TSV_$_" );
    $Configs->{$_}->set( '_settings', 'width',  $image_width );
    $Configs->{$_}->{'id'} = $object->stable_id;
  }

  $Configs->{'transcript'}->{'filtered_fake_snps'} = \@transcript_snps;

  foreach(qw(transcripts_top transcripts_bottom)) {
    $Configs->{$_}->{'extent'}      = $extent;
    $Configs->{$_}->{'transid'}     = $object->stable_id;
    $Configs->{$_}->{'transcripts'} = [{ 'exons' => \@ens_exons }];
    $Configs->{$_}->{'snps'}        = $sample_snps;
    $Configs->{$_}->{'subslices'}   = $sub_slices;
    $Configs->{$_}->{'fakeslice'}   = 1;
    $Configs->{$_}->container_width( $fake_length );
  }


  $Configs->{'snps'} = $object->user_config_hash( "genesnpview_snps" );
  $Configs->{'snps'}->set( '_settings', 'width',  $image_width );
  $Configs->{'snps'}->{'snp_counts'} = [$count_sample_snps, scalar @$sample_snps, $context_count];

  $Configs->{'context'}->container_width( $object->__data->{'slices'}{'context'}[1]->length() );
  $Configs->{'context'}->set( 'scalebar', 'label', "Chr. @{[$object->__data->{'slices'}{'context'}[1]->seq_region_name]}");
  $Configs->{'context'}->set( 'est_transcript','on','off');
  $Configs->{'context'}->set( '_settings', 'URL', $base_URL."bottom=%7Cbump_", 1);
  #$Configs->{'context'}->{'filtered_fake_snps'} = $context_snps;

  # SNP stuff ------------------------------------------------------------
  my ($containers_and_configs, $haplotype);

  # Foreach sample ... 
  ($containers_and_configs, $haplotype) = _sample_configs($object, $transcript_slice, $sub_slices, $fake_length);

  # -- Map SNPs for the last SNP display to fake even spaced co-ordinates
  # @snps: array of arrays  [fake_start, fake_end, B:E:Variation obj]
  my $SNP_REL     = 5; ## relative length of snp to gap in bottom display...
  my $snp_fake_length = -1; ## end of last drawn snp on bottom display...
  my @fake_snps = map {
    $snp_fake_length +=$SNP_REL+1;
      [ $snp_fake_length - $SNP_REL+1, $snp_fake_length, $_->[2], $transcript_slice->seq_region_name,
  $transcript_slice->strand > 0 ?
  ( $transcript_slice->start + $_->[2]->start - 1,
    $transcript_slice->start + $_->[2]->end   - 1 ) :
  ( $transcript_slice->end - $_->[2]->end     + 1,
    $transcript_slice->end - $_->[2]->start   + 1 )
      ]
    } sort { $a->[0] <=> $b->[0] } @$sample_snps;

  if (scalar @$haplotype) {
    $Configs->{'snps'}->set( 'snp_fake_haplotype', 'on', 'on' );
    $Configs->{'snps'}->set( 'TSV_haplotype_legend', 'on', 'on' );
    $Configs->{'snps'}->{'snp_fake_haplotype'}  =  $haplotype;
  }
  $Configs->{'snps'}->container_width(   $snp_fake_length   );
  $Configs->{'snps'}->{'snps'}        = \@fake_snps;
  $Configs->{'snps'}->{'reference'}   = $object->param('reference')|| "";
  $Configs->{'snps'}->{'fakeslice'}   = 1;
  $Configs->{'snps'}->{'URL'} =  $base_URL;
  return if $do_not_render;

  ## -- Render image ----------------------------------------------------- ##
  # Send the image pairs of slices and configurations
  my $image    = $object->new_image(
    [
     $object->__data->{'slices'}{'context'}[1],     $Configs->{'context'},
     $object->__data->{'slices'}{'transcript'}[1],  $Configs->{'transcript'},
     $transcript_slice, $Configs->{'transcripts_top'},
     @$containers_and_configs,
    $transcript_slice, $Configs->{'transcripts_bottom'},
     $transcript_slice, $Configs->{'snps'},
    ],
    [ $object->stable_id ]
  );

  $image->imagemap = 'yes';
  my $T = $image->render;
  $panel->print( $T );

  return 0;
}




sub _sample_configs {
  my ($object, $transcript_slice, $sub_slices, $fake_length) = @_;

  my @containers_and_configs = (); ## array of containers and configs
  my @haplotype = ();
  my $extent = tsv_extent($object);

  # THIS IS A HACK. IT ASSUMES ALL COVERAGE DATA IN DB IS FROM SANGER fc1
  # Only display coverage data if source Sanger is on
  my $display_coverage = $object->get_scriptconfig->get( "opt_sanger" ) eq 'off' ? 0 : 1;

  foreach my $sample ( $object->get_samples ) {
    my $sample_slice = $transcript_slice->get_by_strain( $sample );
    next unless $sample_slice;

    ## Initialize content...
    my $sample_config = $object->get_userconfig( "TSV_sampletranscript" );
    $sample_config->{'id'}         = $object->stable_id;
    $sample_config->{'subslices'}  = $sub_slices;
    $sample_config->{'extent'}     = $extent;

    ## Get this transcript only, on the sample slice
    my $transcript;

    foreach my $test_transcript ( @{$sample_slice->get_all_Transcripts} ) {
      next unless $test_transcript->stable_id eq $object->stable_id;
      $transcript = $test_transcript;  # Only display on e transcripts...
      last;
    }
    next unless $transcript;

    my $raw_coding_start = defined( $transcript->coding_region_start ) ? $transcript->coding_region_start : $transcript->start;
    my $raw_coding_end   = defined( $transcript->coding_region_end )   ? $transcript->coding_region_end : $transcript->end;
    my $coding_start = $raw_coding_start + $object->munge_gaps( 'TSV_transcript', $raw_coding_start );
    my $coding_end   = $raw_coding_end   + $object->munge_gaps( 'TSV_transcript', $raw_coding_end );

    my @exons = ();
    foreach my $exon (@{$transcript->get_all_Exons()}) {
      my $es = $exon->start;
      my $offset = $object->munge_gaps( 'TSV_transcript', $es );
      push @exons, [ $es + $offset, $exon->end + $offset, $exon ];
    }

    my ( $allele_info, $consequences ) = $object->getAllelesConsequencesOnSlice($sample, "TSV_transcript", $sample_slice);
    my ($coverage_level, $raw_coverage_obj) = ([], []);
    if ($display_coverage) {
      ($coverage_level, $raw_coverage_obj) = $object->read_coverage($sample, $sample_slice);
    }
    my $munged_coverage = $object->munge_read_coverage($raw_coverage_obj);

    $sample_config->{'transcript'} = {
      'sample'          => $sample,
      'exons'           => \@exons,  
      'coding_start'    => $coding_start,
      'coding_end'      => $coding_end,
      'transcript'      => $transcript,
      'allele_info'     => $allele_info,
      'consequences'    => $consequences,
      'coverage_level'  => $coverage_level,
      'coverage_obj'    => $munged_coverage,
    };
    unshift @haplotype, [ $sample, $allele_info, $munged_coverage ];

warn "#### $sample\n";
warn map { "  >> @$_\n" } @$allele_info;
#warn map { "  << @$_\n" } @$munged_coverage;
    $sample_config->container_width( $fake_length );
  
    ## Finally the variation features (and associated transcript_variation_features )...  Not sure exactly which call to make on here to get 

    ## Now push onto config hash...
    push @containers_and_configs,    $sample_slice, $sample_config;
  } #end foreach sample

  return (\@containers_and_configs, \@haplotype);
}



sub tsv_extent {
  my $object = shift;
  return $object->param( 'context' ) eq 'FULL' ? 1000 : $object->param( 'context' );
}


sub transcriptsnpview_menu    {
  my ($panel, $object) = @_;
  my $valids = $object->valids;

  my @onsources;
  map {  push @onsources, $_ if $valids->{lc("opt_$_")} }  @{$object->get_source || [] };

  my $text;
  my @populations = $object->get_samples('display');
  if ( $onsources[0] ) {
    $text = " from these sources: " . join ", ", @onsources if $onsources[0];
  }
  else {
    $text = ". Please select a source from the yellow 'Source' dropdown menu" if scalar @populations;
  }
  $panel->print("<p>Where there is resequencing coverage, SNPs have been called using a computational method.  Here we display the SNP calls observed by transcript$text.  </p>");

  my $user_config = $object->user_config_hash( 'TSV_sampletranscript' );
  $user_config->{'Populations'}    = \@populations;


  my $individual_adaptor = $object->Obj->adaptor->db->get_db_adaptor('variation')->get_IndividualAdaptor;
  $user_config->{'snp_haplotype_reference'}    =  $individual_adaptor->get_reference_strain_name();

  my $strains = ucfirst($object->species_defs->translate("strain"))."s";
  my $left =  [( 'Features', 'Source', 'SNPClasses', 'SNPTypes', "$strains", 'SNPContext', 'THExport', 'ImageSize' )]; # removed SNPValid

  my $mc = $object->new_menu_container(
     'configname'  => 'TSV_sampletranscript', #primary config for display
     'panel'       => "bottom",
     'configs'     => [ $object->user_config_hash( 'TSV_context' ), $object->user_config_hash('TSV_transcript') ], # other configs that are affected by menu changes
     'leftmenus'  => $left,
     'rightmenus' => ['SNPHelp'],
   );
  $panel->print( $mc->render_html );
  $panel->print( $mc->render_js );
  return 0;
}

sub table_info {

  ### Adds text to panel defined in Configuration::Transcript 
  ### just above spreadsheet tables
  ### Returns 0

  my ($panel, $object)= @_;
  my $samples = join ", ", ($object->get_samples("default"));
  my $strain = $object->species_defs->translate("strain")."s";
  $panel->print("These $strain are displayed by default: $samples. <br />Use the yellow dropdown menus at the top of the image above to customise which $strain and types of SNPs are displayed in the tables below.");
  return 0;
}

sub spreadsheet_TSVtable {
  my( $panel, $object ) = @_;
  my $sample      =  $panel->{'sample'};
  my $snp_data    = get_page_data($panel, $object, [$sample] );
  my $strain_name = $object->species_defs->translate("strain");

  $panel->add_columns(
    { 'key' => 'ID',  },
    { 'key' => 'consequence', 'title' => 'Type', },
    { 'key' => 'chr' ,        'title' => "Chr: bp" },
    { 'key' => 'ref_alleles',  'title' => 'Ref. allele', },
    { 'key' => 'Alleles',     'title' => ucfirst($strain_name)." genotype", },
    { 'key' => 'Ambiguity',   'title' => 'Ambiguity',  },
    { 'key' => 'Codon',       'title' => "Transcript codon" ,  },
    { 'key' => 'cdscoord',  'title' => 'CDS coord.',  },
    { 'key' => 'aachange', 'title' => 'AA change',  },
    { 'key' => 'aacoord',  'title' => 'AA coord.',  },
    #{ 'key' => 'coverage',  'title' => 'Read coverage',  },
    { 'key' => 'Class', },
    { 'key' => 'Source', },
    { 'key' => 'Status', 'title' => 'Validation',  },
         ) if %$snp_data;
  foreach my $snp_row (sort keys %$snp_data) {
    foreach my $row ( @{$snp_data->{$snp_row}{$sample} || [] } ) {
      $panel->add_row( $row );
    }
  }
  return 1;
}



sub get_page_data {
  my( $panel, $object, $samples ) = @_;

  my %snp_data;

  foreach my $sample ( @$samples ) { 
    my $munged_transcript = $object->get_munged_slice("TSV_transcript",  tsv_extent($object), 1 ) || warn "Couldn't get munged transcript";
    my $sample_slice = $munged_transcript->[1]->get_by_strain( $sample );

    my ( $allele_info, $consequences ) = $object->getAllelesConsequencesOnSlice($sample, "TSV_transcript", $sample_slice);
    next unless @$consequences && @$allele_info;

    my ($coverage_level, $raw_coverage_obj) = $object->read_coverage($sample, $sample_slice);

    my @coverage_obj;
    if ( @$raw_coverage_obj ){
      @coverage_obj = sort {$a->start <=> $b->start} @$raw_coverage_obj;
    }

    my $index = 0;
    foreach my $allele_ref (  @$allele_info ) {
      my $allele = $allele_ref->[2];
      my $conseq_type = $consequences->[$index];
      $index++;
      next unless $conseq_type && $allele;

      # Check consequence obj and allele feature obj have same alleles
      my $tmp = join "", @{$conseq_type->alleles || []};
      $tmp =~ tr/ACGT/TGCA/ if ( $object->Obj->strand ne $allele->strand);
      #warn "ERROR: Allele call on alleles is", $allele->allele_string, ". Allele call on ConsequenceType is different: $tmp" if $allele->allele_string ne $tmp;

      # Type
      my $type = join ", ", @{$conseq_type->type || []};
      if ($type eq 'SARA') {
  $type .= " (Same As Ref. Assembly)";
      }

      
      # Position
      my $offset = $sample_slice->strand > 0 ? $sample_slice->start - 1 :  $sample_slice->end + 1;
      my $chr_start = $allele->start() + $offset;
      my $chr_end   = $allele->end() + $offset;
      my $pos =  $chr_start;
      if( $chr_end < $chr_start ) {
  $pos = "between&nbsp;$chr_end&nbsp;&amp;&nbsp;$chr_start";
      } elsif($chr_end > $chr_start ) {
  $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
      }

      # Class
      my $class = $object->var_class($allele);
      if ($class eq 'in-del') {
  $class = $chr_start > $chr_end ? 'Insertion' : 'Deletion';
      }
      $class =~ s/snp/SNP/;
      
      # Codon - make the letter for the SNP position in the codon bold
      my $codon = $conseq_type->codon;
      if ( $codon ) {
  my $position = ($conseq_type->cds_start % 3 || 3) - 1;
  $codon =~ s/(\w{$position})(\w)(.*)/$1<b>$2<\/b>$3/; 
      }

      my $status;
      if ( grep { $_ eq "Sanger"} @{$allele->get_all_sources() || []} ) {
  #if ($allele->source eq 'Sanger') {
  # Read coverage
  my $allele_start = $allele->start;
  my $coverage;
  foreach ( @coverage_obj ) {
    next if $allele_start >  $_->end;
    last if $allele_start < $_->start;
    $coverage = $_->level if $_->level > $coverage;
  }
  $coverage = ">".($coverage-1) if $coverage == $coverage_level->[-1];
  $status = "resequencing coverage $coverage";
      }
      else {
  my $tmp =  $allele->variation;
  my @validation = $tmp ? @{ $tmp->get_all_validation_states || [] } : ();
  $status = join( ', ',  @validation ) || "-";
  $status =~ s/freq/frequency/;
      }

      # Other
      my $chr = $sample_slice->seq_region_name;

      my $aa_alleles = $conseq_type->aa_alleles || [];
      my $aa_coord = $conseq_type->aa_start;
      $aa_coord .= $aa_coord == $conseq_type->aa_end ? "": $conseq_type->aa_end;
      my $cds_coord = $conseq_type->cds_start;
      $cds_coord .= "-".$conseq_type->cds_end unless $conseq_type->cds_start == $conseq_type->cds_end;
      my $sources = join ", " , @{$allele->get_all_sources || [] };
      my $row = {
    'ID'          =>  qq(<a href="/@{[$object->species]}/snpview?snp=@{[$allele->variation_name]};source=@{[$allele->source]};chr=$chr;vc_start=$chr_start">@{[$allele->variation_name]}</a>),
    'Class'       => $class || "-",
    'Source'      => $sources || "-",
     'ref_alleles' => $allele->ref_allele_string || "-",
    'Alleles'     => $allele->allele_string || "-",
    'Ambiguity'   => $object->ambig_code($allele),
    'Status'      => $status,
    'chr'         => "$chr:$pos",
    'Codon'       => $codon || "-",
    'consequence' => $type,
    'cdscoord'    => $cds_coord || "-",
    #'coverage'    => $coverage || "0",
    };
     
      if ($conseq_type->aa_alleles){
  $row->{'aachange'} = ( join "/", @{$aa_alleles} ) || "";
  $row->{'aacoord'}  = $aa_coord;
      }
      else {
  $row->{'aachange'} = '-';
  $row->{'aacoord'}  = '-';
      }
      push @{$snp_data{"$chr:$pos"}{$sample}}, $row;
    }
  }
  return \%snp_data;
}


# PAGE DUMP METHODS -------------------------------------------------------

sub dump {
  my ( $panel, $object ) = @_;
  my $strain = $object->species_defs->translate("strain");
  $panel->print("<p>Dump of SNP data per $strain (SNPs in rows, $strain","s in columns).  For more advanced data queries use <a href='/biomart/martview'>BioMart</a>. </p>");
  my $html = qq(
   <div>
     @{[ $panel->form( 'dump_form' )->render() ]}
  </div>);

  $panel->print( $html );
  return 1;
}


sub dump_form {
  my ($panel, $object ) = @_;

  my $form = EnsEMBL::Web::Form->new('tsvview_form', "/@{[$object->species]}/transcriptsnpdataview", 'get' );

  my  @formats = ( {"value" => "astext",  "name" => "Text format"},
        #          {"value" => "asexcel", "name" => "In Excel format"},
                   {"value" => "ashtml",  "name" => "HTML format"}
                 );

  return $form unless @formats;
  $form->add_element( 'type'  => 'Hidden',
                      'name'  => '_format',
                      'value' => 'ashtml' );
  $form->add_element(
    'class'     => 'radiocheck1col',
    'type'      => 'DropDown',
    'renderas'  => 'checkbox',
    'name'      => 'dump',
    'label'     => 'Dump format',
    'values'    => \@formats,
    'value'     => $object->param('dump') || 'astext',
  );

  $form->add_element (
                           'type'      => 'Hidden',
                           'name'      => 'transcript',
                           'value'     => $object->param('transcript'),
         );

  my @cgi_params = @{$panel->get_params($object, {style =>"form"}) };
  foreach my $param ( @cgi_params) {
       $form->add_element (
                          'type'      => 'Hidden',
                          'name'      => $param->{'name'},
                          'value'     => $param->{'value'},
                          'id'        => "Other param",
                         );
  }


 $form->add_element(
    'type'      => 'Submit',
    'name'      => 'submit',
    'value'     => 'Dump',
                    );


  $form->add_attribute( 'onSubmit',
  qq(this.elements['_format'].value='HTML';this.target='_self';flag='';for(var i=0;i<this.elements['dump'].length;i++){if(this.elements['dump'][i].checked){flag=this.elements['dump'][i].value;}}if(flag=='astext'){this.elements['_format'].value='Text';this.target='_blank'}if(flag=='gz'){this.elements['_format'].value='Text';})
    );

  return $form;
}


sub html_dump {
  my( $panel, $object ) = @_;

  my $script_config = $object->get_scriptconfig;
  $script_config->reset;
  foreach my $param ( $object->param() ) {
    $script_config->set($param, $object->param($param) , 1);
  }
  # $script_config->save;
  my @samples = sort ( $object->get_samples );

  my $snp_data = get_page_data($panel, $object, \@samples );
  unless (ref $snp_data eq 'HASH') {
    $panel->print("<p>No data in this region.");
    return;
  }

  $panel->print("<p>Format: tab separated per strain (SNP id; Type; Amino acid change;)</p>\n");
  my $header_row = join "</th><th>", ("bp position", @samples);
  $panel->print("<table class='ss tint'>\n");
  $panel->print("<tr><th>$header_row</th></tr>\n");

  my @background = ('class="bg2"', ""); 
  my $user_config = $object->user_config_hash( 'genesnpview_snps' );
  my %colours = $user_config->{'_colourmap'}->colourSet('variation');

  foreach my $snp_pos ( sort keys %$snp_data ) {
    my $background= shift @background;
    push @background, $background;
    $panel->print(qq(<tr $background><td>$snp_pos</td>));
    foreach my $sample ( @samples ) {
      my @info;
      my $style;

      foreach my $row ( @{$snp_data->{$snp_pos}{$sample} || [] } ) {
  (my $type = $row->{consequence}) =~ s/\(Same As Ref. Assembly\)//;
  if ($row->{ID}) {
    if ($row->{aachange} ne "-") {
      my $colour = $user_config->{'_colourmap'}->hex_by_name($colours{$type}[0]);
      $style = qq(style="background-color:#$colour");
    }
    push @info, "$row->{ID}; $type; $row->{aachange};";
  }
  else {
    push @info, "<td>.</td>";
  }
      }
      my $print = join "<br />", @info;
      $panel->print("<td $style>$print</td>");
    }
    $panel->print("</tr>\n");
  }
  $panel->print("\n</table>");
  return 1;
}

sub text_dump {
  my( $panel, $object ) = @_;

  my $script_config = $object->get_scriptconfig;
  $script_config->reset;
  foreach my $param ( $object->param() ) {
    $script_config->set($param, $object->param($param) , 1);
  }
  # $script_config->save;
  my @samples = sort ( $object->get_samples );
  $panel->print("Variation data for ".$object->stable_id);
  $panel->print("\nFormat: tab separated per strain (SNP id; Type; Amino acid change;)\n\n");

  my $snp_data = get_page_data($panel, $object, \@samples );
  unless (ref $snp_data eq 'HASH') {
    $panel->print("No data in this region.");
    return;
  }

  my $header_row = join "\t", ("bp position", @samples);
  $panel->print("$header_row\n");

  foreach my $snp_pos ( sort keys %$snp_data ) {
    $panel->print(qq($snp_pos\t));
    foreach my $sample ( @samples ) {
      foreach my $row ( @{$snp_data->{$snp_pos}{$sample} || [] }) {
  (my $type = $row->{consequence}) =~ s/\(Same As Ref. Assembly\)//;;
  my $info = $row->{ID} ? "$row->{ID}; $type; $row->{aachange}; " : ".";
  $panel->print(qq($info));
      }
      $panel->print("\t");
    }
    $panel->print("\n");
  }
  $panel->print("\n");
  return 1;
}

sub class {
    my ($panel,$transcript) = @_;
    my $label = 'Transcript Class';
    my $class = ucfirst(lc($transcript->Obj->status)).' '.ucfirst(lc($transcript->Obj->biotype));
	$class =~ s/_/ /g;
	$class =~ s/unknown//i;
    return 1 unless $class;
    my $species = $transcript->species;
    my $text = qq(<p>$class [<a href="http://vega.sanger.ac.uk/info/about/gene_and_transcript_types.html" target="external">Definition</a>]</p>);
    $panel->add_row($label, qq($text));
    return 1;
}

=head2 version

 Arg[1]       : information panel (EnsEMBL::Web::Document::Panel::Information)
 Arg[2]       : object (EnsEMBL::Web::Proxy::Object)
 Example     : $panel1->add_component(qw(curated_locus EnsEMBL::Sanger_vega::Component::Gene::version));
 Description : adds version details to an information panel
 Return type : true

=cut

sub version {
    my ($panel, $obj) = @_; 
    my $label = 'Version';
    my $version = $obj->version;
  return 1 unless $version;
    $panel->add_row($label, qq(<p>$version</p>));
    return 1;
}

1;
