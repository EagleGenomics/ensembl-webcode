package EnsEMBL::Web::Wizard::Node::RemoteData;

### Contains methods to create nodes for DAS and remote URL wizards

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::DASConfig;
use Bio::EnsEMBL::ExternalData::DAS::SourceParser qw(@GENE_COORDS @PROT_COORDS);
use base qw(EnsEMBL::Web::Wizard::Node);


sub select_server {
  my $self = shift;
  my $object = $self->object;
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;

  $self->title('Select a DAS server or data file');

  my @preconf_das = $self->object->get_das_servers;

  # DAS server section
  $self->add_element('type'   => 'DropDown',
                     'name'   => 'preconf_das',
                     'select' => 'select',
                     'label'  => "$sitename DAS sources",
                     'values' => \@preconf_das,
                     'value'  => $object->param('preconf_das'));
  $self->add_element('type'   => 'String',
                     'name'   => 'other_das',
                     'label'  => 'or other DAS server',
                     'size'   => '30',
                     'value'  => $object->param('other_das'),
                     'notes'  => '( e.g. http://www.example.com/MyProject/das )');
  $self->add_element('type'   => 'String',
                     'name'   => 'das_name_filter',
                     'label'  => 'Filter sources',
                     'size'   => '30',
                     'value'  => $object->param('das_name_filter'),
                     'notes'  => 'by name, description or URL');
  $self->add_element('type'   => 'Information',
                     'value'  => 'Please note that the next page will take a few moments to load.');
  
}

sub select_das {
### Displays sources for the chosen server as a series of checkboxes 
### (or an error message if no dsns found)
  my $self = shift;

  $self->title('Select a DAS source');
  
  # Get a list of DAS sources (filtered if specified)
  my $sources = $self->object->get_das_server_dsns();
  
  # Process any errors
  if (!ref $sources) {
    $self->add_element( 'type' => 'Information', 'value' => $sources );
  }
  elsif (!scalar @{ $sources }) {
    $self->add_element( 'type' => 'Information', 'value' => 'No sources found' );
  }
  
  # Otherwise add a checkbox element for each DAS source
  else {
    my @already_added = ();
    my $all_das = $ENSEMBL_WEB_REGISTRY->get_all_das(  );
    for my $source (@{ $sources }) {
      
      # If the source is already in the speciesdefs/session/user, skip it
      if ( $all_das->{$source->logic_name} ) {
        push @already_added, $source;
      }
      # Otherwise add a checkbox...
      else {
        $self->add_element( 'type' => 'DASCheckBox', 'das'  => $source );
      }
    } # end DAS source loop
    
    if ( scalar @already_added ) {
      my $noun = scalar @already_added > 1 ? 'sources' : 'source';
      my $note = sprintf 'You have %d DAS %s not shown here that are already configured within %s.',
                         scalar @already_added, $noun,
                         $self->object->species_defs->ENSEMBL_SITETYPE;
      $self->notes( {'heading'=>'Note', 'text'=> $note } );
    }
  } # end if-else
  
}
# Logic method, used for checking a DAS source before adding it
sub validate_das {
  my $self      = shift;
  
  if (! $self->object->param('dsn') ) {
    $self->parameter('error_message', 'No source selected');
    $self->parameter('wizard_next', 'select_das');
    return;
  }
  
  # Get a list of DAS sources (only those selected):
  my $sources = $self->object->get_das_server_dsns( $self->object->param('dsn') );
  
  # Process any errors
  if (!ref $sources) {
    $self->parameter('error_message', $sources);
    $self->parameter('wizard_next', 'select_das');
    return;
  }
  elsif (!scalar @{ $sources }) {
    $self->parameter('error_message', 'No sources selected');
    $self->parameter('wizard_next', 'select_das');
    return;
  }
  
  my $no_species = 0;
  my $no_coords  = 0;
  
  for my $source (@{ $sources }) {
    # If one or more source has missing details, need to fill them in and resubmit
    unless (@{ $source->coord_systems } || $self->object->param('coords')) {
      $no_coords = 1;
      if (!$self->object->param('species')) {
        $no_species = 1;
      }
    }
  }
  
  my $next = $no_species ? 'select_das_species'
           : $no_coords  ? 'select_das_coords'
           : 'attach_das';
  $self->parameter('wizard_next', $next);
  return;
}

