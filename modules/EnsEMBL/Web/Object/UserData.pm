# $Id$

package EnsEMBL::Web::Object::UserData;

### NAME: EnsEMBL::Web::Object::UserData
### Object for accessing data uploaded by the user

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk

### DESCRIPTION
### This module does not wrap around a data object, it merely
### accesses user data via the session                                                                                   
use strict;

use Digest::MD5 qw(md5_hex);

use Bio::EnsEMBL::StableIdHistoryTree;
use Bio::EnsEMBL::Utils::Exception qw(try catch);
use Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor;
use Bio::EnsEMBL::Variation::DBSQL::TranscriptVariationAdaptor;
#use Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor;
use Bio::DB::Sam;

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Data::Record::Upload;
use EnsEMBL::Web::Data::Session;
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::Text::Feature::SNP_EFFECT;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::Tools::Misc qw(get_url_filesize);

use base qw(EnsEMBL::Web::Object);

my $DEFAULT_CS = 'DnaAlignFeature';

sub data      :lvalue { $_[0]->{'_data'}; }
sub data_type :lvalue {  my ($self, $p) = @_; if ($p) {$_[0]->{'_data_type'} = $p} return $_[0]->{'_data_type' }; }

sub caption  {
  my $self = shift;
  return 'Custom Data';
}

sub short_caption {
  my $self = shift;
  return 'Data Management';
}

sub counts {
  my $self   = shift;
  my $user   = $self->user;
  my $counts = {};
  return $counts;
}

sub availability {
  my $self = shift;
  my $hash = $self->_availability;
  $hash->{'has_id_mapping'} = $self->table_info( $self->get_db, 'stable_id_event' )->{'rows'} ? 1 : 0;
  $hash->{'has_variation'} = $self->database('variation') ? 1 : 0;
  return $hash;
}

sub check_url_data {
  my ($self, $url) = @_;
  my $error = '';
  my $options = {};

  $url = "http://$url" unless $url =~ /^http/;

  ## Check file size
  my $feedback = get_url_filesize($url);

  if ($feedback->{'error'}) {
    if ($feedback->{'error'} eq 'timeout') {
      $error = 'No response from remote server';
    } elsif ($feedback->{'error'} eq 'mime') {
      $error = 'Invalid mime type';
    } else {
      $error = "Unable to access file. Server response: $feedback->{'error'}";
    }
  } elsif (defined $feedback->{'filesize'} && $feedback->{'filesize'} == 0) {
    $error = 'File appears to be empty';
  }
  else {
    $options = {'filesize' => $feedback->{'filesize'}};
  }
  return ($error, $options);
}

sub check_bam_data {
  my ($self, $url) = @_;
  my $error = '';

  if ($url =~ /^ftp:\/\//i && !$SiteDefs::BAM_ALLOW_FTP) {
    $error = "The bam file could not be added - FTP is not supported, please use HTTP.";
  } 
  else {
    # try to open and use the bam file and its index -
    # this checks that the bam and index files are present and correct, 
    # and should also cause the index file to be downloaded and cached in /tmp/ 
    my ($bam, $index);
    eval {
      $bam = Bio::DB::Bam->open($url);
      $index = Bio::DB::Bam->index($url,0);
      my $header = $bam->header;
      my $region = $header->target_name->[0];
      my $callback = sub {return 1};
      $index->fetch($bam, $header->parse_region("$region:1-10"), $callback);
    };
    warn $@ if $@;
    warn "Failed to open BAM " . $url unless $bam;
    warn "Failed to open BAM index for " . $url unless $index;

    if ($@ or !$bam or !$index) {
        $error = "Unable to open/index remote BAM file: $url<br>Ensembl can only display sorted, indexed BAM files.<br>Please ensure that your web server is accessible to the Ensembl site and that both your .bam and .bai files are present, named consistently, and have the correct file permissions (public readable).";
    }
  }
  return $error;
}

sub check_vcf_data {
  my ($self, $url) = @_;
  my $error = '';

  if ($url =~ /^ftp:\/\//i && !$SiteDefs::ALLOW_FTP_ATTACHMENT) {
    $error = "The VCF file could not be added - FTP is not supported, please use HTTP.";
  } 
  else {
    # try to open and use the VCF file       # this checks that the VCF and index files are present and correct, 
    # and should also cause the index file to be downloaded and cached in /tmp/ 
    my ($dba, $index);
    eval {
      $dba =  Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor->new($url);
      $dba->fetch_variations(1, 1, 10);
    };
    warn $@ if $@;
    warn "Failed to open VCF $url\n $@\n " if $@; 
    warn "Failed to open VCF $url\n $@\n " unless $dba;
          
    if ($@ or !$dba) {
      $error = "Unable to open/index remote VCF file: $url<br>Ensembl can only display sorted, indexed VCF files
<br>Ensure you have sorted and indexed your file and that your web server is accessible to the Ensembl site";
    }
  }
  return $error;
}


#---------------------------------- userdata DB functionality ----------------------------------

