package EnsEMBL::Web::Constants;

use strict;
use warnings;
no warnings 'uninitialized';

sub FORMATS {
  return (
	  'png'  => { 'name' => 'PNG', 'longname' => 'Portable Network Graphics',   'extn' => 'png', 'mime' => 'image/png' },
    'gif'  => { 'name' => 'GIF', 'longname' => 'Graphics Interchange Format', 'extn' => 'gif', 'mime' => 'image/gif' },
	  'svg'  => { 'name' => 'SVG', 'longname' => 'Scalable Vector Graphics',    'extn' => 'svg', 'mime' => 'image/svg+xml' },
	  'eps'  => { 'name' => 'EPS', 'longname' => 'Encapsulated Postscript',     'extn' => 'eps', 'mime' => 'application/postscript' },
	  'pdf'  => { 'name' => 'PDF', 'longname' => 'Portable Document Format',    'extn' => 'pdf', 'mime' => 'application/pdf' },
	  'gff'  => { 'name' => 'GFF', 'longname' => 'General Feature Format',      'extn' => 'txt', 'mime' => 'text/plain' }
  );
}

sub HOMOLOGY_TYPES {
  return {
    'BRH'  => 'Best Reciprocal Hit',
    'UBRH' => 'Unique Best Reciprocal Hit',
    'MBRH' => 'Multiple Best Reciprocal Hit',
    'RHS'  => 'Reciprocal Hit based on Synteny around BRH',
    'DWGA' => 'Derived from Whole Genome Alignment'
  };
}

sub GENE_JOIN_TYPES {
  return {
    'ortholog_one2one'          => 'orthologue',
    'apparent_ortholog_one2one' => 'orthologue',
    'ortholog_one2many'         => 'orthologue_multi',
    'ortholog_many2many'        => 'orthologue_multi',
    'UBRH'                      => 'orthologue',
    'BRH'                       => 'orthologue',
    'MBRH'                      => 'orthologue',
    'RHS'                       => 'orthologue',
    'within_species_paralog'    => 'paralogue',
    'other_paralog'             => 'paralogue',
    'between_species_paralog'   => 'paralogue',
    'putative_gene_split'       => 'hidden',
    'contiguous_gene_split'     => 'hidden'
  }
}

sub ALIGNMENT_FORMATS {
  return (
    'fasta'    => 'FASTA',
    'msf'      => 'MSF',
    'clustalw' => 'CLUSTAL',
    'selex'    => 'Selex',
    'pfam'     => 'Pfam',
    'mega'     => 'Mega',
    'nexus'    => 'Nexus',
    'phylip'   => 'Phylip',
    'psi'      => 'PSI',
  );
}
sub SIMPLEALIGN_DEFAULT { return 'clustalw'; }

sub TREE_FORMATS {
  return (
    'text' => { 
      'caption'    => 'Text dump', 
      'method'     => 'string_tree', 
      'parameters' => [ 'scale' ] 
     },
    'newick' => { 
      'caption'    => 'Newick', 
      'method'     => 'newick_format', 
      'parameters' => [ 'newick_mode' ], 
      'split'      => ',', 
      'link'       => 'http://en.wikipedia.org/wiki/Newick_format'
     },
    'nhx' => { 
      'caption'    => 'New Hampshire eXtended (NHX)', 
      'method'     => 'nhx_format', 
      'parameters' => [ 'nhx_mode' ], 
      'split'      => ',', 
      'link'       => 'http://www.phylosoft.org/forester/NHX.html'
    }
  );
}

sub NHX_OPTIONS {
  return (
    'full'                    => 'Full mode',
    'protein_id'              => 'Protein ID',
    'transcript_id'           => 'Transcript ID',
    'gene_id'                 => 'Gene ID',
    'display_label'           => 'Display label',
    'display_label_composite' => 'Display label composite',
    'simple'                  => 'Simple',
    'phylip'                  => 'PHYLIP',
  );
}