# Page method for filling in missing DAS source details
sub select_das_species {
  my $self = shift;
  
  $self->title('Choose a species');
  
  # Get a list of DAS sources (only those selected):
  my $sources = $self->object->get_das_server_dsns( $self->object->param('dsn') );
  
  # Process any errors
  if (!ref $sources) {
    $self->object->param('error_message', $sources);
    $self->object->param('fatal_error', 1);
    return;
  }
  elsif (!scalar @{ $sources }) {
    $self->object->param('error_message', 'No sources found on server');
    $self->object->param('fatal_error', 1);
    return;
  }
  
  $self->add_element( 'type' => 'Information', 'value' => "Which species' do the DAS sources below have data for? If they contain data for all species' (e.g. gene or protein-based sources) choose 'all'. If the DAS sources do not use the same coordinate system, go back and add them individually." );
  
  my @values = map {
    { 'name' => $_, 'value' => $_, }
  } @{ $self->object->species_defs->ENSEMBL_SPECIES };
  unshift @values, { 'name' => 'Not species-specific', 'value' => 'NONE' };
  
  $self->add_element('name'   => 'species',
                     'label'  => 'Species',
                     'type'   => 'MultiSelect',
                     'select' => 1,
                     'value'  => [$self->object->species_defs->ENSEMBL_PRIMARY_SPECIES], # default species
                     'values' => \@values);
  
  $self->add_element( 'type' => 'SubHeader',   'value' => 'DAS Sources' );
  $self->_output_das_text(@{ $sources });
}

sub select_das_coords {
  my $self = shift;
  
  # Get a list of DAS sources (only those selected):
  my $sources = $self->object->get_das_server_dsns( $self->object->param('dsn') );
  
  # Process any errors
  if (!ref $sources) {
    $self->parameter('error_message', $sources);
    $self->parameter('fatal_error', 1);
    return;
  }
  elsif (!scalar @{ $sources }) {
    $self->parameter('error_message', 'No sources found on server');
    $self->parameter('fatal_error', 1);
    return;
  }
  
  my @species = $self->object->param('species');
  if (grep /NONE/, @species) {
    @species = ();
  }
  
  $self->title('Choose a coordinate system');
  $self->add_element( 'type' => 'Header', 'value' => 'Coordinate Systems' );
  
  for my $species (@species) {
    
    my $fieldset =$self->create_fieldset();
    $self->add_fieldset($fieldset);
    $fieldset->legend("Genomic ($species)");
    
    my $csa =  Bio::EnsEMBL::Registry->get_adaptor($species, "core", "CoordSystem");
    my @coords = sort {
      $a->rank <=> $b->rank
    } grep {
      ! $_->is_top_level
    } @{ $csa->fetch_all };
    for my $cs (@coords) {
      $cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_hashref($cs);
      $fieldset->add_element( 'type'    => 'CheckBox',
                             'name'    => 'coords',
                             'value'   => $cs->to_string,
                             'label'   => $cs->label );
    }
  }
  
  my $fieldset =$self->create_fieldset();
  $self->add_fieldset($fieldset);
  $fieldset->legend('Gene');
  
  for my $cs (@GENE_COORDS) {
    $cs->matches_species($ENV{ENSEMBL_SPECIES}) || next;
    $fieldset->add_element( 'type'    => 'CheckBox',
                           'name'    => 'coords',
                           'value'   => $cs->to_string,
                           'label'   => $cs->label );
  }
  
  $fieldset =$self->create_fieldset();
  $self->add_fieldset($fieldset);
  
  for my $cs (@PROT_COORDS) {
    $cs->matches_species($ENV{ENSEMBL_SPECIES}) || next;
    $fieldset->add_element( 'type'    => 'CheckBox',
                           'name'    => 'coords',
                           'value'   => $cs->to_string,
                           'label'   => $cs->label );
  }
  
  $self->add_element( 'type' => 'SubHeader',   'value' => 'DAS Sources' );
  
  for my $source (@{ $sources }) {
    $self->_output_das_text(@{ $sources });
  }
}