sub save_to_db {
  my $self     = shift;
  my %args     = @_;
  my $session  = $self->hub->session;
  my $tmpdata  = $session->get_data(%args);
  my $assembly = $tmpdata->{'assembly'};

  ## TODO: proper error exceptions !!!!!
  my $file = new EnsEMBL::Web::TmpFile::Text(
    filename => $tmpdata->{'filename'}
  );
  
  return unless $file->exists;
  
  my $data = $file->retrieve or die "Can't get data out of the file $tmpdata->{'filename'}";
  
  my $format = $tmpdata->{'format'};
  my $report;

  my $parser = EnsEMBL::Web::Text::FeatureParser->new($self->species_defs);
  $parser->parse($data, $format);

  my $config = {
    action   => 'new', # or append
    species  => $tmpdata->{'species'},
    assembly => $tmpdata->{'assembly'},
    default_track_name => $tmpdata->{'name'}
  };

  if (my $user = $self->user) {
    $config->{'id'} = $user->id;
    $config->{'track_type'} = 'user';
  } else {
    $config->{'id'} = $session->session_id;
    $config->{'track_type'} = 'session';
  }
  
  $config->{'file_format'} = $format; 
  my (@analyses, @messages, @errors);
  my @tracks = $parser->get_all_tracks;
  push @errors, "Sorry, we couldn't parse your data." unless @tracks;
  
  foreach my $track (@tracks) {
    push @errors, "Sorry, we couldn't parse your data." unless keys %$track;
    
    foreach my $key (keys %$track) {
      my $track_report = $self->_store_user_track($config, $track->{$key});
      push @analyses, $track_report->{'logic_name'} if $track_report->{'logic_name'};
      push @messages, $track_report->{'feedback'} if $track_report->{'feedback'};
      push @errors, $track_report->{'error'} if $track_report->{'error'};
    }
  }


  $report->{'browser_switches'} = $parser->{'browser_switches'};
  $report->{'analyses'} = \@analyses if @analyses;
  $report->{'feedback'} = \@messages if @messages;
  $report->{'errors'}   = \@errors   if @errors;
  
  return $report;
}

sub move_to_user {
  my $self = shift;
  my %args = (
    type => 'upload',
    @_,
  );

  my $hub     = $self->hub;
  my $user    = $hub->user;
  my $session = $hub->session;

  my $data = $session->get_data(%args);
  my $record;
  
  $record = $user->add_to_uploads($data)
    if $args{'type'} eq 'upload';

  $record = $user->add_to_urls($data)
    if $args{'type'} eq 'url';

  if ($record) {
    $session->purge_data(%args);
    return $record;
  }
  
  return undef;
}

sub store_data {
  ## Parse file and save to genus_species_userdata
  my $self = shift;
  my %args = @_;
  
  my $hub     = $self->hub;
  my $user    = $hub->user;
  my $session = $hub->session;
  
  my $tmp_data = $session->get_data(%args);
  $tmp_data->{'name'} = $hub->param('name') if $hub->param('name');

  my $report = $self->save_to_db(%args);
  
  unless ($report->{'errors'}) {
    ## Delete cached file
    my $file = new EnsEMBL::Web::TmpFile::Text(
      filename => $tmp_data->{'filename'}
    );
    
    $file->delete;

    ## logic names
    my $analyses = $report->{'analyses'};
    my @logic_names = ref($analyses) eq 'ARRAY' ? @$analyses : ($analyses);

    my $session_id = $session->session_id;    
    
    if ($user) {
      my $upload = $user->add_to_uploads(
        %$tmp_data,
        type     => 'upload',
        filename => '',
        analyses => join(', ', @logic_names),
        browser_switches => $report->{'browser_switches'}||{}
      );
      
      if ($upload) {
        if (!$tmp_data->{'filename'}) {
          my $session_record = EnsEMBL::Web::Data::Session->retrieve(session_id => $session_id, code => $tmp_data->{'code'}) if $session_id && $tmp_data->{'code'};

          $session_record->session_id(EnsEMBL::Web::Data::Session->create_session_id);
          $session_record->save;
        }
        
        $session->purge_data(%args);
        
        return $upload->id;
      }
      
      warn 'ERROR: Can not save user record.';
      
      return undef;
    } else {
      $session->set_data(
         %$tmp_data,
         %args,
         filename => '',
         analyses => join(', ', @logic_names),
         browser_switches => $report->{'browser_switches'}||{},
      );
      
      return $args{code};
    }
  }

  warn Dumper($report->{'errors'}) if $report->{'errors'};
  return undef;
}
  
