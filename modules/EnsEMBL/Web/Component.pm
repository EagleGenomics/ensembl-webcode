# $Id$

package EnsEMBL::Web::Component;

use strict;

use base qw(EnsEMBL::Web::Root Exporter);

use Exporter;

our @EXPORT_OK = qw(cache cache_print);
our @EXPORT = @EXPORT_OK;

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);
use Text::Wrap qw(wrap);

use Bio::EnsEMBL::DrawableContainer;
use Bio::EnsEMBL::VDrawableContainer;
use Bio::EnsEMBL::ExternalData::DAS::Coordinator;

use EnsEMBL::Web::Document::Image;
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::Constants;
use EnsEMBL::Web::DOM;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Form::ModalForm;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::TmpFile::Text;

sub new {
  my $class = shift;
  my $hub   = shift;
  my $id    = [split /::/, $class]->[-1];
  
  my $self = {
    hub         => $hub,
    builder     => shift,
    renderer    => shift,
    id          => $id,
    view_config => $hub->get_viewconfig($id, $hub->type, 'cache')
  };
  
  bless $self, $class;
  
  $self->_init;
  
  return $self;
}

sub id {
  my $self = shift;
  $self->{'id'} = shift if @_;
  return $self->{'id'};
}

sub builder     { return $_[0]->{'builder'};     }
sub hub         { return $_[0]->{'hub'};         }
sub renderer    { return $_[0]->{'renderer'};    }
sub view_config { return $_[0]->{'view_config'}; }
sub dom         { return $_[0]->{'dom'} ||= new EnsEMBL::Web::DOM; }

sub content_pan_compara {
  my $self = shift;
  return $self->content('compara_pan_ensembl');
}

sub content_text_pan_compara {
  my $self = shift;
  return $self->content_text('compara_pan_ensembl');
}

sub content_align_pan_compara {
  my $self = shift;
  return $self->content_align('compara_pan_ensembl');
}

sub content_alignment_pan_compara {
  my $self = shift;
  return $self->content('compara_pan_ensembl');
}

sub content_ensembl_pan_compara {
  my $self = shift;
  return $self->content_ensembl('compara_pan_ensembl');
}
sub content_other_pan_compara {
  my $self = shift;
  return $self->content_other('compara_pan_ensembl');
}

sub object {
  ## Tries to be backwards compatible
  my $self = shift;
  $self->{'object'} = shift if @_;
  return $self->builder ? $self->builder->object : $self->{'object'};
}

sub cacheable {
  my $self = shift;
  $self->{'cacheable'} = shift if @_;
  return $self->{'cacheable'};
}

sub ajaxable {
  my $self = shift;
  $self->{'ajaxable'} = shift if @_;
  return $self->{'ajaxable'};
}

sub configurable {
  my $self = shift;
  $self->{'configurable'} = shift if @_;
  return $self->{'configurable'};
}

sub cache {
  my ($panel, $obj, $type, $name) = @_;
  my $cache = new EnsEMBL::Web::TmpFile::Text(
    prefix   => $type,
    filename => $name,
  );
  return $cache;
}

sub cache_print {
  my ($cache, $string_ref) = @_;
  $cache->print($$string_ref) if $string_ref;
}

sub format {
  my $self = shift;
  return $self->{'format'} ||= $self->hub->param('_format') || 'HTML';
}

sub html_format {
  my $self = shift;
  return $self->{'html_format'} ||= $self->format eq 'HTML';
}

sub site_name   { return $SiteDefs::SITE_NAME || $SiteDefs::ENSEMBL_SITETYPE; }
sub image_width { return $ENV{'ENSEMBL_IMAGE_WIDTH'}; }
sub has_image   { return 0; }
sub cache_key   { return undef; }
sub caption     { return undef; }
sub _init       { return; }

sub _error   { return shift->_info_panel('error',   @_);  } # Fatal error message. Couldn't perform action
sub _warning { return shift->_info_panel('warning', @_ ); } # Error message, but not fatal
sub _info    { return shift->_info_panel('info',    @_ ); } # Extra information 
sub _hint    {                                              # Extra information, hideable
  my ($self, $id, $caption, $desc, $width) = @_;
  return if grep $_ eq $id, split /:/, $self->hub->get_cookies('ENSEMBL_HINTS');
  return $self->_info_panel('hint hint_flag', $caption, $desc, $width, $id);
} 