# Page method for attaching a DAS source (saving to the session)
sub attach_das {
  my $self = shift;
  
  my @expand_coords = grep { $_ } $self->object->param('coords');
  if (scalar @expand_coords) {
    @expand_coords = map {
      Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_string($_)
    } @expand_coords;
  }
  
  # Get a list of DAS sources (only those selected):
  my $sources = $self->object->get_das_server_dsns( $self->object->param('dsn') );
  
  # Process any errors
  if (!ref $sources) {
    $self->add_element( 'type' => 'Information', 'value' => $sources );
  }
  elsif (!scalar @{ $sources }) {
    $self->add_element( 'type' => 'Information', 'value' => 'No sources found' );
  }
  else {
    $self->title('Attached DAS sources');
    
    my @success = ();
    my @skipped = ();
    
    for my $source (@{ $sources }) {
      
      $source = EnsEMBL::Web::DASConfig->new_from_hashref( $source );
      
      # Fill in missing coordinate systems
      if (!scalar @{ $source->coord_systems }) {
        if ( !scalar @expand_coords ) {
          die sprintf "Source %s has no coordinate systems and none were selected";
        }
        $source->coord_systems(\@expand_coords);
      }
      
      if ($self->object->get_session->add_das($source)) {
        push @success, $source;
      } else {
        push @skipped, $source;
      }

    }
    $self->object->get_session->save_das;
    
    if (scalar @success) {
      $self->add_element( 'type' => 'SubHeader', 'value' => 'The following DAS sources have now been attached:' );
      for my $source (@success) {
        $self->add_element( 'type' => 'Information', 'styles' => ['no-bold'],
                            'value' => sprintf '<strong>%s</strong><br/>%s<br/><a href="%s">%3$s</a>',
                                                                $source->label,
                                                                $source->description,
                                                                $source->homepage );
      }
    }
    
    if (scalar @skipped) {
      $self->add_element( 'type' => 'SubHeader', 'value' => 'The following DAS sources were already attached:' );
      for my $source (@skipped) {
        $self->add_element( 'type' => 'Information', 'styles' => ['no-bold'], 
                            'value' => sprintf '<strong>%s</strong><br/>%s<br/><a href="%s">%3$s</a>',
                                                                $source->label,
                                                                $source->description,
                                                                $source->homepage );
      }
    }
  }
}


sub show_tempdas {
  my $self = shift;
  $self->title('Save source information to your account');

  my $has_data = 0;
  my $das = $self->object->get_session->get_all_das;
  if ($das && keys %$das) {
    $has_data = 1;
    $self->add_element('type'=>'Information', 'value' => 'Choose the DAS sources you wish to save to your account', 'style' => 'spaced');
    my @values;
    foreach my $source (sort { lc $a->label cmp lc $b->label } values %$das) {
      $self->add_element( 'type' => 'DASCheckBox', 'das'  => $source );
    }
  }

  my $url = $self->object->get_session->get_tmp_data('url');
  if ($url && $url->{'url'}) {
    $has_data = 1;
    $self->add_element('type'=>'Information', 'value' => "You have the following URL attached:", 'style' => 'spaced');
    $self->add_element('type'=>'CheckBox', 'name' => 'url', 'value' => 'yes', 'label' => $url->{'url'});
  }

  unless ($has_data) {
    $self->add_element('type'=>'Information', 'value' => "You have no temporary data sources to save. Click on 'Attach DAS' or 'Attach URL' in the left-hand menu to add sources.");
  }
}

sub save_tempdas {
  my $self = shift;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @sources = grep {$_} $self->object->param('dsn');
  
  if ($user && scalar @sources) {
    my $all_das = $self->object->get_session->get_all_das;
    foreach my $logic_name  (@sources) {
      my $das = $all_das->{$logic_name} || warn "*** $logic_name";
      my $result = $user->add_das( $das );
      if ( $result ) {
        $self->parameter('wizard_next', 'ok_tempdas');
      }
      else {
        $self->parameter('wizard_next', 'show_tempdas');
        $self->parameter('error_message', 'Unable to save DAS details to user account');
      }
    }
    $self->parameter('wizard_next', 'ok_tempdas');
    $self->parameter('source', 'ok');
    # Just need to save the session to remove the source - it knows it has changed
    $self->object->get_session->save_das;
  }
  else {
    $self->parameter('wizard_next', 'show_tempdas');
    $self->parameter('error_message', 'Unable to save DAS details to user account');
  }

  ## Save any URL data
  if ($self->object->param('url')) {
    my $url = $self->object->get_session->get_tmp_data('url');
    my $record_id = $user->add_to_urls($url);
    if ($record_id) {
      $self->object->get_session->purge_tmp_data('url');
      $self->parameter('wizard_next', 'ok_tempdas');
      $self->parameter('url', 'ok');
    }
    else {
      $self->parameter('wizard_next', 'show_tempdas');
      $self->parameter('error_message', 'Unable to save URL to user account');
    }
  }
}

