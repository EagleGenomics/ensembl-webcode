# $Id$

package EnsEMBL::Web::Component::Gene::GeneSNPTable;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self             = shift;
  my $hub              = $self->hub;
  my $consequence_type = $hub->param('sub_table');
  my $gene             = $self->configure($hub->param('context') || 100, $hub->get_imageconfig('genesnpview_transcript'));
  my @transcripts      = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts};
  
  my $count;
  $count += scalar @{$_->__data->{'transformed'}{'gene_snps'}} foreach @transcripts;
  
  if ($consequence_type || $count < 25) {
    $consequence_type ||= 'ALL';
    my $table_rows = $self->variation_table($consequence_type, \@transcripts);
    my $table      = $table_rows ? $self->make_table($table_rows, $consequence_type) : undef;
    return $self->render_content($table, $consequence_type);
  } else {
    my $table = $self->stats_table(\@transcripts); # no sub-table selected, just show stats
    return $self->render_content($table);
  }
}

sub make_table {
  my ($self, $table_rows, $consequence_type) = @_;
  
  my $columns = [
    { key => 'ID',         sort => 'html'                                                        },
    { key => 'chr' ,       sort => 'position',      title => 'Chr: bp'                           },
    { key => 'Alleles',    sort => 'string',                                   align => 'center' },
    { key => 'Ambiguity',  sort => 'string',                                   align => 'center' },
    { key => 'HGVS',       sort => 'string',        title => 'HGVS name(s)',   align => 'center' },
    { key => 'class',      sort => 'string',        title => 'Class',          align => 'center' },
    { key => 'Source',     sort => 'string'                                                      },
    #{ key => 'status',     sort => 'string',   title => 'Validation',     align => 'center' },
    { key => 'snptype',    sort => 'string',        title => 'Type',                             },
    { key => 'aachange',   sort => 'string',        title => 'Amino Acid',     align => 'center' },
    { key => 'aacoord',    sort => 'position',      title => 'AA co-ordinate', align => 'center' },
    { key => 'sift',       sort => 'position_html', title => 'SIFT',                             },
    { key => 'polyphen',   sort => 'position_html', title => 'PolyPhen',                         },
    { key => 'Transcript', sort => 'string'                                                      },
  ];
  
  return $self->new_table($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ], exportable => 0, id => "${consequence_type}_table" });
}

sub render_content {
  my ($self, $table, $consequence_type) = @_;
  my $stable_id = $self->object->stable_id;
  my $html;
  
  if ($consequence_type) {
    my $label = $consequence_type;#$Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_LABELS{$consequence_type} || 'All';
    
    $html = qq{
      <h2 style="float:left"><a href="#" class="toggle open" rel="$consequence_type">$label variants</a></h2>
      <span style="float:right;"><a href="#$self->{'id'}_top">[back to top]</a></span>
      <p class="invisible">.</p>
    };
  } else {
    $html = qq{<a id="$self->{'id'}_top"></a><h2>Summary of variations in $stable_id by consequence type</h2>};
  }
  
  $html .= sprintf '<div class="toggleable">%s</div>', $table->render;
  
  return $html;
}