sub _info_panel {
  my ($self, $class, $caption, $desc, $width, $id) = @_;
  
  return $self->html_format ? sprintf(
    '<div%s style="width:%s" class="%s"><h3>%s</h3><div class="error-pad">%s</div></div>',
    $id ? qq{ id="$id"} : '',
    $width || $self->image_width . 'px', 
    $class, 
    $caption, 
    $desc
  ) : '';
}

sub config_msg {
  my $self = shift;
  my $url  = $self->hub->url({
    species   => $self->hub->species,
    type      => 'Config',
    action    => $self->hub->type,
    function  => 'ExternalData',
    config    => '_page'
 });
  
  return qq{Click <a href="$url" class="modal_link">"Configure this page"</a> to change the sources of external annotations that are available in the External Data menu.};
}

sub ajax_url {
  my ($self, $function_name, $no_query_string) = @_;
  
  my $hub = $self->hub;
  my ($ensembl, $plugin, $component, $type, $module) = split '::', ref $self;
  
  my $url = join '/', $hub->species_defs->species_path, 'Component', $hub->type, $plugin, $module;
  $url .= "/$function_name" if $function_name && $self->can("content_$function_name");
  $url .= '?_rmd=' . substr md5_hex($ENV{'REQUEST_URI'}), 0, 4;
  $url .= ";$ENV{'QUERY_STRING'}" unless $no_query_string;
  
  return $url;
}

sub EC_URL {
  my ($self, $string) = @_;
  
  my $url_string = $string;
     $url_string =~ s/-/\?/g;
  
  return $self->hub->get_ExtURL_link("EC $string", 'EC_PATHWAY', $url_string);
}

sub glossary_mouseover {
  my ($self, $entry, $display_text) = @_;
  $display_text ||= $entry;
  
  my %glossary = $self->hub->species_defs->multiX('ENSEMBL_GLOSSARY');
  (my $text = $glossary{$entry}) =~ s/<.+?>//g;

  return $text ? qq{<span class="glossary_mouseover">$display_text<span class="floating_popup">$text</span></span>} : $display_text;
}

# Attach all das sources from an image config
sub _attach_das {
  my ($self, $image_config) = @_;

  # Look for all das sources which are configured and turned on
  my @das_nodes = map { $_->get('glyphset') eq '_das' && $_->get('display') ne 'off' ? @{$_->get('logic_names')||[]} : () } $image_config->tree->nodes;
  
  return unless @das_nodes; # Return if no sources to be drawn
  
  my $hub = $self->hub;

  # Check to see if they really exists, and get entries from get_all_das call
  my %T = %{$hub->get_all_das};
  my @das_sources = @T{@das_nodes};

  return unless @das_sources; # Return if no sources exist
  
  my $species_defs = $hub->species_defs;

  # Cache the DAS Coordinator object (with key das_coord)
  $image_config->cache('das_coord',  
    Bio::EnsEMBL::ExternalData::DAS::Coordinator->new(
      -sources => \@das_sources,
      -proxy   => $species_defs->ENSEMBL_WWW_PROXY,
      -noproxy => $species_defs->ENSEMBL_NO_PROXY,
      -timeout => $species_defs->ENSEMBL_DAS_TIMEOUT
    )
  );
}

sub modal_form {
  ## Creates a modal-friendly form with hidden elements to automatically pass to handle wizard buttons
  ## Params Name (Id attribute) for form
  ## Params Action attribute
  ## Params HashRef with keys as accepted by Web::Form::ModalForm constructor

  my ($self, $name, $action, $options) = @_;
  
  my $hub     = $self->hub;
  my $params  = {};
  
  $params->{'action'}   = $params->{'next'} = $action;
  $params->{'current'}  = $hub->action;
  $params->{$_}         = $options->{$_} for qw(class method wizard label back_button no_button buttons_on_top buttons_align);

  if ($options->{'wizard'}) {
    my $species = $hub->type eq 'UserData' ? $hub->data_species : $hub->species;
    
    $params->{'action'}  = $hub->species_path($species) if $species;
    $params->{'action'} .= sprintf '/%s/Wizard', $hub->type;
    my @tracks = $hub->param('_backtrack');
    $params->{'backtrack'} = \@tracks if scalar @tracks; 
  }

  return new EnsEMBL::Web::Form::ModalForm($params);
}