sub ok_tempdas {
  my $self = shift;
  
  $self->title('Sources Saved');

  if ($self->object->param('source')) {
    $self->add_element('type'=>'Information', 'value' => 'The DAS source details were saved to your user account.');
    $self->add_element('type'=>'SubHeader', 'value' => 'Saved DAS sources');
    my @das = sort { lc $a->label cmp lc $b->label } values %{ $ENSEMBL_WEB_REGISTRY->get_user->get_all_das };
    $self->_output_das_text(@das);
  }

  if ($self->object->param('url')) {
    $self->add_element('type'=>'Information', 'value' => 'The data URL was saved to your user account.');
  }
}

#------------------------------ URL-based data --------------------------------------

sub check_session {
  my $self = shift;
  my $temp_data = $self->object->get_session->get_tmp_data('url');
  if (keys %$temp_data) {
    $self->parameter('wizard_next', 'overwrite_warning');
  }
  else {
    $self->parameter('wizard_next', 'select_url');
  }
}


sub overwrite_warning {
  my $self = shift;

  $self->notes({'heading'=>'Note', 'text'=>qq(We do not save the data on your server to our database, only the address of the file you wish to view.)});

  $self->add_element(('type'=>'Information', 'value'=>'You already attached a URL source. The address will be overwritten unless it is first saved to your user account.'));

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user) {
    $self->add_element(( type => 'CheckBox', name => 'save', label => 'Save current URL to my account', 'checked'=>'checked' ));
  }
  else {
    $self->add_element(('type'=>'Information', 'styles' => ['no-bold'], 'value'=>'<a href="/Account/Login" class="modal_link">Log into your user account</a> to save the current URL.'));
  }
}


# Page method for attaching from URL
sub select_url {
  my $self = shift;
  my $object = $self->object;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($self->object->param('save') && $user) {
    ## Save current temporary url to user account
    $user->add_to_urls($self->object->get_session->get_tmp_data('url'));
    $self->object->get_session->purge_tmp_data('url');
  }

  # URL-based section
  $self->notes({'heading'=>'Tip', 'text'=>qq(Accessing data via a URL can be slow if the file is large, but the data you see is always the same as the file on your server. For faster access, you can upload files to Ensembl (only suitable for small, single-species datasets).)});

  $self->add_element('type'  => 'String',
                     'name'  => 'url',
                     'label' => 'File URL',
                     'size'   => '30',
                     'value' => $object->param('url'),
                     'notes' => '( e.g. http://www.example.com/MyProject/mydata.gff )');

  if ($user && $user->id) {
    $self->add_element('type'    => 'CheckBox',
                       'name'    => 'save',
                       'label'   => 'Save URL to my account',
                       'notes'   => 'N.B. Only the file address will be saved, not the data itself',
                       'checked' => 'checked');
  }
}


sub attach_url {
  my $self = shift;

  my $url = $self->object->param('url');
  if ($url) {
    $self->object->get_session->set_tmp_data('url' => {
          'url'         => $self->object->param('url'), 
    });
    $self->parameter('wizard_next', 'url_feedback');
  }
  else {
    $self->parameter('wizard_next', 'select_url');
    $self->parameter('error_message', 'No URL was entered. Please try again.');
  }
}

sub url_feedback {
  my $self = shift;
  $self->title('URL attached');

  $self->add_element(
    type  => 'Information',
    value => qq(Thank you - your file was successfully uploaded. Close this Control Panel to view your data),
  );
}


#---------------------- HELPER FUNCTIONS USED BY NODES --------------------------------------

sub _output_das_text {
  my ( $self, @sources ) = @_;
  map {
    $self->add_element( 'type' => 'Information',
                        'value' => sprintf '<strong>%s</strong><br/>%s<br/><a href="%s">%3$s</a>',
                                           $_->label,
                                           $_->description,
                                           $_->homepage );
  } @sources;
}

1;