sub delete_upload {
  my $self    = shift;
  my $hub     = $self->hub;
  my $type    = $hub->param('type');
  my $code    = $hub->param('code');
  my $id      = $hub->param('id');
  my $user    = $hub->user;
  my $session = $hub->session;
  
  if ($type eq 'upload') { 
    my $upload = $session->get_data(type => $type, code => $code);
    
    if ($upload->{'filename'}) {
      EnsEMBL::Web::TmpFile::Text->new(filename => $upload->{'filename'})->delete;
    } else {
      my @analyses = split(', ', $upload->{'analyses'});
      $self->_delete_datasource($upload->{'species'}, $_) for @analyses;
    } 
    
    $session->purge_data(type => $type, code => $code);
  } elsif ($id && $user) {
    my ($upload) = $user->uploads($id);
    
    if ($upload) {
      my @analyses = split(', ', $upload->analyses);
      $code = $upload->code;
      $type = $upload->type;
      
      $self->_delete_datasource($upload->species, $_) for @analyses;
      $upload->delete;
    }
  }
  
  # Remove all shared data with this code and type
  EnsEMBL::Web::Data::Session->search(code => $code, type => $type)->delete_all if $code && $type;
}

sub delete_remote {
  my $self    = shift;
  my $hub     = $self->hub;
  my $type    = $hub->param('type');
  my $code    = $hub->param('code');
  my $id      = $hub->param('id');
  my $user    = $hub->user;
  my $session = $hub->session;
  
  if ($code && $type =~ /^(url)$/) {
    $session->purge_data(type => $type, code => $code);
  }
  elsif ($self->param('logic_name')) {
    my $temp_das = $session->get_all_das;
    if ($temp_das) {
      my $das = $temp_das->{$self->param('logic_name')};
      $das->mark_deleted if $das;
      $session->save_das;
    }
  } 
  elsif ($id && $user) {
    if ($type eq 'das') {
      my ($das) = $user->dases($id);
      if ($das) {
        $das->delete;
      }
    }
    elsif ($type eq 'url') {
      my ($url) = $user->urls($id);
      if ($url) {
        $url->delete;
      }
    }
  }
}


sub _store_user_track {
  my ($self, $config, $track) = @_;
  my $report;

  if (my $current_species = $config->{'species'}) {
    my $action = $config->{action} || 'error';
    if( my $track_name = $track->{config}->{name} || $config->{default_track_name} || 'Default' ) {

      my $logic_name = join '_', $config->{track_type}, $config->{id}, md5_hex($track_name);
  
      my $dbs         = EnsEMBL::Web::DBSQL::DBConnection->new( $current_species );
      my $dba         = $dbs->get_DBAdaptor('userdata');
      unless($dba) {
        $report->{'error'} = 'No user upload database for this species';
        return $report;
      }
      my $ud_adaptor  = $dba->get_adaptor( 'Analysis' );

      my $datasource = $ud_adaptor->fetch_by_logic_name($logic_name);

## Populate the $config object.....
      my %web_data = %{$track->{'config'}||{}};
      delete $web_data{ 'description' };
      delete $web_data{ 'name' };
      $web_data{'styles'} = $track->{styles};
      $config->{source_adaptor} = $ud_adaptor;
      $config->{track_name}     = $logic_name;
      $config->{track_label}    = $track_name;
      $config->{description}    = $track->{'config'}{'description'};
      $config->{web_data}       = \%web_data;
      $config->{method}         = 'upload';
      $config->{method_type}    = $config->{'file_format'};
      if ($datasource) {
        if ($action eq 'error') {
          $report->{'error'} = "$track_name : This track already exists";
        } elsif ($action eq 'overwrite') {
          $self->_delete_datasource_features($datasource);
          $self->_update_datasource($datasource, $config);
        } elsif( $action eq 'new' ) {
          my $extra = 0;
          while( 1 ) {
            $datasource = $ud_adaptor->fetch_by_logic_name(sprintf "%s_%06x", $logic_name, $extra );
            last if ! $datasource; ## This one doesn't exist so we are going to create it!
            $extra++; 
            if( $extra > 1e4 ) { # Tried 10,000 times this guy is keen!
              $report->{'error'} = "$track_name: Cannot create two many entries in analysis table with this user and name";
              return $report;
            }
          }
          $logic_name = sprintf "%s_%06x", $logic_name, $extra; 
          $config->{track_name}     = $logic_name;
          $datasource = $self->_create_datasource($config, $ud_adaptor);   
          unless ($datasource) {
            $report->{'error'} = "$track_name: Could not create datasource!";
          }
        } else { #action is append [default]....
          if ($datasource->module_version ne $config->{assembly}) {
            $report->{'error'} = sprintf "$track_name : Cannot add %s features to %s datasource",
              $config->{assembly} , $datasource->module_version;
          }
        }
      } else {
        $datasource = $self->_create_datasource($config, $ud_adaptor);

        unless ($datasource) {
          $report->{'error'} = "$track_name: Could not create datasource!";
        }
      }

      return $report unless $datasource;
      if( $track->{config}->{coordinate_system} eq 'ProteinFeature' ) {
        $self->_save_protein_features($datasource, $track->{features});
      } else {
        $self->_save_genomic_features($datasource, $track->{features});
      }
      ## Prepend track name to feedback parameter
      $report->{'feedback'} = $track_name;
      $report->{'logic_name'} = $datasource->logic_name;
    } else {
      $report->{'error_message'} = "Need a trackname!";
    }
  } else {
    $report->{'error_message'} = "Need species name";
  }
  return $report;
}