sub new_image {
  my $self        = shift;
  my $hub         = $self->hub;
  my %formats     = EnsEMBL::Web::Constants::FORMATS;
  my $export      = $hub->param('export');
  my $id          = $self->id;
  my $config_type = $self->view_config ? $self->view_config->image_config : undef;
  my (@image_configs, $image_config);
  
  if (ref $_[0] eq 'ARRAY') {
    my %image_config_types;
    
    for (grep $_->isa('EnsEMBL::Web::ImageConfig'), @{$_[0]}) {
      $image_config_types{$_->{'type'}} = 1;
      push @image_configs, $_;
    }
    
    $image_config = $_[0][1];
  } else {
    @image_configs = ($_[1]);
    $image_config  = $_[1];
  }
  
  if ($export) {
    # Set text export on image config
    $image_config->set_parameter('text_export', $export) if $formats{$export}{'extn'} eq 'txt';
    $image_config->set_parameter('sortable_tracks', 0);
  }
  
  $_->set_parameter('component', $id) for grep $_->{'type'} eq $config_type, @image_configs;
  
  my $image = new EnsEMBL::Web::Document::Image($hub->species_defs, \@image_configs);
  $image->drawable_container = new Bio::EnsEMBL::DrawableContainer(@_) if $self->html_format;
  
  return $image;
}

sub new_vimage {
  my $self  = shift;
  my $image = new EnsEMBL::Web::Document::Image($self->hub->species_defs);
  $image->drawable_container = new Bio::EnsEMBL::VDrawableContainer(@_) if $self->html_format;
  
  return $image;
}

sub new_karyotype_image {
  my ($self, $image_config) = @_;  
  my $image = new EnsEMBL::Web::Document::Image($self->hub->species_defs);
  $image->{'object'} = $self->object;
  
  return $image;
}

sub new_table {
  my $self     = shift;
  my $hub      = $self->hub;
  my $table    = new EnsEMBL::Web::Document::SpreadSheet(@_);
  (my $comp    = ref $self) =~ s/[^\w\.]+/_/g;
  
  $table->format     = $self->format;
  $table->exportable = $hub->url unless defined $table->exportable || $self->{'_table_count'}++;
  
  $self->renderer->{'filename'} = join '-', $comp, $hub->filename($self->object);
  
  return $table;
}

sub new_form {
  ## Creates and returns a new Form object.
  ## @param   HashRef as accepted by Form->new
  ## @return  EnsEMBL::Web::Form object
  my ($self, $params) = @_;
  $params->{'dom'} = $self->dom;
  return new EnsEMBL::Web::Form($params);
}

sub _export_image {
  my ($self, $image, $flag) = @_;
  my $hub = $self->hub;
  
  $image->{'export'} = 'iexport' . ($flag ? " $flag" : '');
  
  my ($format, $scale) = $hub->param('export') ? split /-/, $hub->param('export'), 2 : ('', 1);
  $scale eq 1 if $scale <= 0;
  
  my %formats = EnsEMBL::Web::Constants::FORMATS;
  
  if ($formats{$format}) {
    $image->drawable_container->{'config'}->set_parameter('sf',$scale);
    (my $comp = ref $self) =~ s/[^\w\.]+/_/g;
    my $filename = sprintf '%s-%s-%s.%s', $comp, $hub->filename($self->object), $scale, $formats{$format}{'extn'};
    
    if ($hub->param('download')) {
      $hub->input->header(-type => $formats{$format}{'mime'}, -attachment => $filename);
    } else {
      $hub->input->header(-type => $formats{$format}{'mime'}, -inline => $filename);
    }

    if ($formats{$format}{'extn'} eq 'txt') {
      print $image->drawable_container->{'export'};
      return 1;
    }

    $image->render($format);
    return 1;
  }
  
  return 0;
}

