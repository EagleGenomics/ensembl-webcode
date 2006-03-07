package EnsEMBL::Web::Component::LD;

# Puts together chunks of XHTML for LD-based displays

### TESTING #############################################################
# TEST SNPs  gives and ERROR 1065427
# 3858116 has TSC sources, 557122 hapmap (works), 2259958 (senza-hit), 625 multi-hit, lots of LD 2733052, 2422821, 12345
# Problem snp  	1800704 has no upstream, downstream seq,  slow one: 431235
# Variation object: has all the data (flanks, alleles) but no position
# VariationFeature: has position (but also short cut calls to allele etc.) 
#                   for contigview
########################################################################

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Component;
use Spreadsheet::WriteExcel;
our @ISA = qw( EnsEMBL::Web::Component);
use POSIX qw(floor ceil);



## Info panel functions ################################################
# focus              : i.e. gene, SNP or slice
# prediction_method  : standard blurb about calculation of LD
# population_info    : name, size, description of population
#                      super/sub population info if exists
########################################################################

sub focus {
  my ( $panel, $object ) = @_;
  my ( $info, $focus );
  if ( $object->param("gene") ) {
    $focus = "Gene";
    my $gene_id = $object->name;
    $info = ("Gene ". $gene_id);
    $info .= "  [<a href='geneview?gene=$gene_id'>View in GeneView</a>]";
  }

  elsif ( $object->param("snp") ) {
    $focus = "SNP";
    my $snp  = $object->__data->{'snp'}->[0];
    my $name = $snp->name;
    my $source = $snp->source;
    my $link_name  = $object->get_ExtURL_link($name, 'SNP', $name) if $source eq 'dbSNP';
    $info .= "$link_name ($source ". $snp->source_version.")";
    my $params = qq( [<a href="snpview?snp=$name;source=$source);
    $params .= ";c=".$object->param('c') if $object->param('c');
    $params .= ";pop=".$object->param('pop') if $object->param('pop');
  }
  else {
    return 1;
  }
  $panel->add_row( "Focus: $focus", $info );
  return 1;
}

#-----------------------------------------------------------------------------

sub prediction_method {
 my($panel, $object) = @_;
 my $label = "Prediction method";
 my $info = 
 "<p>LD values were calculated by a pairwise
 estimation between SNPs genotyped in the same individuals and within a
 100kb window.  An established method was used to estimate the maximum 
 likelihood of the proportion that each possible haplotype contributed to the
 double heterozygote.</p>";

 $panel->add_row( $label, $info );
 return 1;
}

#-----------------------------------------------------------------------------

sub population_info {
  my ( $panel, $object ) = @_;
  my $pop_names  = $object->current_pop_name;

  unless (@$pop_names) {
    $panel->add_row("Population", "Please select a population from the yellow drop down menu below.");
    return ;
  }

  foreach my $name (@$pop_names) {
    my $pop       = $object->pop_obj_from_name($name);
    my $super_pop = $object->extra_pop($pop->{$name}{PopObject}, "super");
    my $sub_pop   = $object->extra_pop($pop->{$name}{PopObject}, "sub");
    my $html = print_pop_info($object, $pop, "Population");
    $html   .= print_pop_info($object, $super_pop, "Super-population");
    $panel->add_row( "Population", "<table>$html</table>");
  }
  return 1;
}



# Use this if there is more than one mapping for SNP  -----------------------
sub mappings {
  my ( $panel, $object ) = @_;
  my $view = "ldview";
  my $snp  = $object->__data->{'snp'};
  my %mappings = %{ $snp->[0]->variation_feature_mapping };
  return [] unless keys %mappings;
  my $source = $snp->[0]->source;

  my @table_header;
  foreach my $varif_id (keys %mappings) {
    my %chr_info;
    my $region = $mappings{$varif_id}{Chr};
    my $start  = $mappings{$varif_id}{start};
    my $end    = $mappings{$varif_id}{end};
    my $link   = "/@{[$object->species]}/contigview?l=$region:" .($start - 10) ."-" . ($end+10);
    my $strand = $mappings{$varif_id}{strand};
    $strand = " ($strand)&nbsp;" if $strand;
    if ($region) {
      $chr_info{chr} = "<nobr><a href= $link>$region: $start-$end</a>$strand </nobr>";
    } else {
      $chr_info{chr} = "unknown";
    }
    my $vari = $snp->[0]->name;
    my $choice = "<a href='$view?snp=$vari;c=$region:$start;w=10000'>Choose this location</a>";
    my $display = int($object->centrepoint +0.5) eq $start ? "Current location":$choice;
    $chr_info{location} = $display;

    $panel->add_row(\%chr_info);
  }
  unshift (@table_header,{key =>'location', title => 'Location'});
  unshift (@table_header, {key =>'chr',title => 'Genomic location (strand)'});

  $panel->add_columns(@table_header);
  return 1;
}

# IMAGE CALLS ################################################################

sub ldview_image_menu {
  my($panel, $object ) = @_;
  my ($count_snps, $snps) = $object->getVariationsOnSlice();
  my $user_config = $object->user_config_hash( 'ldview' );
  $user_config->{'_databases'}     = $object->DBConnection;
  $user_config->{'_add_labels'}    = 'true';
  $user_config->{'Populations'}    = $object->pops_for_slice(100000);
  $user_config->{'_ld_population'} = $object->current_pop_name;
  $user_config->{'snps'}           = $snps;

  my $mc = $object->new_menu_container(
    'configname'  => 'ldview',
    'panel'       => 'bottom',
    'leftmenus'  => [qw(Features Population Source Options Export ImageSize)],
    'rightmenus' => [qw(SNPHelp)],
    #  'fields' => {
#       'snp'          => $object->param('snp'),
#       'gene'         => $object->param('gene'),
#       'pop'          => $object->current_pop_name,
#       'w'            => $object->length,
#       'c'            => $object->seq_region_name.':'.$object->centrepoint,  
#       'source'       => $object->param('source'),
#       'h'            => $object->highlights_string,
#     }
  );
  $panel->print( $mc->render_html );
  $panel->print( $mc->render_js );
  return 0;
}

#-----------------------------------------------------------------------------

sub ldview_image {
  my($panel, $object) = @_;
  my ($seq_region, $start, $end, $seq_type ) = ($object->seq_region_name, $object->seq_region_start, $object->seq_region_end, $object->seq_region_type);

  my $slice =
    $object->database('core')->get_SliceAdaptor()->fetch_by_region(
    $seq_type, $seq_region, $start, $end, 1
  );
  my $wuc = $object->user_config_hash( 'ldview' );

  $wuc->set( '_settings', 'width', $object->param('image_width'));
  $wuc->container_width($slice->length);

  # If you want to resize this image
  my $image = $object->new_image( $slice, $wuc, [$object->name] );
  $image->imagemap = 'yes';
  $panel->print( $image->render );
  return 0;
}


#-------------------------------------------------------------------------
sub ldview_noimage {
  my ($panel, $object) = @_;
  $panel->print("<p>Unable to draw context as we cannot uniquely determine the SNP's location</p>");
  return 1;
}


# OPTIONS FORM CALLS ##############################################

sub options {
  my ( $panel, $object ) = @_;
  $panel->print("<p>Use the yellow drop down menus at the top of the image to configure display and data you wish to dump.  If no LD values are displayed, zoom out, choose another population or another region. </p>");
  my $html = qq(
   <div>
     @{[ $panel->form( 'options' )->render() ]}
  </div>);

  $panel->print( $html );
  return 1;
}


sub options_form {
  my ($panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new('ldview_form', "/@{[$object->species]}/ldtableview", 'get' );

  my  @formats = ( {"value" => "astext",  "name" => "As text"},
	#	   {"value" => "asexcel", "name" => "In Excel format"},
		   {"value" => "ashtml",  "name" => "HTML format "}
		 );

  return $form unless @formats;
  $form->add_element( 'type' => 'Hidden', 
		      'name' => '_format', 
		      'value'=>'HTML' );
  $form->add_element(
    'class'     => 'radiocheck1col',
    'type'      => 'DropDown',
    'renderas'  => 'checkbox',
    'name'      => 'dump',
    'label'     => 'Dump format',
    'values'    => \@formats,
    'value'     => $object->param('dump') || 'ashtml'
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



###############################################################################
#               INTERNAL CALLS
###############################################################################

sub tagged_snp {
  my $object  = shift;
  my $snps = $object->__data->{'snp'};
  return 0 unless $snps && @$snps;
  my $snp_data  = $snps->[0]->tagged_snp;
  return unless %$snp_data;

  my $current_pop  = $object->current_pop_name;
  for my $pop_id (keys %$snp_data) {
    return "Yes" if $pop_id == $current_pop;
  }
  return "No";
}




# Internal LD calls: Population Info  ---------------------------------------

sub print_pop_info {
  my ($object, $pop, $label ) = @_;
  my $count;
  my $return;

  foreach my $pop_name (keys %$pop) {
    my $display_pop = _pop_url($object,  $pop->{$pop_name}{Name}, 
				       $pop->{$pop_name}{PopLink});

    my $description = $pop->{$pop_name}{Description} || "unknown";
    $description =~ s/\.\s+.*//; # descriptions are v. long. Stop after 1st "."

    my $size = $pop->{$pop_name}{Size}|| "unknown";
    $return .= "<th>$label: </th><td>$display_pop &nbsp;[size: $size]</td></tr>";
    $return .= "<tr><th>Description:</th><td>".
      ($description)."</td>";

    if ($object->param('snp') && $label eq 'Population') {
      my $tagged = tagged_snp($object);
      $return .= "<tr><th>SNP in tagged set for this population:<br /></th>
                   <td>$tagged</td>" if $tagged;
    }
  }
  return unless $return;
  $return = "<tr>$return</tr>";
  return $return;
}


sub _pop_url {
  my ($object, $pop_name, $pop_dbSNP) = @_;
  return $pop_name unless $pop_dbSNP;
  return $object->get_ExtURL_link( $pop_name, 'DBSNPPOP', $pop_dbSNP->[0] );
}


#------------------------------------------------------------------------------

1;

__END__

=head1 EnsEMBL::Web::Component::LD;

=head2 SYNOPSIS

This object is called from a Configuration object e.g. from package EnsEMBL::Web::Configuration::Location;
   
   use EnsEMBL::Web::Component::LD;

For each component to be displayed, you need to create an appropriate panel object and then add the component.  The description of each component indicates the usual Panel subtype e.g. Panel::Image.

  my $info_panel = $self->new_panel( "Information",
    "code"    => "info#",
    "caption"=> "Linkage disequilibrium report: [[object->type]] [[object->name]]"
				   )) {

    $info_panel->add_components(qw(
    focus                EnsEMBL::Web::Component::LD::focus
    prediction_method    EnsEMBL::Web::Component::LD::prediction_method
    population_info      EnsEMBL::Web::Component::LD::population_info
				  ));
    $self->{page}->content->add_panel( $info_panel );

=head2 DESCRIPTION

This class consists of methods for displaying data related to linkage disequilibrium for a slice, a slice based on a gene or a slice based on a SNP.  Current components include:

=head2 METHODS

Except where indicated, all methods take the same two arguments, a Document::Panel object and a Proxy::Object object (data). In general components return true on completion. If true is returned and the components are chained (see notes in Ensembl::Web::Configuration) then the subsequence components are ignored; if false is returned any subsequent components are executed.

Methods for information panel:
  focus
  prediction_method
  population_info

If there is more than one mapping for a SNP:
  mappings

For the image panel:
  ldview_image_menu
  ldview_image
  ldview_noimage

For section on dumping out the data:
  options
  options_form

=head3 B<Accessor methods>

=over 4

=item B<tagged_snp>          Returns "Yes" if tagged SNP, else "No" or 0

=item B<print_pop_info>      Returns HTML string with population data

=item B<_pop_url>            Returns HTML string of link to population in dbSNP

=back



=head3 package EnsEMBL::Web::Document::DropDown::Menu:


=head3 B<focus>

    Description : adds pair of values (type of focus e.g gene or snp and the ID) to panel if the paramater "gene" or "snp" is defined


=head3 B<prediction_method>

   Description : Adds text information about the prediction method


=head3 B<population_info>

   Description : Returns information about the population.  Calls helper function print_pop_info to get population data (name, size, description, whether the SNP is tagged)



=head3 B<mappings>

 Description : table showing Variation feature mappings to genomic locations. May only display when a SNP maps to more than one location


=head2 -Image calls-

=head3 B<ldview_image_menu>

 Example  : $image_panel->add_components(qw(
      menu  EnsEMBL::Web::Component::LD::ldview_image_menu
      image EnsEMBL::Web::Component::LD::ldview_image
    ));
 Description : Creates a menu container for ldview and adds it to the panel
 Return type : 0


=head3 B<ldview_image>

 Example  : $image_panel->add_components(qw(
      menu  EnsEMBL::Web::Component::LD::ldview_image_menu
      image EnsEMBL::Web::Component::LD::ldview_image
    ));
 Description : Gets the slice, creates the user config
               Creates the image, imagemap and renders the image
 Return type : 0



=head3 B<ldview_noimage>

 Description : Adds an HTML string to the panel if the LD cannot be mapped uniquely


=head3 B<options>

 Description: Adds text to the page instructing user how to navigate round page


=head3 B<options_form>

  Description :  Creates a new form to dump LD data in different formats (html, text, in the future excel and haploview)
  Return      :  $form


=head2 -ACCESSOR CALLS-

=head3 B<tagged_snp>

    Arg[1]      : Object
    Description : Gets the SNP object off the proxy object and checks if SNP is
                  a tagged SNP in the current population
    Return type : string "Yes" or "No" or 0


=head3 B<print_pop_info> 

  Arg[1]      : population object
  Arg[1]      : label (e.g. "Super-Population" or "Sub-Population")
  Example     : From population_info
                print_pop_info($super_pop, "Super-Population"). 
  Description : Returns information about the population: name, size, description and whether it is a tagged SNP
  Return type : html string


=head3 B<_pop_url>  ### ALSO IN SNP RENDERER

   Arg 1       : Proxy object
   Arg 2       : Population name (to be displayed)
   Arg 3       : dbSNP population ID (variable to be linked to)
   Example     : _pop_url($pop_name, $pop_dbSNPID);
   Description : makes pop_name into a link
   Return type : html string


=head2 BUGS AND LIMITATIONS

None known at present.


=head2 AUTHOR

Fiona Cunningham, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org

=head2 COPYRIGHT

See http://www.ensembl.org/info/about/code_licence.html

=cut

