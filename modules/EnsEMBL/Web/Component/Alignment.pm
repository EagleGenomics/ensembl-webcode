package EnsEMBL::Web::Component::Alignment;

# outputs chunks of XHTML for protein domain-based displays

use EnsEMBL::Web::Component;
our @ISA = qw(EnsEMBL::Web::Component);
use Bio::AlignIO;
use IO::String;

use strict;
use warnings;
no warnings "uninitialized";

sub SIMPLEALIGN_FORMATS { return {
  'fasta'    => 'FASTA',
  'msf'      => 'MSF',
  'clustalw' => 'CLUSTAL',
  'selex'    => 'Selex',
  'pfam'     => 'Pfam',
  'mega'     => 'Mega',
  'nexus'    => 'Nexus',
  'phylip'   => 'Phylip',
  'psi'      => 'PSI',
}; }

sub HOMOLOGY_TYPES {
  return {
    'BRH'  => 'Best Reciprocal Hit',
    'UBRH' => 'Unique Best Reciprocal Hit',
    'RHS'  => 'Reciprocal Hit based on Synteny around BRH',
    'DWGA' => 'Derived from Whole Genome Alignment'
  };
}

sub param_list {
  my $class = shift;
  my $T = {
    'Family'   => [qw(family_stable_id)],
    'Homology' => [qw(gene g1)],
    'AlignSlice' => [qw(chr bp_start bp_end as method s)],
  };
  return @{$T->{$class}||[]};
}
sub SIMPLEALIGN_DEFAULT { return 'clustalw'; }

sub format_form {
  my( $panel, $object ) = @_;
  my $class = $object->param('class');
  my $form = EnsEMBL::Web::Form->new( 'format_form', "/@{[$object->species]}/alignview", 'get' );
  foreach my $K ( 'class', param_list( $class ) ) {
    $form->add_element( 'type' => 'Hidden', 'name' => $K, 'value' => $object->param($K) );
  }
  if( $class eq 'Homology' ) {
    $form->add_element(
      'type' => 'DropDown', 
      'select' => 'select',
      'name' => 'seq',
      'label' => 'Display sequence as',
      'value' => $object->param('seq')||'Pep',
      'values' => [
        { 'value'=>'Pep', 'name' => 'Peptide' },
        { 'value'=>'DNA', 'name' => 'DNA' },
      ]
    );
  }
  my $hash = SIMPLEALIGN_FORMATS;
  $form->add_element( 
    'type' => 'DropDownAndSubmit', 
    'select' => 'select',
    'name' => 'format',
    'label' => 'Change output format to:',
    'value' => $object->param('format')||SIMPLEALIGN_DEFAULT,
    'button_value' => 'Go',
    'values' => [
      map {{ 'value' => $_, 'name' => $hash->{$_} }} sort keys %$hash
    ]
  );
  return $form;
}

sub format {
  my( $panel, $object ) = @_;
  $panel->print( $panel->form('format')->render );
  return 1;
}

sub renderer_type {
  my $K = shift;
  my $T = SIMPLEALIGN_FORMATS;
  return $T->{$K} ? $K : SIMPLEALIGN_DEFAULT;
}

sub output_Family {
  my( $panel, $object ) = @_;
  foreach my $family (@{$object->Obj||[]}) {
    my $alignio = Bio::AlignIO->newFh(
      -fh     => IO::String->new(my $var),
      -format => renderer_type($object->param('format'))
    );
    print $alignio $family->get_SimpleAlign();
    $panel->print("<pre>$var</pre>\n");
  }
}