sub _matches {
  my ($self, $key, $caption, @keys) = @_;
  
  my $output_as_table = $keys[-1] eq 'RenderAsTables';
  
  pop @keys if $output_as_table; # if output_as_table the last value isn't maningful
  
  my $object       = $self->object;
  my $species_defs = $self->hub->species_defs;
  my $label        = $species_defs->translate($caption);
  my $obj          = $object->Obj;

  # Check cache
  if (!$object->__data->{'links'}) {
    my @similarity_links = @{$object->get_similarity_hash($obj)};
    
    return unless @similarity_links;
    
    $self->_sort_similarity_links($output_as_table, @similarity_links);
  }

  my @links = map { @{$object->__data->{'links'}{$_}||[]} } @keys;

  return unless @links;

  my $db    = $object->get_db;
  my $entry = lc(ref $obj);
  $entry =~ s/bio::ensembl:://;

  my @rows;
  my $html;
  
  if ($species_defs->ENSEMBL_SITETYPE eq 'Vega') {
    $html = '<p></p>';
  } else {
    $html = "<p><strong>This $entry corresponds to the following database identifiers:</strong></p>";
  }
  
  # use tables for formatting if we are not outputting a data table
  $html .= '<table cellpadding="4">' unless $output_as_table;
  
  @links = $self->remove_redundant_xrefs(@links) if $keys[0] eq 'ALT_TRANS';
  
  return unless @links;

  my $list_html;  
  
  # in order to preserve the order, we use @links for acces to keys
  while (scalar @links) {
    my $key = $links[0][0];
    my $j   = 0;
    my $text;
    
    $list_html .= '<div class="small">GO mapping is inherited from swissprot/sptrembl</div>' if $key eq 'GO';
    $list_html .= '</td></tr>' if $key ne '';    
    $list_html .= qq{<tr><th style="white-space: nowrap; padding-right: 1em"><strong>$key:</strong></th><td>};
    
    # display all other vales for the same key
    while ($j < scalar @links) {
      my ($other_key , $other_text) = @{$links[$j]};
      
      if ($key eq $other_key) {
        $list_html .= $other_text;
        $text      .= "$other_text<br />";
        
        splice @links, $j, 1;          
      } else {
        $j++;
      }
    }
    
    $list_html .= "</td></tr>";
    
    push @rows, { dbtype => $key, dbid => $text };
  }
  
  if ($output_as_table) {
    return $html . $self->new_table([ 
        { key => 'dbtype', align => 'left', title => 'External database type' },
        { key => 'dbid',   align => 'left', title => 'Database identifier'    }
      ], \@rows, { data_table => 1, sorting => [ 'dbid asc' ], exportable => 0 }
    )->render;
  } else {
    return "$html$list_html</table>";
  }
}