sub _create_datasource {
  my ($self, $config, $adaptor) = @_;

  my $datasource = new Bio::EnsEMBL::Analysis(
    -logic_name     => $config->{track_name},
    -description    => $config->{description},
    -web_data       => $config->{web_data}||{},
    -display_label  => $config->{track_label} || $config->{track_name},
    -displayable    => 1,
    -module         => $config->{coordinate_system} || $DEFAULT_CS,
    -program        =>  $config->{'method'}||'upload',
    -program_version => $config->{'method_type'},
    -module_version => $config->{assembly},
  );

  $adaptor->store($datasource);
  return $datasource;
}

sub _update_datasource {
  my ($self, $datasource, $config) = @_;

  my $adaptor = $datasource->adaptor;

  $datasource->logic_name(      $config->{track_name}                          );
  $datasource->display_label(   $config->{track_label}||$config->{track_name}  );
  $datasource->description(     $config->{description}                         );
  $datasource->module(          $config->{coordinate_system} || $DEFAULT_CS    );
  $datasource->module_version(  $config->{assembly}                            );
  $datasource->web_data(        $config->{web_data}||{}                        );

  $adaptor->update($datasource);
  return $datasource;
}

sub _delete_datasource {
  my ($self, $species, $ds_name) = @_;

  my $dbs  = EnsEMBL::Web::DBSQL::DBConnection->new( $species );
  my $dba = $dbs->get_DBAdaptor('userdata');
  my $ud_adaptor  = $dba->get_adaptor( 'Analysis' );
  my $datasource = $ud_adaptor->fetch_by_logic_name($ds_name);
  my $error;
  if ($datasource && ref($datasource) =~ /Analysis/) {
    $error = $self->_delete_datasource_features($datasource);
    $ud_adaptor->remove($datasource); ## TODO: Check errors here as well?
  }
  return $error;
}

sub _delete_datasource_features {
  my ($self, $datasource) = @_;

  my $dba = $datasource->adaptor->db;
  my $source_type = $datasource->module || $DEFAULT_CS;

  if (my $feature_adaptor = $dba->get_adaptor($source_type)) { # 'DnaAlignFeature' or 'ProteinFeature'
   $feature_adaptor->remove_by_analysis_id($datasource->dbID);
   return undef;
  }
  else {
   return "Could not get $source_type adaptor";
  }
}

sub _save_protein_features {
  my ($self, $datasource, $features) = @_;

  my $uu_dba = $datasource->adaptor->db;
  my $feature_adaptor = $uu_dba->get_adaptor('ProteinFeature');

  my $current_species = $uu_dba->species;

  my $dbs  = EnsEMBL::Web::DBSQL::DBConnection->new( $current_species );
  my $core_dba = $dbs->get_DBAdaptor('core');
  my $translation_adaptor = $core_dba->get_adaptor( 'Translation' );

  my $shash;
  my @feat_array;
  my ($report, $errors, $feedback);

  foreach my $f (@$features) {
    my $seqname = $f->seqname;
    unless ($shash->{ $seqname }) {
      if (my $object =  $translation_adaptor->fetch_by_stable_id( $seqname )) {
        $shash->{ $seqname } = $object->dbID;
      }
    }
    next unless $shash->{ $seqname };

    if (my $object_id = $shash->{$seqname}) {
      eval {
          my($s,$e) = $f->rawstart<$f->rawend?($f->rawstart,$f->rawend):($f->rawend,$f->rawstart);
	  my $feat = new Bio::EnsEMBL::ProteinFeature(
              -translation_id => $object_id,
              -start      => $s,
              -end        => $e,
              -strand     => $f->strand,
              -hseqname   => ($f->id."" eq "") ? '-' : $f->id,
              -hstart     => $f->hstart,
              -hend       => $f->hend,
              -hstrand    => $f->hstrand,
              -score      => $f->score,
              -analysis   => $datasource,
              -extra_data => $f->extra_data,
        );

	  push @feat_array, $feat;
      };

      if ($@) {
	  push @$errors, "Invalid feature: $@.";
      }
    }
    else {
      push @$errors, "Invalid segment: $seqname.";
    }

  }

  $feature_adaptor->save(\@feat_array) if (@feat_array);
  push @$feedback, scalar(@feat_array).' saved.';
  if (my $fdiff = scalar(@$features) - scalar(@feat_array)) {
    push @$feedback, "$fdiff features ignored.";
  }

  $report->{'errors'} = $errors;
  $report->{'feedback'} = $feedback;
  return $report;
}

