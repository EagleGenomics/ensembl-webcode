package EnsEMBL::Web::Data::Bio::Variation;

### NAME: EnsEMBL::Web::Data::Bio::Variation
### Base class - wrapper around a Bio::EnsEMBL::Variation API object 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::Variation

### DESCRIPTION:
### This module provides additional data-handling
### capabilities on top of those provided by the API

use strict;

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
  ### Converts a set of API objects into simple parameters 
  ### for use by drawing code and HTML components
  
  my $self     = shift;
  my $data     = $self->data_objects;
  my $hub      = $self->hub;
  my @phen_ids = $hub->param('ph');
  my $ga       = $hub->database('core')->get_adaptor('Gene');
  my (@results, %associated_genes, %p_value_logs, %p_values, %phenotypes_sources, %phenotypes_studies);
  
  # getting associated phenotypes and associated genes
  foreach my $pf (@{$data || []}) {
    my $object_id   = $pf->object_id;
    my $source_name = $pf->source;
       $source_name =~ s/_/ /g;
    my $study_xref  = ($pf->study) ? $pf->study->external_reference : undef;
    
    $phenotypes_sources{$object_id}{$source_name} = 1;
    $phenotypes_studies{$object_id}{$study_xref} = 1 if ($study_xref);
    
    # only get the p value log 10 for the pointer matching phenotype id and variation id
    if (grep $pf->{'_phenotype_id'} == $_, @phen_ids) {
      $p_value_logs{$object_id} = -(log($pf->p_value) / log(10)) unless $pf->p_value == 0;      
      $p_values{$object_id}     = $pf->p_value;
      
      # if there is more than one associated gene (comma separated), split them to generate the URL for each of them
      foreach my $id (grep $_, split /,/, $pf->associated_gene) {
        $id =~ s/\s//g;
        $associated_genes{$object_id}{$id} = $_->description for @{$ga->fetch_all_by_external_name($id) || []};
      }
    }
  }
  
  my %seen;
  
  foreach my $pf (@$data) {
    if (ref($pf) =~ /UnmappedObject/) {
      push @results, $self->unmapped_object($pf);
      next;
    }
    
    # unique key on name and location
    my $name        = $pf->object_id;
    my $seq_region  = $pf->seq_region_name;
    my $start       = $pf->seq_region_start;
    next if $seen{$name.$seq_region.$start};
    $seen{$name.$seq_region.$start} = 1;
    
    my $object_type = $pf->type;
    my $end         = $pf->seq_region_end;
    my $dbID        = $pf->dbID;
    my $id_param    = $object_type;
       $id_param    =~ s/[a-z]//g;
       $id_param    = lc $id_param;
    my %url_params;
 
    # making the location 10kb if it a one base pair
    if ($end == $start) {
      $start -= 5000;
      $end   += 5000;
    }
    
    # make zmenu link
    if ($object_type =~ /^(Gene|Variation|StructuralVariation)$/) {
      %url_params = (
        type      => 'ZMenu',
        ftype     => 'Xref',
        action    => $object_type,
        $id_param => $name,
        vdb       => 'variation'
      );
      
      $url_params{'p_value'} = $p_value_logs{$name} if defined $p_value_logs{$name};
      $url_params{'regions'} = sprintf '%s:%s-%s', $seq_region, $pf->seq_region_start, $pf->seq_region_end if $object_type eq 'Variation';
    } else {
      # use simple feature for QTL and SupportingStructuralVariation
      %url_params = (
        type          => 'ZMenu',
        ftype         => 'Xref',
        action        => 'SimpleFeature',
        display_label => $name,
        logic_name    => $object_type,
        bp            => "$seq_region:$start-$end",
      );
    }
    
    push @results, {
      region  => $seq_region,
      start   => $start,
      end     => $end,
      strand  => $pf->strand,
      html_id => "${name}_$dbID", # The html id is used to match the feature on the karyotype (html_id in area tag) with the row in the feature table (table_class in the table row)
      label   => $name,
      href    => $hub->url(\%url_params),       
      p_value => $p_value_logs{$name},
      extra   => {
        feat_type   => $object_type,
        phe_sources => join(', ', sort keys %{$phenotypes_sources{$name}    || {}}),
        phe_studies => $self->_pf_external_reference_link($phenotypes_studies{$name}),
        'p-values'  => ($p_value_logs{$name} ? sprintf('%.1f', $p_value_logs{$name}) : '-'), 
      },
    };
  }
  
  return [ \@results, [
    { key => 'feat_type',   title => 'Feature type',            sort => ''        },
    { key => 'genes',       title => 'Reported gene(s)',        sort => 'html'    },
    { key => 'phe_sources', title => 'Annotation source(s)',    sort => ''        },
    { key => 'phe_studies', title => 'Study',                   sort => ''        },
    { key => 'p-values',    title => 'P value (negative log)',  sort => 'numeric' },
  ]];
}

sub _pf_external_reference_link {
  my ($self, $xrefs) = @_;
  
  my $html;
  
  foreach my $xref (sort keys(%$xrefs)) {
    my $link;
    if($xref =~ /pubmed/) {
      $link = qq{http://www.ncbi.nlm.nih.gov/$xref};
      $xref =~ s/\//:/g;
      $html .= qq{<a rel="external" href="$link">$xref</a>; };
    }
    elsif($xref =~ /^MIM\:/) {
      foreach my $mim (split /\,\s*/, $xref) {
        my $id = (split /\:/, $mim)[-1];
        my $sub_link = $self->hub->get_ExtURL_link($mim, 'OMIM', $id);
        $link .= ', '.$sub_link;
        $link =~ s/^\, //g;
      }
      $html .= "$link; ";
    }
    else {
      $html .= "$xref; ";
    }
  }
  $html =~ s/;\s$//;
  
  return $html;
}

1;