sub _sort_similarity_links {
  my $self             = shift;
  my $output_as_table  = shift || 0;  
  my @similarity_links = @_;
  my $hub              = $self->hub;
  my $object           = $self->object;
  my $database         = $hub->database;
  my $db               = $object->get_db;
  my $urls             = $hub->ExtURL;
  my $fv_type          = $hub->action eq 'Oligos' ? 'OligoFeature' : 'Xref'; # default link to featureview is to retrieve an Xref
  my (%affy, %exdb);

  # Get the list of the mapped ontologies 
  my @mapped_ontologies = @{$hub->species_defs->SPECIES_ONTOLOGIES || ['GO']};
  my $ontologies = join '|', @mapped_ontologies, 'goslim_goa';

  foreach my $type (sort {
    $b->priority        <=> $a->priority        ||
    $a->db_display_name cmp $b->db_display_name ||
    $a->display_id      cmp $b->display_id
  } @similarity_links) {
    my $link       = '';
    my $join_links = 0;
    my $externalDB = $type->database;
    my $display_id = $type->display_id;
    my $primary_id = $type->primary_id;

    # hack for LRG
    $primary_id =~ s/_g\d*$// if $externalDB eq 'ENS_LRG_gene';
   
    next if $type->status eq 'ORTH';                            # remove all orthologs
    next if lc $externalDB eq 'medline';                        # ditch medline entries - redundant as we also have pubmed
    next if $externalDB =~ /^flybase/i && $display_id =~ /^CG/; # ditch celera genes from FlyBase
    next if $externalDB eq 'Vega_gene';                         # remove internal links to self and transcripts
    next if $externalDB eq 'Vega_transcript';
    next if $externalDB eq 'Vega_translation';
    next if $externalDB eq 'OTTP' && $display_id =~ /^\d+$/;    # don't show vega translation internal IDs
    
    if ($externalDB =~ /^$ontologies$/) {
      push @{$object->__data->{'links'}{'go'}}, $display_id;
      next;
    } elsif ($externalDB eq 'GKB') {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$object->__data->{'links'}{'gkb'}->{$key}}, $type;
      next;
    }
    
    my $text = $display_id;
    
    (my $A = $externalDB) =~ s/_predicted//;
    
    if ($urls && $urls->is_linked($A)) {
#      my $link = $urls->get_url($A, $primary_id);
      $type->{ID} = $primary_id;
      $link = $urls->get_url($A, $type);
      my $word = $display_id;
      $word .= " ($primary_id)" if $A eq 'MARKERSYMBOL';
      
      if ($link) {
        $text = qq{<a href="$link">$word</a>};
      } else {
        $text = $word;
      }
    }
    if ($type->isa('Bio::EnsEMBL::IdentityXref')) {
      $text .= ' <span class="small"> [Target %id: ' . $type->target_identity . '; Query %id: ' . $type->query_identity . ']</span>';
      $join_links = 1;
    }
    
    if ($hub->species_defs->ENSEMBL_PFETCH_SERVER && $externalDB =~ /^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i && ref($object->Obj) eq 'Bio::EnsEMBL::Transcript' && $externalDB !~ /uniprot_genename/i) {
      my $seq_arg = $display_id;
      $seq_arg    = "LL_$seq_arg" if $externalDB eq 'LocusLink';
      
      my $url = $self->hub->url({
        type     => 'Transcript',
        action   => 'Similarity/Align',
        #fucntion => 'Align',
        sequence => $seq_arg,
        extdb    => lc $externalDB
      });
      
      $text .= qq{ [<a href="$url">align</a>] };
    }
    
    $text .= sprintf ' [<a href="%s">Search GO</a>]', $urls->get_url('GOSEARCH', $primary_id) if $externalDB =~ /^(SWISS|SPTREMBL)/i; # add Search GO link;
    
    if ($type->description) {
      (my $D = $type->description) =~ s/^"(.*)"$/$1/;
      
      $text .= '<br />' . encode_entities($D);
      $join_links = 1;
    }
    
    if ($join_links) {
      $text = qq{\n <div>$text};
    } else {
      $text = qq{\n <div class="multicol">$text};
    }
    
    # override for Affys - we don't want to have to configure each type, and
    # this is an internal link anyway.
    if ($externalDB =~ /^AFFY_/i) {
      next if $affy{$display_id} && $exdb{$type->db_display_name}; # remove duplicates
      
      $text = qq{\n  <div class="multicol"> $display_id};
      $affy{$display_id}++;
      $exdb{$type->db_display_name}++;
    }

    # add link to featureview
    ## FIXME - another LRG hack! 
    if ($externalDB eq 'ENS_LRG_gene') {
      my $lrg_url = $self->hub->url({
        type    => 'LRG',
        action  => 'Genome',
        lrg     => $display_id,
      });
    
      $text .= qq{ [<a href="$lrg_url">view all locations</a>]};
    } else {
      my $link_name = $fv_type eq 'OligoFeature' ? $display_id : $primary_id;
      my $link_type = $fv_type eq 'OligoFeature' ? $fv_type    : "${fv_type}_$externalDB";
    
      my $k_url = $self->hub->url({
        type   => 'Location',
        action => 'Genome',
        id     => $link_name,
        ftype  => $link_type
      });
    
      $text .= qq{  [<a href="$k_url">view all locations</a>]};
    }
    
    $text .= '</div>' if $join_links;
    
    my $label = $type->db_display_name || $externalDB;
    $label    = 'LRG' if $externalDB eq 'ENS_LRG_gene'; ## FIXME Yet another LRG hack!
    
    push @{$object->__data->{'links'}{$type->type}}, [ $label, $text ];
  }
}