sub NEWICK_OPTIONS {
  return (
    'full'                    => 'Full',
    'full_common'             => 'Full (common)',
    'int_node_id'             => 'Int node id',
    'display_label_composite' => 'Display label composite',
    'full_web'                => 'Full (web)',
    'gene_stable_id'          => 'Gene ID',
    'otu_id'                  => 'OTU ID',
    'simple'                  => 'Simple',
    'species'                 => 'Species',
    'species_short_name'      => 'Short species name',
    'ncbi_taxon'              => 'NCBI taxon',
    'ncbi_name'               => 'NCBI name',
    'njtree'                  => 'NJ tree',
    'phylip'                  => 'PHYLIP',
  );
}

sub FAMILY_EXTERNAL {
  return (
    'swissprot' => { 'name' => 'UniProt/Swiss-Prot' , 'key' => 'Uniprot/SWISSPROT' },
    'trembl'    => { 'name' => 'UniProt/TrEMBL',      'key' => 'Uniprot/SPTREMBL'  }
  );
}

# shared by 'Genomic Alignments', 'Marked-up Sequence' and 'Resequencing'
sub GENERAL_MARKUP_OPTIONS {
  return (
    'snp_display' => {
      'type'     => 'DropDown', 
      'select'   => 'select',
      'required' => 'yes', 
      'name'     => 'snp_display',
      'label'    => 'Show variations',
      'values'   => [
        { 'value' => 'off',       'name' => 'No' },
        { 'value' => 'snp',       'name' => 'Yes' },
        { 'value' => 'snp_link' , 'name' => 'Yes and show links' },
      ]
    },
    'line_numbering' => {
      'type'     => 'DropDown', 
      'select'   => 'select',
      'required' => 'yes',
      'name'     => 'line_numbering',
      'label'    => 'Line numbering',
      'values'   => [
        { 'value' => 'sequence', 'name' => 'Relative to this sequence' },
        { 'value' => 'slice',    'name' => 'Relative to coordinate systems' },
        { 'value' => 'off',      'name' => 'None' },
      ]
    },
    'exon_ori' => {
      'type'     => 'DropDown',
      'select'   => 'select',
      'required' => 'yes',
      'name'     => 'exon_ori',
      'label'    => 'Orientation of additional exons',
      'values'   => [
        { 'value' => 'fwd', 'name' => 'Display same orientation exons only' },
        { 'value' => 'rev', 'name' => 'Display reverse orientation exons only' },
        { 'value' => 'all', 'name' => 'Display exons in both orientations' },
      ],
    },
  );
}

# shared by 'Genomic Alignments' and 'Marked-up Sequence'
sub GENE_MARKUP_OPTIONS {
  return (
    'flank5_display' => {
      'type'     => 'NonNegInt', 
      'required' => 'yes',
      'label'    => "5' Flanking sequence (upstream)",  
      'name'     => 'flank5_display',
      'max'      => 1e6
    },
    'flank3_display' => {
      'type'     => 'NonNegInt', 
      'required' => 'yes',
      'label'    => "3' Flanking sequence (downstream)",  
      'name'     => 'flank3_display',
      'max'      => 1e6
    },
    'exon_display' => {
      'type'     => 'DropDown', 
      'select'   => 'select',
      'required' => 'yes', 
      'name'     => 'exon_display',
      'label'    => 'Additional exons to display',
      'values'   => [
        { 'value' => 'off',       'name' => 'No exon markup' },
        { 'value' => 'Ab-initio', 'name' => 'Ab-initio exons' },
        { 'value' => 'core',      'name' => 'Core exons' },
      ],
    },
  );
}