sub stats_table {
  my ($self, $transcripts) = @_;
  
  my $hub = $self->hub;
  my $cons_format = $hub->param('consequence_format');
  
  my $columns = [
    { key => 'count', title => 'Number of variants', sort => 'numeric_hidden', width => '20%', align => 'right'  },   
    { key => 'view',  title => '',                   sort => 'none',           width => '5%',  align => 'center' },
    { key => 'type',  title => 'Type',               sort => 'position_html',  width => '20%'                    },   
    { key => 'desc',  title => 'Description',        sort => 'none',           width => '55%'                    },
  ];
  
  my %counts;
  my %total_counts;
  my %ranks;
  my %descriptions;
  my %labels;
  
  my @all_cons = @Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  
  foreach my $con(@all_cons) {
    my $term = $self->select_consequence_term($con, $cons_format);
    
    if($cons_format eq 'so') {
      $labels{$term} = $term;
      $descriptions{$term} = ($con->SO_accession =~ /x/i ? $con->SO_accession : $hub->get_ExtURL_link($con->SO_accession, 'SEQUENCE_ONTOLOGY', $con->SO_accession)) unless $descriptions{$term};
    }
    elsif($cons_format eq 'ncbi') {
      $labels{$term} = $term;
      $descriptions{$term} = '-';
    }
    else {
      $labels{$term} = $con->label;
      $descriptions{$term} = $con->description;
    }
    
    $ranks{$term} = $con->rank if $con->rank < $ranks{$term} || !defined($ranks{$term});
  }
  
  # mini-hack for when NCBI don't have a term
  $ranks{'unclassified'} = 99999999999;
  
  foreach my $tr (@$transcripts) {
    my $tr_stable_id = $tr->stable_id;
    my $tvs          = $tr->__data->{'transformed'}{'snps'} || {};
    my $gene_snps    = $tr->__data->{'transformed'}{'gene_snps'};
    my $tr_start     = $tr->__data->{'transformed'}{'start'};
    my $tr_end       = $tr->__data->{'transformed'}{'end'};
    my $extent       = $tr->__data->{'transformed'}{'extent'};
    
    foreach (@$gene_snps) {
      my ($snp, $chr, $start, $end) = @$_;
      my $vf_id = $snp->dbID;
      my $tv = $tvs->{$vf_id};
      
      if(defined($tv) && $end >= $tr_start - $extent && $start <= $tr_end + $extent) {
        foreach my $tva(@{$tv->get_all_alternate_TranscriptVariationAlleles}) {
          foreach my $con (@{$tva->get_all_OverlapConsequences}) {
            my $key = join "_", ($tr_stable_id, $vf_id, $tva->variation_feature_seq);
            
            my $term = $self->select_consequence_term($con, $cons_format);
            
            $counts{$term}{$key} = 1 if $con;
            $total_counts{$key} = 1;
          }
        }
      }
    }
  }
  my @rows;
  
  my $warning_text = qq{<span style="color:red;">(WARNING: table may not load for this number of variants!)</span>};
  
  foreach my $con (keys %descriptions) {
    if (defined $counts{$con}) {
      my $url = $self->ajax_url . ";sub_table=$con;update_panel=1";
      my $warning = scalar keys %{$counts{$con}} > 10000 ? $warning_text : '';
      
      my $view_html = qq{
        <a href="$url" class="ajax_add toggle closed" rel="$con">
          <span class="closed">Show</span><span class="open">Hide</span>
          <input type="hidden" class="url" value="$url" />
        </a>
      };
      
      push @rows, {
        type  => qq{<span class="hidden">$ranks{$con}</span>$labels{$con}},
        desc  => $descriptions{$con}.' '.$warning,
        count => scalar keys %{$counts{$con}},
        view  => $view_html
      };
    } else {
      push @rows, {
        type  => qq{<span class="hidden">$ranks{$con}</span>$labels{$con}},
        desc  => $descriptions{$con},
        count => 0,
        view  => '-'
      };
    }
  }

  
  # add the row for ALL variations if there are any
  if (my $total   = scalar keys %total_counts) {
      my $url = $self->ajax_url . ';sub_table=ALL;update_panel=1';
  
  # create a hidden span to add so that ALL is always last in the table
      my $hidden_span = qq{<span class="hidden">-</span>};
  
      my $view_html = qq{
	  <a href="$url" class="ajax_add toggle closed" rel="ALL">
	      <span class="closed">Show</span><span class="open">Hide</span>
	      <input type="hidden" class="url" value="$url" />
	      </a>
	  };
  

      my $warning = $total > 10000 ? $warning_text : '';
  
      push @rows, {
	  type  => $hidden_span . 'ALL',
	  view  => $view_html,
	  desc  => "All variations $warning",
	  count => $hidden_span . $total,
      };
  }
  return $self->new_table($columns, \@rows, { data_table => 'no_col_toggle', sorting => [ 'type asc' ], exportable => 0 });
}