sub _save_genomic_features {
  my ($self, $datasource, $features) = @_;

  my $uu_dba = $datasource->adaptor->db;
  my $feature_adaptor = $uu_dba->get_adaptor('DnaAlignFeature');

  my $current_species = $uu_dba->species;

  my $dbs  = EnsEMBL::Web::DBSQL::DBConnection->new( $current_species );
  my $core_dba = $dbs->get_DBAdaptor('core');
  my $slice_adaptor = $core_dba->get_adaptor( 'Slice' );

  my $assembly = $datasource->module_version;
  my $shash;
  my @feat_array;
  my ($report, $errors, $feedback);

  foreach my $f (@$features) {
    my $seqname = $f->seqname;
    $shash->{ $seqname } ||= $slice_adaptor->fetch_by_region( undef,$seqname, undef, undef, undef, $assembly );
    if (my $slice = $shash->{$seqname}) {
      eval {
        my($s,$e) = $f->rawstart < $f->rawend ? ($f->rawstart,$f->rawend) : ($f->rawend,$f->rawstart);
	      my $feat = new Bio::EnsEMBL::DnaDnaAlignFeature(
                  -slice        => $slice,
                  -start        => $s,
                  -end          => $e,
                  -strand       => $f->strand,
                  -hseqname     => ($f->id."" eq "") ? '-' : $f->id,
                  -hstart       => $f->hstart,
                  -hend         => $f->hend,
                  -hstrand      => $f->hstrand,
                  -score        => $f->score,
                  -analysis     => $datasource,
                  -cigar_string => $f->cigar_string || ($e-$s+1).'M', #$f->{_attrs} || '1M',
                  -extra_data   => $f->extra_data,
	      );
	      push @feat_array, $feat;

      };
      if ($@) {
	      push @$errors, "Invalid feature: $@.";
      }
    }
    else {
      push @$errors, "Invalid segment: $seqname.";
    }
  }
  $feature_adaptor->save(\@feat_array) if (@feat_array);
  push @$feedback, scalar(@feat_array).' saved.';
  if (my $fdiff = scalar(@$features) - scalar(@feat_array)) {
    push @$feedback, "$fdiff features ignored.";
  }
  $report->{'errors'} = $errors;
  $report->{'feedback'} = $feedback;
  return $report;
}

#---------------------------------- ID history functionality ---------------------------------

sub get_stable_id_history_data {
  my ($self, $file, $size_limit) = @_;
  my $data = $self->fetch_userdata_by_id($file);
  my (@fs, $class, $output, %stable_ids, %unmapped);

  if (my $parser = $data->{'parser'}) { 
    foreach my $track ($parser->{'tracks'}) { 
      foreach my $type (keys %{$track}) {  
        my $features = $parser->fetch_features_by_tracktype($type);
        my $archive_id_adaptor = $self->get_adaptor('get_ArchiveStableIdAdaptor', 'core', $self->species);

        %stable_ids = ();
        my $count = 0;
        foreach (@$features) {
          next if $count >= $size_limit; 
          my $id_to_convert = $_->id;
          my $archive_id_obj = $archive_id_adaptor->fetch_by_stable_id($id_to_convert);
          unless ($archive_id_obj) { 
            $unmapped{$id_to_convert} = 1;
            next;
          }
          my $history = $archive_id_obj->get_history_tree;
          $stable_ids{$archive_id_obj->stable_id} = [$archive_id_obj->type, $history];
          $count++;
        }
      }
    }
  }
  my @data = (\%stable_ids, \%unmapped); 
  return \@data;
}