sub output_Homology {
  my( $panel, $object ) = @_;
  foreach my $homology (@{$object->Obj||[]}) {
    my $sa;
    eval { $sa = $homology->get_SimpleAlign( $object->param('seq') eq 'DNA' ? 'cdna' : undef ); };
    my $second_gene = $object->param('g1');
    if( $sa ) {
      my $DATA = [];
      my $FLAG = ! $second_gene;
      foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
        my ($member, $attribute) = @{$member_attribute};
        $FLAG = 1 if $member->stable_id eq $second_gene;
        my $peptide = $member->{'_adaptor'}->db->get_MemberAdaptor()->fetch_by_dbID( $attribute->peptide_member_id );
        my $species = $member->genome_db->name;
        (my $species2 = $species ) =~s/ /_/g;
        push @$DATA, [
          $species,
          sprintf( '<a href="/%s/geneview?gene=%s">%s</a>' , $species2, $member->stable_id,$member->stable_id ),
          sprintf( '<a href="/%s/protview?peptide=%s">%s</a>' , $species2, $peptide->stable_id,$peptide->stable_id ),
          sprintf( '%d aa', $peptide->seq_length ),
          sprintf( '<a href="/%s/contigview?l=%s:%d-%d">%s:%d-%d</a>',$species2,
          $member->chr_name, $member->chr_start, $member->chr_end,
          $member->chr_name, $member->chr_start, $member->chr_end )
        ];
      }
      next unless $FLAG;
      my $homology_types = HOMOLOGY_TYPES;
      $panel->print( sprintf( '<h3>"%s" homology for gene %s</h3>',
      $homology_types->{$homology->{_description}} || $homology->{_description},
      $homology->{'_this_one_first'} ) );
      my $ss = EnsEMBL::Web::Document::SpreadSheet->new(
        [ { 'title' => 'Species', 'width'=>'20%' },
          { 'title' => 'Gene ID', 'width'=>'20%' },
          { 'title' => 'Peptide ID', 'width'=>'20%' },
          { 'title' => 'Peptide length', 'width'=>'20%' },
          { 'title' => 'Genomic location', 'width'=>'20%' } ],
        $DATA
      );
      $panel->print( $ss->render );
      my $alignio = Bio::AlignIO->newFh(
        -fh     => IO::String->new(my $var),
        -format => renderer_type($object->param('format'))
      );
      print $alignio $sa;
      $panel->print("<pre>$var</pre>\n");
    }
  }
}

sub output_AlignSlice {
    my( $panel, $object ) = @_;

    my $hash = $object->[1];
    my $as = $hash->{_object};
    my $sa = $as->get_SimpleAlign( 'cdna');
    
    (my $sp = $ENV{ENSEMBL_SPECIES}) =~ s/_/ /g;
    
    my @species = grep { $_ !~ /$sp/ } keys %{$as->{slices}};
    
    my $type = $as->get_MethodLinkSpeciesSet->method_link_type;

    $type or $type = $object->param('method');

    my $info = qq{
<table>
  <tr>
    <td> Secondary species: </td>
    <td> %s </td>
  </tr>
  <tr>
    <td> Method: </td>
    <td> %s </td>
  </tr>

</table>
    };

    $panel->print(sprintf($info, join(", ", @species), $type));

    my $alignio = Bio::AlignIO->newFh(
				      -fh     => IO::String->new(my $var),
				      -format => renderer_type($object->param('format'))
			
				     );

    print $alignio $sa;
    $panel->print("<pre>$var</pre>\n");
    
    return ;
}

use EnsEMBL::Web::Document::SpreadSheet;
sub output_DnaDnaAlignFeature {
  my( $panel, $object ) = @_;
  foreach my $align ( @{$object->Obj||[]} ) {
    $panel->printf( qq(<h3>%s alignment between %s %s %s and %s %s %s</h3>),
      $align->{'alignment_type'}, $align->species,  $align->slice->coord_system_name, $align->seqname,
                                $align->hspecies, $align->hslice->coord_system_name, $align->hseqname
    );

    my $BLOCKSIZE = 60;
    my $REG       = "(.{1,$BLOCKSIZE})";
    my ( $ori, $start, $end ) = $align->strand < 0 ? ( -1, $align->end, $align->start ) : ( 1, $align->start, $align->end );
    my ( $hori, $hstart, $hend ) = $align->hstrand < 0 ? ( -1, $align->hend, $align->hstart ) : ( 1, $align->hstart, $align->hend );
    my ( $seq,$hseq) = @{$align->alignment_strings()||[]};
    $panel->print( "<pre>" );
    while( $seq ) {
      $seq  =~s/$REG//; my $part = $1;
      $hseq =~s/$REG//; my $hpart = $1;
      $panel->print( sprintf( "%9d %-60.60s %9d\n%9s ", $start, $part, $start + $ori * ( length( $part) - 1 ),' ' ) );
      my @BP = split //, $part;
      foreach( split //, ($part ^ $hpart ) ) {
        $panel->print( ord($_) ? ' ' : $BP[0] );
        shift @BP;
      }
      $panel->print( sprintf( "\n%9d %-60.60s %9d\n\n", $hstart, $hpart, $hstart + $hori * ( length( $hpart) - 1 ) ) );
      $start += $ori * $BLOCKSIZE;
      $hstart += $hori * $BLOCKSIZE;
    }
    $panel->print( "</pre>" );
  }
}

sub output_External {
  my( $panel, $object ) = @_;
  use Data::Dumper;
  warn Data::Dumper::Dumper( $object->Obj );
  foreach my $align ( @{$object->Obj||[]} ) {
    $panel->print(
      "<pre>",
        map( { $_->{'alignment'} } @{ $align->{'internal_seqs'} } ),
      "</pre>"
    );
  }
  return 1;
}
1;