sub variation_table {
  my ($self, $consequence_type, $transcripts, $slice) = @_;
  my $hub          = $self->hub;
  my $cons_format = $hub->param('consequence_format');
  my $show_scores = $hub->param('show_scores');
  my @rows;
  
  # create some URLs - quicker than calling the url method for every variation
  my $base_url = $hub->url({
    type   => 'Variation',
    action => 'Mappings',
    vf     => undef,
    v      => undef,
    source => undef,
  });
  
  my $base_trans_url = $hub->url({
    type   => 'Transcript',
    action => 'Summary',
    t      => undef,
  });
  
  foreach my $transcript (@$transcripts) {
    my $transcript_stable_id = $transcript->stable_id;
    
    my %snps = %{$transcript->__data->{'transformed'}{'snps'} || {}};
   
    next unless %snps;
    
    my $gene_snps         = $transcript->__data->{'transformed'}{'gene_snps'} || [];
    my $tr_start          = $transcript->__data->{'transformed'}{'start'};
    my $tr_end            = $transcript->__data->{'transformed'}{'end'};
    my $extent            = $transcript->__data->{'transformed'}{'extent'};
    my $cdna_coding_start = $transcript->Obj->cdna_coding_start;
    my $gene              = $transcript->gene;
    
    foreach (@$gene_snps) {
      my ($snp, $chr, $start, $end) = @$_;
      my $raw_id               = $snp->dbID;
      my $transcript_variation = $snps{$raw_id};
      
      next unless $transcript_variation;
      
      foreach my $tva(@{$transcript_variation->get_all_alternate_TranscriptVariationAlleles}) {
        
        my $skip = 1;
        
        if ($consequence_type eq 'ALL') {
          $skip = 0;
        } elsif ($tva) {
          foreach my $con (@{$tva->get_all_OverlapConsequences}) {
            if ($self->select_consequence_term($con, $cons_format) eq $consequence_type) {
              $skip = 0;
              last;
            }
          }
        }
        
        next if $skip;
        
        if ($tva && $end >= $tr_start - $extent && $start <= $tr_end + $extent) {
          my $validation        = $snp->get_all_validation_states || [];
          my $variation_name    = $snp->variation_name;
          my $var_class         = $snp->var_class;
          my $translation_start = $transcript_variation->translation_start;
          my $source            = $snp->source;
          
          my ($aachange, $aacoord) = $translation_start ? 
            ($tva->pep_allele_string, sprintf('%s (%s)', $transcript_variation->translation_start, (($transcript_variation->cdna_start - $cdna_coding_start) % 3 + 1))) : 
            ('-', '-');
          
          my $url       = "$base_url;v=$variation_name;vf=$raw_id;source=$source";
          my $trans_url = "$base_trans_url;t=$transcript_stable_id";
          
          my $as = $snp->allele_string;
          
          # break up allele string if too long (will disrupt highlight below, but for long alleles who cares)
          $as =~ s/(.{20})/$1\n/g;
          
          # highlight variant allele in allele string
          my $vf_allele = $tva->variation_feature_seq;
          $as =~ s/$vf_allele/<b>$&\<\/b>/ if $as =~ /\//;
          
          # sort out consequence type string
          my $type = join ', ', map {$self->select_consequence_label($_, $cons_format)} @{$tva->get_all_OverlapConsequences || []};
          $type  ||= '-';
          
          my $sift = $self->render_sift_polyphen(
            $tva->sift_prediction || '-',
            $show_scores eq 'yes' ? $tva->sift_score : undef
          );
          my $poly = $self->render_sift_polyphen(
            $tva->polyphen_prediction || '-',
            $show_scores eq 'yes' ? $tva->polyphen_score : undef
          );
          
          my $row = {
            ID         => qq{<a href="$url">$variation_name</a>},
            class      => $var_class,
            Alleles    => $as,#qq{<span style="font-family:Courier New,Courier,monospace;">$as</span>},
            Ambiguity  => $snp->ambig_code,
            status     => (join(', ',  @$validation) || '-'),
            chr        => "$chr:$start" . ($start == $end ? '' : "-$end"),
            Source     => $source,
            snptype    => $type,
            Transcript => qq{<a href="$trans_url">$transcript_stable_id</a>},
            aachange   => $aachange,
            aacoord    => $aacoord,
            sift       => $sift,
            polyphen   => $poly,
          };
          
          # add HGVS if LRG
          $row->{'HGVS'} = $self->get_hgvs($tva) || '-';# if $transcript_stable_id =~ /^LRG/;
          
          push @rows, $row;
        }
      }
    }
  }

  return \@rows;
}

sub configure {
  my ($self, $context, $master_config) = @_;
  my $object = $self->object;
  my $extent = $context eq 'FULL' ? 1000 : $context;
  
  $master_config->set_parameters({
    image_width     => 800,
    container_width => 100,
    slice_number    => '1|1',
    context         => $context
  });

  $object->get_gene_slices(
    $master_config,
    [ 'context',     'normal', '100%'  ],
    [ 'gene',        'normal', '33%'   ],
    [ 'transcripts', 'munged', $extent ]
  );
  
  $object->store_TransformedTranscripts; ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'}
  $object->store_TransformedSNPS;        ## Stores in $transcript_object->__data->{'transformed'}{'snps'}
  
  my $transcript_slice = $object->__data->{'slices'}{'transcripts'}[1];
  my ($count_snps, $snps, $context_count) = $object->getVariationsOnSlice($transcript_slice, $object->__data->{'slices'}{'transcripts'}[2]);
  
  ## Map SNPs for the last SNP display  
  my @snps2 = map {[ 
    $_->[2], $transcript_slice->seq_region_name,
    $transcript_slice->strand > 0 ?
      ( $transcript_slice->start + $_->[2]->start - 1, $transcript_slice->start + $_->[2]->end   - 1 ) :
      ( $transcript_slice->end   - $_->[2]->end   + 1, $transcript_slice->end   - $_->[2]->start + 1 )
  ]} @$snps;

  foreach (@{$object->get_all_transcripts}) {
    $_->__data->{'transformed'}{'extent'}    = $extent;
    $_->__data->{'transformed'}{'gene_snps'} = \@snps2;
  }

  return $object;
}

sub get_hgvs {
  
  my ($self, $tva) = @_;
  
  my $hgvs;
  $hgvs .= $tva->hgvs_coding if defined($tva->hgvs_coding);
  $hgvs .= '<br/>'.$tva->hgvs_protein if defined($tva->hgvs_protein);
  
  $hgvs =~ s/.{30}/$&\n/g;
  
  return $hgvs;
}

sub select_consequence_term {
  my ($self, $con, $format) = @_;
  
  if($format eq 'so') {
    return $con->SO_term;
  }
  elsif($format eq 'ncbi') {
    return $con->NCBI_term || 'unclassified';
  }
  else {
    return $con->display_term;
  }  
}

sub select_consequence_label {
  my ($self, $con, $format) = @_;
  
  if($format eq 'so') {
    return $self->hub->get_ExtURL_link($con->SO_term, 'SEQUENCE_ONTOLOGY', $con->SO_accession);
  }
  elsif($format eq 'ncbi') {
    return $con->NCBI_term || 'unclassified';
  }
  else {
    return '<span title="'.$con->description.'">'.$con->label.'</span>';
  }  
}

1;