sub remove_redundant_xrefs {
  my ($self, @links) = @_;
  my %priorities;

  foreach my $link (@links) {
    my ($key, $text) = @$link;
    $priorities{$key} = $text if $text =~ />OTT|>ENST/;
  }

  foreach my $type (
    'Transcript having exact match between ENSEMBL and HAVANA',
    'Ensembl transcript having exact match with Havana',
    'Havana transcript having same CDS',
    'Ensembl transcript sharing CDS with Havana',
    'Havana transcript'
  ) {
    if ($priorities{$type}) {
      my @munged_links;
      $munged_links[0] = [ $type, $priorities{$type} ];
      return @munged_links;;
    }
  }
  
  return @links;
}

sub transcript_table {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $species     = $hub->species;
  my $page_type   = ref($self) =~ /::Gene\b/ ? 'gene' : 'transcript';
  my $description = encode_entities($object->gene_description);
  $description    = '' if $description eq 'No description';
  
  if ($description) {
    my ($edb, $acc);
    
    if ($object->get_db eq 'vega') {
      $edb = 'Vega';
      $acc = $object->Obj->stable_id;
      $description .= sprintf ' <span class="small">%s</span>', $hub->get_ExtURL_link("Source: $edb", $edb . '_' . lc $page_type, $acc);
    } else {
      $description =~ s/EC\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->EC_URL($1)/e;
      $description =~ s/\[\w+:([-\w\/\_]+)\;\w+:([\w\.]+)\]//g;
      ($edb, $acc) = ($1, $2);

      my $l1   =  $hub->get_ExtURL($edb, $acc);
      $l1      =~ s/\&amp\;/\&/g;
      my $t1   = "Source: $edb $acc";
      my $link = $l1 ? qq(<a href="$l1">$t1</a>) : $t1;
      
      $description .= qq( <span class="small">@{[ $link ]}</span>) if $acc && $acc ne 'content';
    }
    
    $description = qq(<dl class="summary">
      <dt>Description</dt>
      <dd>$description</dd>
    </dl>);
  }
  
  my $seq_region_name  = $object->seq_region_name;
  my $seq_region_start = $object->seq_region_start;
  my $seq_region_end   = $object->seq_region_end;
  
  my $location_html = sprintf(
    '<a href="%s">%s: %s-%s</a> %s.',
    $hub->url({
      type   => 'Location',
      action => 'View',
      r      => "$seq_region_name:$seq_region_start-$seq_region_end"
    }),
    $self->neat_sr_name($object->seq_region_type, $seq_region_name),
    $self->thousandify($seq_region_start),
    $self->thousandify($seq_region_end),
    $object->seq_region_strand < 0 ? ' reverse strand' : 'forward strand'
  );
  
  # alternative (Vega) coordinates
  if ($object->get_db eq 'vega') {
    my $alt_assemblies  = $hub->species_defs->ALTERNATIVE_ASSEMBLIES || [];
    my ($vega_assembly) = map { $_ =~ /VEGA/; $_ } @$alt_assemblies;
    
    # set dnadb to 'vega' so that the assembly mapping is retrieved from there
    my $reg        = 'Bio::EnsEMBL::Registry';
    my $orig_group = $reg->get_DNAAdaptor($species, 'vega')->group;
    
    $reg->add_DNAAdaptor($species, 'vega', $species, 'vega');

    my $alt_slices = $object->vega_projection($vega_assembly); # project feature slice onto Vega assembly
    
    # link to Vega if there is an ungapped mapping of whole gene
    if (scalar @$alt_slices == 1 && $alt_slices->[0]->length == $object->feature_length) {
      my $l = $alt_slices->[0]->seq_region_name . ':' . $alt_slices->[0]->start . '-' . $alt_slices->[0]->end;
      
      $location_html .= ' [<span class="small">This corresponds to ';
      $location_html .= sprintf(
        '<a href="%s" target="external">%s-%s</a>',
        $hub->ExtURL->get_url('VEGA_CONTIGVIEW', $l),
        $self->thousandify($alt_slices->[0]->start),
        $self->thousandify($alt_slices->[0]->end)
      );
      
      $location_html .= " in $vega_assembly coordinates</span>]";
    } else {
      $location_html .= sprintf qq{ [<span class="small">There is no ungapped mapping of this %s onto the $vega_assembly assembly</span>]}, lc $object->type_name;
    }
    
    $reg->add_DNAAdaptor($species, 'vega', $species, $orig_group); # set dnadb back to the original group
  }
  
  if ($page_type eq 'gene') {
    # Haplotype/PAR locations
    my $alt_locs = $object->get_alternative_locations;
    
    if (@$alt_locs) {
      $location_html .= '
        <p> This gene is mapped to the following HAP/PARs:</p>
        <ul>';
      
      foreach my $loc (@$alt_locs) {
        my ($altchr, $altstart, $altend, $altseqregion) = @$loc;
        
        $location_html .= sprintf('
          <li><a href="/%s/Location/View?l=%s:%s-%s">%s : %s-%s</a></li>', 
          $species, $altchr, $altstart, $altend, $altchr,
          $self->thousandify($altstart),
          $self->thousandify($altend)
        );
      }
      
      $location_html .= '
        </ul>';
    }
  }
  
  my $html = qq{
    $description
    <dl class="summary">
      <dt>Location</dt>
      <dd>
        $location_html
      </dd>
    </dl>
  };
  
  my $gene = $object->gene;
  
  if ($gene) {
    my $transcript  = $page_type eq 'transcript' ? $object->stable_id : $hub->param('t');
    my $transcripts = $gene->get_all_Transcripts;
    my $count       = @$transcripts;
    my $plural_1    = 'are';
    my $plural_2    = 'transcripts';
    my $action      = $hub->action;
    my %biotype_rows;
    
    my %url_params = (
      type   => 'Transcript',
      action => $page_type eq 'gene' || $action eq 'ProteinSummary' ? 'Summary' : $action
    );
    
    if ($count == 1) { 
      $plural_1 = 'is';
      $plural_2 =~ s/s$//;
    }
    
    my $label = "There $plural_1 $count $plural_2 in this gene";
    
    if ($page_type eq 'transcript') {
      my $gene_id  = $gene->stable_id;
      my $gene_url = $hub->url({
        type   => 'Gene',
        action => 'Summary',
        g      => $gene_id
      });
    
      $label = qq{This transcript is a product of gene <a href="$gene_url">$gene_id</a> - $label};
    }
    
    my $hide = $self->hub->get_cookies('ENSEMBL_transcripts') eq 'close';
    
    $html .= sprintf(qq{
      <dl class="summary">
        <dt id="transcripts" class="toggle_button" title="Click to toggle the transcript table"><span>%s</span><em class="%s"></em></dt>
        <dd>%s</dd>
        <dd class="toggle_info"%s>Click the plus to show the transcript table</dd>
      </dl>
      <table class="toggle_table data_table fixed_width" id="transcripts_table" summary="List of transcripts for this gene - along with translation information and type"%s>
        <thead>
          <tr>
            <th>Name</th>
            <th class="sort_html">Transcript ID</th>
            <th class="sort_numeric">Length (bp)</th>
            <th class="sort_html">Protein ID</th>
            <th class="sort_numeric">Length (aa)</th>
            <th class="sort_html">Biotype</th> 
      }, 
      $page_type eq 'gene' ? 'Transcripts' : 'Gene',
      $hide ? 'closed' : 'open',
      $label,
      $hide ? '' : ' style="display:none"',
      $hide ? ' style="display:none"' : ''
    );

    $html .= '<th class="sort_html">CCDS</th>' if $species =~ /^Homo|Mus/;
    $html .= '
        </tr>
      </thead>
      <tbody>
    ';
    
    foreach (map { $_->[2] } sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } map { [ $_->external_name, $_->stable_id, $_ ] } @$transcripts) {
      my $transcript_length = $_->length;
      my $protein           = 'No protein product';
      my $protein_length    = '-';
      my $ccds              = '-';
      my $url               = $hub->url({ %url_params, t => $_->stable_id });
      
      if ($_->translation) {
        $protein = sprintf(
          '<a href="%s">%s</a>',
          $hub->url({
            type   => 'Transcript',
            action => 'ProteinSummary',
            t      => $_->stable_id
          }),
          $_->translation->stable_id
        );
        
        $protein_length = $_->translation->length;
      }
      
      if (my @CCDS = grep { $_->dbname eq 'CCDS' } @{$_->get_all_DBLinks}) {
        my %T = map { $_->primary_id => 1 } @CCDS;
        @CCDS = sort keys %T;
        $ccds = join ', ', map $hub->get_ExtURL_link($_, 'CCDS', $_), @CCDS;
      }

      (my $biotype = $_->biotype) =~ s/_/ /g;
      
      my $html_row .= sprintf('
        <tr%s>
          <td class="bold">%s</td>
          <td><a href="%s">%s</a></td>
          <td>%s</td>
          <td>%s</td>
          <td>%s</td>
          <td>%s</td>',
        $count == 1 || $_->stable_id eq $transcript ? ' class="active"' : '',
        $_->display_xref ? $_->display_xref->display_id : 'Novel',
        $url,
        $_->stable_id,
        $transcript_length,
        $protein,
        $protein_length,
        $self->glossary_mouseover(ucfirst $biotype)
      );

      $html_row .= "<td>$ccds</td>" if $species =~ /^Homo|Mus/;
      $html_row .= '</tr>';
      
      $biotype = '.' if $biotype eq 'protein coding';
      $biotype_rows{$biotype} = [] unless exists $biotype_rows{$biotype};
      push @{$biotype_rows{$biotype}}, $html_row;
    }

    # Add rows to transcript table sorted by biotype
    foreach my $type (sort { $a cmp $b } keys %biotype_rows) {
      $html .= $_ for @{$biotype_rows{$type}};
    }   

    $html .= qq{
      </tbody>
    </table>
    <form class="data_table_config">
      <input type="hidden" name="asStripClasses" value="['','']" />
    </form>};
  }
  
  return qq{<div class="summary_panel">$html</div>};
}