# shared by 'Genomic Alignments' and 'Resequencing'
sub OTHER_MARKUP_OPTIONS {
  return (
    'display_width' => {
      'type'     => 'DropDown',
      'select'   => 'select',
      'required' => 'yes',
      'name'     => 'display_width',
      'label'    => 'Number of base pairs per row',
      'values'   => [
        map { { 'value' => $_, 'name' => "$_ bps" } } map { $_*15 } (2..12)
      ],
    },
    'codons_display' => {
      'type'     => 'DropDown',
      'select'   => 'select',
      'required' => 'yes',
      'name'     => 'codons_display',
      'label'    => 'Codons',
      'values'   => [
        { 'value' => 'all', 'name' => 'START/STOP codons' },
        { 'value' => 'off', 'name' => 'Do not show codons' },
      ],
    },
    'title_display' => {
      'type'     => 'DropDown',
      'select'   => 'select',
      'required' => 'yes',
      'name'     => 'title_display',
      'label'    => 'Display pop-up information on mouseover',
      'values'   => [
        { 'value' => 'all', 'name' => 'Yes' },
        { 'value' => 'off', 'name' => 'No' },
      ],
    },
  );
}

# shared by transcript and gene snp views
sub VARIATION_OPTIONS {
  return (
    'variation' =>  {
      'opt_freq'      =>  [ 'on', 'By frequency' ],
      'opt_cluster'   =>  [ 'on', 'By Cluster' ],
      'opt_doublehit' =>  [ 'on', 'By doublehit' ],
      'opt_submitter' =>  [ 'on', 'By submitter' ],
      'opt_hapmap'    =>  [ 'on', 'Hapmap' ],
      'opt_noinfo'    =>  [ 'on', 'No information' ],
    }, 
    'class' =>  {
      'opt_in-del'    =>  [ 'on', 'In-dels' ],
      'opt_snp'       =>  [ 'on', 'SNPs' ],
      'opt_mixed'     =>  [ 'on', 'Mixed variations' ],
      'opt_microsat'  =>  [ 'on', 'Micro-satellite repeats' ],
      'opt_named'     =>  [ 'on', 'Named variations' ],
      'opt_mnp'       =>  [ 'on', 'MNPs' ],
      'opt_het'       =>  [ 'on', 'Hetrozygous variations' ],
      'opt_'          =>  [ 'on', 'Unclassified' ]
    }, 
    'type' => {
      'opt_non_synonymous_coding'   =>  [ 'on', 'Non-synonymous', 32 ],
      'opt_frameshift_coding'       =>  [ 'on', 'Frameshift', 16 ],
      'opt_synonymous_coding'       =>  [ 'on', 'Synonymous', 128 ],
      'opt_5prime_utr'              =>  [ 'on', "5' UTR", 1024 ],
      'opt_3prime_utr'              =>  [ 'on', "3' UTR", 2048 ],
      'opt_intronic'                =>  [ 'on', 'Intronic', 4096 ],
      'opt_downstream'              =>  [ 'on', 'Downstream', 32768 ],
      'opt_upstream'                =>  [ 'on', 'Upstream', 16384 ],
      'opt_intergenic'              =>  [ 'on', 'Intergenic', 131072 ],
      'opt_essential_splice_site'   =>  [ 'on', 'Essential splice site', 1 ],
      'opt_splice_site'             =>  [ 'on', 'Splice site', 64 ],
      'opt_regulatory_region'       =>  [ 'on', 'Regulatory region', 256 ],
      'opt_stop_gained'             =>  [ 'on', 'Stop gained', 2 ],
      'opt_stop_lost'               =>  [ 'on', 'Stop lost', 4 ],
      'opt_sara'                    =>  [ 'on', 'SARA (same as ref.assembly)', 65537 ],
      'opt_complex_indel'           =>  [ 'on', 'Complex Indel', 8 ],
      'opt_within_mature_mirna'     =>  [ 'on', 'Within mature miRNA', 512 ],
      'opt_within_non_coding_gene'  =>  [ 'on', 'Within non coding gene', 8192 ],
      'opt_no_consequence'          =>  [ 'on', 'No consequence', 65536 ]
    },
  );
}

sub MESSAGE_PRIORITY {
  return (
    '_error',
    '_warning',
    '_info',
    '_hint'
  ); 
}

1;
