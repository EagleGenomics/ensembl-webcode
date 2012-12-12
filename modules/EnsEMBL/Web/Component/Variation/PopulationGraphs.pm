# $Id$

package EnsEMBL::Web::Component::Variation::PopulationGraphs;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $freq_data = $self->object->freqs;
  
	my $graph_type = ($hub->param('graph_type')) ? $hub->param('graph_type') : 'allele';
	
	my $pop_freq;
	my $graph_width = '118';
	if ($graph_type eq 'allele') {
    $pop_freq = $self->format_allele_frequencies($freq_data);
	} else {
	  $pop_freq = $self->format_genotype_frequencies($freq_data);
	  $graph_width = '125';
	}
	
	return '' unless (defined($pop_freq));
  
  my @pop_phase1 = grep{ /phase_1/} keys(%$pop_freq);
  return '' unless (scalar @pop_phase1);
  
  my $graph_id = 0;
  my $height   = 50;
  my (@graphs, $pop_tree, %sub_pops, @alleles);
  
  my @inputs = (
    q{<input class="graph_config" type="hidden" name="legendpos" value="'east'" />},
    q{<input class="graph_config" type="hidden" name="legendmark" value="'arrow'" />},
    '<input class="graph_dimensions" type="hidden" value="[25,25,20]" />',
  );
  
  # Get alleles list
  foreach my $pop_name (sort keys %$pop_freq) {
    my $values   = '';
    my $p_name   = (split ':', $pop_name)[1];
       $pop_tree = $self->update_pop_tree($pop_tree, $pop_name, $pop_freq->{$pop_name}{'sub_pop'}) if defined $pop_freq->{$pop_name}{'sub_pop'};
    
    foreach my $ssid (keys %{$pop_freq->{$pop_name}{'freq'}}) {
      foreach my $allele (keys %{$pop_freq->{$pop_name}{'freq'}{$ssid}}) {
        my $freq = $pop_freq->{$pop_name}{'freq'}{$ssid}{$allele};
        push (@alleles, $allele) if $freq > 0 && !(grep $allele eq $_, @alleles);
      }
    }  
  }
  
  my $nb_alleles = scalar @alleles;
  
  if ($nb_alleles > 2) {
    while ($nb_alleles != 2) {
      $height += 6;
      $nb_alleles--;
    }
  }
  
  # Create graphs
  foreach my $pop_name (sort { ($a !~ /ALL/ cmp $b !~ /ALL/) || $a cmp $b } @pop_phase1) {
    my $values    = '';
    my @pop_names = split ':', $pop_name;
    
    shift @pop_names;
    
    my $p_name     = join ':', @pop_names;
    my $short_name = $self->get_short_name($p_name);
    my $pop_desc   = $pop_freq->{$pop_name}{'desc'};
    
    # Constructs the array for the pie charts: [allele,frequency]
    foreach my $al (@alleles) {
      foreach my $ssid (keys %{$pop_freq->{$pop_name}{'freq'}}) {
        my $freq = $pop_freq->{$pop_name}{'freq'}{$ssid}{$al};
        
        next unless $freq;
        
        $values .= ',' if $values ne '';
        $freq    = 0.5 if $freq < 0.5; # Fixed bug if freq between 0 and 0.5
        $values .= "[$freq,'$al']";
        last;
      }
    }
    
    push @inputs, qq{<input type="hidden" class="graph_data" value="[$values]" />};
    
    if ($short_name =~ /ALL/) {
      push @graphs, sprintf('
        <div class="pie_chart_holder">
          <div class="pie_chart%s" title="%s">
            <h4>%s</h4>
            <div id="graphHolder%s" style="width:%spx;height:%spx"></div>
          </div>
        </div>
      ', $short_name eq 'ALL' ? ' all_population' : '', $pop_desc, $short_name, $graph_id, $graph_width, $height);
    } elsif ($pop_tree->{$short_name}) {
      push @graphs, sprintf('
        <div class="pie_chart_holder">
          <div class="pie_chart" title="%s">
            <h4>%s</h4>
            <div id="graphHolder%s" style="width:%spx;height:%spx"></div>
          </div>
          <a class="toggle set_cookie %s" href="#" rel="population_freq_%s" title="Click to toggle sub-population frequencies">Sub-populations</a>
        </div>
      ', $pop_desc, $short_name, $graph_id, $graph_width, $height, $hub->get_cookie_value("toggle_population_freq_$short_name") eq 'open' ? 'open' : 'closed', $short_name);
    } else {
      foreach (grep $pop_tree->{$_}{$short_name}, keys %$pop_tree) {
        push @{$sub_pops{$_}}, qq{
          <div class="pie_chart_holder">
            <div class="pie_chart" title="$pop_desc">
              <h4>$short_name</h4>
              <div id="graphHolder$graph_id" style="width:${graph_width}px;height:${height}px"></div>
            </div>
          </div>
        };
      }
    }
    
    $graph_id++;
  }
  
	my $switch_to_type = $graph_type eq 'allele' ? 'genotype' : 'allele';
	
	my $switch_link = $hub->url({
                      type   => 'Variation',
                      action => 'Population',
                      v      => $hub->param('v'),
										  vf     => $hub->param('vf'),
										  graph_type => $switch_to_type
                    });
	my $html_link = qq{<img src="/img/var_al-gen_switch.png" style="vertical-align:middle;padding-right:5px"/><a href="$switch_link">Switch to display the $switch_to_type frequency pie charts</a>};
	
  my $html = sprintf( q{<h2>1000 Genomes %s frequencies</h2><div><input type="hidden" class="panel_type" value="PopulationGraph" />%s</div>%s<br /><br />
	                     <div class="population_genetics_pie">%s</div>},
    $graph_type,
		$html_link,
		join('', @inputs),
    join('', @graphs)
  );
  foreach my $sp (sort keys %sub_pops) {
    my $sub_html = join '', @{$sub_pops{$sp}};
    my $show     = $hub->get_cookie_value("toggle_population_freq_$sp") eq 'open';
    
    $html .= sprintf('
      <div class="population_genetics_pie population_freq_%s">
        <div class="toggleable" %s>
          <div><p><b>%s sub-populations</b></p></div>
          %s
        </div>
      </div>
    ', $sp, $show ? '' : 'style="display:none"', $sp, $sub_html);
  }

  return $html;
}

sub format_allele_frequencies {
  my ($self, $freq_data) = @_;
  my $hub = $self->hub;
  my $pop_freq;
  
  foreach my $pop_id (keys %$freq_data) {
	  my $pop_name = $freq_data->{$pop_id}{'pop_info'}{'Name'};
		next if $freq_data->{$pop_id}{'pop_info'}{'Name'} !~ /^1000genomes\:.*/i;
		
		$pop_freq->{$pop_name}{'desc'}    = $freq_data->{$pop_id}{'pop_info'}{'Description'};
    $pop_freq->{$pop_name}{'sub_pop'} = $freq_data->{$pop_id}{'pop_info'}{'Sub-Population'} if scalar keys %{$freq_data->{$pop_id}{'pop_info'}{'Sub-Population'}};
		
    foreach my $ssid (keys %{$freq_data->{$pop_id}{'ssid'}}) {
      next if $freq_data->{$pop_id}{$ssid}{'failed_desc'};
      
      my @allele_freq = @{$freq_data->{$pop_id}{'ssid'}{$ssid}{'AlleleFrequency'}};
      
      foreach my $gt (@{$freq_data->{$pop_id}{'ssid'}{$ssid}{'Alleles'}}) {
        next unless $gt =~ /(\w|\-)+/;
        
        my $freq = $self->format_number(shift @allele_freq);
        
        $pop_freq->{$pop_name}{'freq'}{$ssid}{$gt} = $freq if $freq ne 'unknown';
      }
    }
  }
  
  return $pop_freq;
}

sub format_genotype_frequencies {
  my ($self, $freq_data) = @_;
  my $hub = $self->hub;
  my $pop_freq;
  
  foreach my $pop_id (keys %$freq_data) {
	  my $pop_name = $freq_data->{$pop_id}{'pop_info'}{'Name'};
    next if($freq_data->{$pop_id}{'pop_info'}{'Name'} !~ /^1000genomes\:.*/i);
	 
	  $pop_freq->{$pop_name}{desc} = $freq_data->{$pop_id}{'pop_info'}{'Description'};
      
    if (scalar(keys %{$freq_data->{$pop_id}{'pop_info'}{'Sub-Population'}})) {
      $pop_freq->{$pop_name}{sub_pop} = $freq_data->{$pop_id}{'pop_info'}{'Sub-Population'};
    }

    foreach my $ssid (keys %{$freq_data->{$pop_id}}) {
      next if($freq_data->{$pop_id}{'ssid'}{$ssid}{failed_desc});
			next if(!$freq_data->{$pop_id}{'ssid'}{$ssid}{Genotypes});
      # Freqs genotypes ---------------------------------------------
      my @geno_freq = @{$freq_data->{$pop_id}{'ssid'}{$ssid}{'GenotypeFrequency'}};
      
      foreach my $gt (@{$freq_data->{$pop_id}{'ssid'}{$ssid}{'Genotypes'}}) {
        next unless $gt =~ /(\w|\-)+/;
        
        my $freq = $self->format_number(shift @geno_freq);
        if ($freq ne 'unknown') {
          $pop_freq->{$pop_name}{freq}{$ssid}{$gt} = $freq;
        }
      }
    }
  }
  return $pop_freq;
}


sub format_number {
  ### Population_genotype_alleles
  ### Arg1 : null or a number
  ### Returns "unknown" if null or formats the number to 3 decimal places

  my ($self, $number) = @_;
  $number = $number * 100 if defined $number;
  return defined $number ? sprintf '%.2f', $number : 'unknown';
}

sub update_pop_tree {
  my ($self, $p_tree, $p_name, $sub_list) = @_;
  my $p_short_name = $self->get_short_name($p_name);
  
  foreach my $sub_pop (keys %$sub_list) {
    my $sub_name       = $sub_list->{$sub_pop}{'Name'};
    my $sub_short_name = $self->get_short_name($sub_name);
    
    $p_tree->{$p_short_name}{$sub_short_name} = 1;
  }
  
  return $p_tree;
}

sub get_short_name {
  my $self   = shift;
  my $p_name = shift;
     $p_name =~ /phase_1_(.+)/; # Gets a shorter name for the display
  
  return $1 || $p_name;
}

1;