# Simple subroutine to dump a formatted "warn" block to the error logs - useful when debugging complex
# data structures etc... 
# output looks like:
#
#  ###########################
#  #                         #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  #                         #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  #                         #
#  ###########################
sub _warn_block {
  my $self        = shift;
  my $width       = 128;
  my $border_char = '#';
  my $template    = sprintf "%s %%-%d.%ds %s\n", $border_char, $width-4,$width-4, $border_char;
  my $line        = $border_char x $width;
  
  warn "\n";
  warn "$line\n";
  
  $Text::Wrap::columns = $width-4;
  
  foreach my $l (@_) {
    my $lines = wrap('','', $l);
    
    warn sprintf $template;
    warn sprintf $template, $_ for split /\n/, $lines;
  }
  
  warn sprintf $template;
  warn "$line\n";
  warn "\n";
}

# render a sift or polyphen prediction with colours and a hidden span with a rank for sorting
sub render_sift_polyphen {
  my ($self, $pred, $score) = @_;
  
  my %colours = (
    '-'                 => '',
    'probably damaging' => 'red',
    'possibly damaging' => 'orange',
    'benign'            => 'green',
    'unknown'           => 'blue',
    'tolerated'         => 'green',
    'deleterious'       => 'red'
  );
  
  my %ranks = (
    '-'                 => 0,
    'probably damaging' => 4,
    'possibly damaging' => 3,
    'benign'            => 1,
    'unknown'           => 2,
    'tolerated'         => 1,
    'deleterious'       => 2,
  );
  
  my ($rank, $rank_str);
  
  if(defined($score)) {
    $rank = int(1000 * $score) + 1;
    $rank_str = " ($score)";
  }
  else {
    $rank = $ranks{$pred};
    $rank_str = '';
  }
  
  return qq{
    <span class="hidden">$rank</span>
    <span style="color:$colours{$pred}">$pred$rank_str</span>
  };
}

1;