#------------------------------- Variation functionality -------------------------------
sub calculate_consequence_data {
  my ($self, $file, $size_limit) = @_;
  my $data = $self->hub->fetch_userdata_by_id($file);
  my %slice_hash;
  my %consequence_results;
  my ($f, @new_vfs);
  my $count =0;
  my $feature_count = 0;
  my $file_count = 0;
  my $nearest;
  my %slices;

  ## Get some adaptors for assembling required information
  my $transcript_variation_adaptor;
  my %species_dbs =  %{$self->species_defs->get_config($self->param('species'), 'databases')};
  if (exists $species_dbs{'DATABASE_VARIATION'} ){
    $transcript_variation_adaptor = $self->get_adaptor('get_TranscriptVariationAdaptor', 'variation', $self->param('species'));
  } else  { 
    $transcript_variation_adaptor  = Bio::EnsEMBL::Variation::DBSQL::TranscriptVariationAdaptor->new_fake($self->param('species'));
  }

  my $slice_adaptor = $self->get_adaptor('get_SliceAdaptor', 'core', $self->param('species'));
  my $gene_adaptor = $self->get_adaptor('get_GeneAdaptor', 'core', $self->param('species'));

  ## Convert the SNP features into SNP_EFFECT features
  if (my $parser = $data->{'parser'}){ 
    foreach my $track ($parser->{'tracks'}) {
      foreach my $type (keys %{$track}) { 
        my $features = $parser->fetch_features_by_tracktype($type);
        my $sa = $self->get_adaptor('get_SliceAdaptor', 'core', $self->param('species'));
        my $vfa;
        my %species_dbs =  %{$self->species_defs->get_config($self->param('species'), 'databases')};
        if (exists $species_dbs{'DATABASE_VARIATION'} ){
          $vfa  = $self->get_adaptor('get_VariationFeatureAdaptor', 'variation', $self->param('species'));
        } else  { 
          $vfa = Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor->new_fake($self->param('species'));
        }
        
        # include failed variations
        $vfa->db->include_failed_variations(1) if defined($vfa->db) && $vfa->db->can('include_failed_variations');

        while ( $f = shift @{$features}){
          $file_count++; 
          next if $feature_count >= $size_limit; # $size_limit is max number of v to process, if hit max continue counting v's in file but do not process them 
          $feature_count++;
          # Get Slice
          my $slice;
          if (defined $slice_hash{$f->seqname}){
            $slice = $slice_hash{$f->seqname};
          } else {
            eval { $slice = $sa->fetch_by_region('chromosome', $f->seqname); };
            if(!defined($slice)) {
              $slice = $sa->fetch_by_region(undef, $f->seqname);
            }
          }

          if(!defined($slice)) {
            warn "Could not get slice $f->seqname $f->start $f->end\n";
            next;
          }


          my $pos;
          if ($f->rawstart == $f->rawend){
            $pos = $f->rawstart;
          } else {
            $pos = $f->rawstart .'-'. $f->rawend;
          }

          my $strand;
          if($f->strand =~ /\-/) {
            $strand = -1;
          } else {
            $strand = 1;
          }

          unless ($f->can('allele_string')){
            my $html ='The uploaded data is not in the correct format.
              See <a href="/info/website/upload/index.html#Consequence">here</a> for more details.';
            my $error = 1;
            return ($html, $error);
          }
          
          # name for VF can be specified in extra column or made from location
          # and allele string if not given
          my $new_vf_name = $f->extra || $f->seqname.'_'.$pos.'_'.$f->allele_string;
          
          # Create VariationFeature
          my $vf = Bio::EnsEMBL::Variation::VariationFeature->new(
            -start          => $f->rawstart,
            -end            => $f->rawend,
            -slice          => $slice,
            -allele_string  => $f->allele_string,
            -strand         => $strand,
            -map_weight     => 1,
            -adaptor        => $vfa,
            -variation_name => $new_vf_name,
          );
          # check we have a valid variation feature
          unless ($vf->allele_string){
            my $html ='The uploaded data is not in the correct format.
              See <a href="/info/website/upload/index.html#Consequence">here</a> for more details about the expected format.';
            my $error = 1;
            return ($html, $error);
          }

          ## Turn the variation feature into a SNP_EFFECT feature

          my $location = $vf->seq_region_name .":". $vf->seq_region_start;
          unless ($vf->seq_region_start == $vf->seq_region_end){
            $location .= '-' . $vf->seq_region_end;
          }

          my $transcript_variations = $vf->get_all_TranscriptVariations();
          foreach my $tv (@{$transcript_variations}){
            foreach my $consequence (@{$tv->consequence_type}){

              ## Set default values
              my $gene_id       = '-';
              my $transcript_id = '-';
              my $cdna_pos      = '-';
              my $prot_pos      = '-';
              my $aa            = $tv->pep_allele_string || '-';;
              my $snp           = '-';

              if ($tv->transcript){
                $transcript_id = $tv->transcript->stable_id;
                my $gene = $gene_adaptor->fetch_by_transcript_id($tv->transcript->dbID);
                $gene_id = $gene->stable_id;
              }

              if ($tv->translation_start){
                $prot_pos = $tv->translation_start;
                unless ($tv->translation_start == $tv->translation_end){
                  if ($tv->translation_end < $tv->translation_start){ 
                    $prot_pos = $tv->translation_end .'-' .$prot_pos;
                  } else {
                    $prot_pos .= '-'. $tv->translation_end;
                  }
                }
              }
          
              if ($tv->cdna_start){
                $cdna_pos = $tv->cdna_start;
                unless ($tv->cdna_start == $tv->cdna_end){
                  if ($tv->cdna_end < $tv->cdna_start){
                    $cdna_pos = $tv->cdna_end .'-' .$cdna_pos;
                  } else {
                    $cdna_pos .= '-'. $tv->cdna_end;
                  }
                }
              }

              my $slice_name = $vf->seq_region_name .":" . $location;
              if (exists $slices{$slice_name} ){
                $snp = $slices{$slice_name};
              }
              else {
                my $temp_slice;
                if ($vf->start <= $vf->end){
                  eval { $temp_slice = $slice_adaptor->fetch_by_region("chromosome",
                    $vf->seq_region_name, $vf->seq_region_start,
                    $vf->seq_region_end); };
                  if(!defined($temp_slice)) {
                    $temp_slice = $slice_adaptor->fetch_by_region(undef,
                    $vf->seq_region_name, $vf->seq_region_start,
                    $vf->seq_region_end);
                  }
                } else {
                  eval {
                    $temp_slice = $slice_adaptor->fetch_by_region("chromosome",
                    $vf->seq_region_name, $vf->seq_region_end,
                    $vf->seq_region_start); };
                  if(!defined($temp_slice)) {
                    $temp_slice = $slice_adaptor->fetch_by_region(undef,
                    $vf->seq_region_name, $vf->seq_region_end,
                    $vf->seq_region_start);
                  }
                }

                foreach my $vf (@{$temp_slice->get_all_VariationFeatures()}){
                  next unless ($vf->seq_region_start == $vf->seq_region_start) &&
                  ($vf->seq_region_end == $vf->seq_region_end);
                  $snp = $vf->variation_name;
                  last if defined($snp);
                }

              }

              my $snp_effect = EnsEMBL::Web::Text::Feature::SNP_EFFECT->new([
                  $vf->variation_name, $location, $gene_id, $transcript_id, 
                  $consequence, $cdna_pos, $prot_pos, $aa, $snp
              ]);

              push @new_vfs, $snp_effect;

              # if the array is "full" or there are no more items in @features
              if(scalar @new_vfs == 1000 || scalar @$features == 0) { 
                $count++;
                next if scalar @new_vfs == 0;
                my @feature_block = @new_vfs;
                $consequence_results{$count} = \@feature_block;
                @new_vfs = ();
              }
            }
          }
        }
      }
    }
    $nearest = $parser->nearest;
  }

  if ($file_count <= $size_limit){ 
    return (\%consequence_results, $nearest);
  } else {  
    return (\%consequence_results, $nearest, $file_count);
  }
}

sub consequence_data_from_file {
  my ($self, $code) = @_;
  my $results = {};

  my $data = $self->hub->get_data_from_session('temp', 'upload', $code);
  if (my $parser = $data->{'parser'}){ 
    foreach my $track ($parser->{'tracks'}) {
      foreach my $type (keys %{$track}) { 
        my $vfs = $track->{$type}{'features'};
        $results->{scalar(@$vfs)} = $vfs;
      }
    }
  }
  return $results;
}

sub consequence_table {
  my ($self, $consequence_data) = @_;
  my $hub     = $self->hub;
  my $species = $self->param('species');
  my $columns = [
    { key => 'var',      title =>'Uploaded Variation',      align => 'center' },
    { key => 'location', title =>'Location',                align => 'center' },
    { key => 'gene',     title =>'Gene',                    align => 'center' },
    { key => 'trans',    title =>'Transcript',              align => 'center' },
    { key => 'con',      title =>'Consequence',             align => 'center' },
    { key => 'cdna_pos', title =>'Position in cDNA',        align => 'center' },
    { key => 'prot_pos', title =>'Position in protein',     align => 'center' },
    { key => 'aa',       title =>'Amino acid change',       align => 'center' },
    { key => 'snp',      title =>'Corresponding Variation', align => 'center' }
  ];

  my @rows;

  foreach my $feature_set (keys %$consequence_data) {
    foreach my $f (@{$consequence_data->{$feature_set}}) { 
      my $row               = {};
      my $location          = $f->location;
      my $url_location      = $f->seqname . ':' . ($f->rawstart - 500) . '-' . ($f->rawend + 500);
      my $uploaded_loc      = $f->id;
      my $transcript_id     = $f->transcript;
      my $gene_id           = $f->gene;
      my $consequence       = $f->consequence;
      my $cdna_pos          = $f->cdna_position;
      my $prot_pos          = $f->protein_position;
      my $aa                = $f->aa_change;
      my $snp_id            = $f->snp;
      my $transcript_string = $transcript_id;
      my $gene_string       = $gene_id;
      my $snp_string        = $snp_id;
      
      my $location_url = $hub->url({
        species          => $species,
        type             => 'Location',
        action           => 'View',
        r                =>  $url_location,
        contigviewbottom => 'variation_feature_variation=normal',
      });
      
      if ($transcript_id ne 'N/A') { 
        my $transcript_url = $hub->url({
          species => $species,
          type    => 'Transcript',
          action  => 'Summary',
          t       =>  $transcript_id,
        });
        
        $transcript_string = qq{<a href="$transcript_url">$transcript_id</a>};
      }

      if ($gene_id ne 'N/A') { 
        my $gene_url = $hub->url({
          species => $species,
          type    => 'Gene',
          action  => 'Summary',
          g       =>  $gene_id,
        });
        
        $gene_string = qq{<a href="$gene_url">$gene_id</a>};
      }
      
      if ($snp_id =~ /^\w/){
        my $snp_url =  $hub->url({
          species => $species,
          type    => 'Variation',
          action  => 'Summary',
          v       =>  $snp_id,
        });
        
        $snp_string = qq{<a href="$snp_url">$snp_id</a>};
      }

      $row->{'var'}      = $uploaded_loc;
      $row->{'location'} = qq{<a href="$location_url">$location</a>};
      $row->{'gene'}     = $gene_string;
      $row->{'trans'}    = $transcript_string;
      $row->{'con'}      = $consequence;
      $row->{'cdna_pos'} = $cdna_pos;
      $row->{'prot_pos'} = $prot_pos;
      $row->{'aa'}       = $aa;
      $row->{'snp'}      = $snp_string;

      push @rows, $row;
    }
  }
  
  return new EnsEMBL::Web::Document::SpreadSheet($columns, [ sort { $a->{'var'} cmp $b->{'var'} } @rows ], { margin => '1em 0px' });
}

#---------------------------------- DAS functionality ----------------------------------

sub get_das_servers {
### Returns a hash ref of pre-configured DAS servers
  my $self = shift;
  
  my @domains = ();
  my @urls    = ();

  my $reg_url  = $self->species_defs->get_config('MULTI', 'DAS_REGISTRY_URL');
  my $reg_name = $self->species_defs->get_config('MULTI', 'DAS_REGISTRY_NAME') || $reg_url;

  push( @domains, {'name'  => $reg_name, 'value' => $reg_url} );
  my @extras = @{$self->species_defs->get_config('MULTI', 'ENSEMBL_DAS_SERVERS')};
  foreach my $e (@extras) {
    push( @domains, {'name' => $e, 'value' => $e} );
  }
  #push( @domains, {'name' => $self->param('preconf_das'), 'value' => $self->param('preconf_das')} );

  # Ensure servers are proper URLs, and omit duplicate domains
  my %known_domains = ();
  foreach my $server (@domains) {
    my $url = $server->{'value'};
    next unless $url;
    next if $known_domains{$url};
    $known_domains{$url}++;
    $url = "http://$url" if ($url !~ m!^\w+://!);
    $url .= "/das" if ($url !~ /\/das1?$/);
    $server->{'name'}  = $url if ( $server->{'name'} eq $server->{'value'});
    $server->{'value'} = $url;
  }

  return @domains;
}

# Returns an arrayref of DAS sources for the selected server and species
sub get_das_sources {
  #warn "!!! ATTEMPTING TO GET DAS SOURCES";
  my ($self, $server, @logic_names) = @_;
  my $clearCache = 0;
  
  my $species = $self->species;
  if ($species eq 'common') {
    $species = $self->species_defs->ENSEMBL_PRIMARY_SPECIES;
  }

  my @name  = grep { $_ } $self->param('das_name_filter');
  my $source_info = [];

  $clearCache = $self->param('das_clear_cache');

  ## First check for cached sources
  my $MEMD = new EnsEMBL::Web::Cache;

  my $cache_key;
  if ($MEMD) {
    $cache_key = $server . '::SPECIES[' . $species . ']';

    if ($clearCache) {
      $MEMD->delete($cache_key);
    }
    my $unfiltered = $MEMD->get($cache_key) || [];
    #warn "FOUND SOURCES IN MEMORY" if scalar @$unfiltered;

    foreach my $source (@{ $unfiltered }) {
      push @$source_info, EnsEMBL::Web::DASConfig->new_from_hashref( $source );
    }
  }

  unless (scalar @$source_info) {
    #warn ">>> NO CACHED SOURCES, SO TRYING PARSER";
    ## If unavailable, parse the sources
    my $sources = [];
 
    try {
      my $parser = $self->hub->session->das_parser;

      # Fetch ALL sources and filter later in this method (better for caching)
      $sources = $parser->fetch_Sources(
        -location   => $server,
        -species    => $species || undef,
# DON'T DO IN PARSER       -name       => scalar @name  ? \@name  : undef, # label or DSN
# DON'T DO IN PARSER       -logic_name => scalar @logic_names ? \@logic_names : undef, # the URI
      ) || [];
    
      if (!scalar @{ $sources }) {
        my $filters = @name ? ' named ' . join ' or ', @name : '';
        $source_info = "No $species DAS sources$filters found for $server";
      }
    
    } catch {
      #warn $_;
      if ($_ =~ /MSG:/) {
        ($source_info) = $_ =~ m/MSG: (.*)$/m;
      } else {
        $source_info = $_;
      }
    };

    # Cache simple caches, not objects
    my $cached = [];
    foreach my $source (@{ $sources }) {
      my %copy = %{ $source };
      my @coords = map { my %cs = %{ $_ }; \%cs } @{ $source->coord_systems || [] };
      $copy{'coords'} = \@coords;
      push @$cached, \%copy;
      push @$source_info, EnsEMBL::Web::DASConfig->new_from_hashref( $source );
    }
    ## Cache them for later use
    # Only cache if more than 10 sources, so we don't confuse people in the process of setting
    # up small personal servers (by caching their results half way through their setup).
    if (scalar(@$cached) > 10) {
      $MEMD->set($cache_key, $cached, 1800, 'DSN_INFO', $species) if $MEMD;
    }
  }

  # Do filtering here rather than in das_parser so only have to cache one complete set of sources for server
  
  if (scalar(@logic_names)) {
    #print STDERR "logic_names = |" . join('|',@logic_names) . "|\n";
    @$source_info = grep { my $source = $_; grep { $source->logic_name eq $_ } @logic_names  } @$source_info;
  }
  if (scalar(@name)) {
    @$source_info = grep { my $source = $_; grep { $source->label =~ /$_/i || 
                                                   $source->logic_name =~ /$_/i || 
                                                   $source->description =~ /$_/msi || 
                                                   $source->caption =~ /$_/i } @name  } @$source_info;
  }

  #warn '>>> RETURNING '.@$source_info.' SOURCES';
  return $source_info;
}

1;
