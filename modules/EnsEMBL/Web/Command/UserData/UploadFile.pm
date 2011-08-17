# $Id$

package EnsEMBL::Web::Command::UserData::UploadFile;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::Tools::Misc qw(get_url_content);

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $hub = $self->hub;
  my $url = $object->species_path($object->data_species);
  my $param = {};
  my $error = $hub->input->cgi_error;

  if ($error =~ /413/) {
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'too_big';
  }

  my @methods = qw(text file url);
  my $method;
  foreach my $M (@methods) {
    if ($hub->param($M)) {
      $method = $M;
      last;
    }
  }

  if ($hub->param($method)) {
    $param = upload($method, $hub);
    if (!$param->{'format'}) {
      $url .= '/UserData/MoreInput';
    }
    else {
      $url .= '/UserData/UploadFeedback';
    } 
  }
  else {
    $url .= '/UserData/SelectFile';
  }

  $url = encode_entities($self->url($url, $param));

  $self->r->content_type('text/html; charset=utf-8');

  print qq{
  <html>
  <head>
    <script type="text/javascript">
      if (!window.parent.Ensembl.EventManager.trigger('modalOpen', { href: '$url', title: 'File uploaded' })) {
        window.parent.location = '$url';
      }
    </script>
  </head>
  <body><p>UP</p></body>
  </html>};
}

sub upload {
## Separate out the upload, to make code reuse easier
  my ($method, $hub) = @_;
  my $param = {};
  my ($error, $format, $full_ext, %args);
  my @orig_path = split('/', $hub->param($method));
  my $filename = $orig_path[-1];

  my $name = $hub->param('name');
  ## Need the filename (for handling zipped files)
  if ($method eq 'text') {
    $name = 'Data' unless $name;
  }
  else {
    my @orig_path = split('/', $hub->param($method));
    $filename = $orig_path[-1];
    $args{'filename'} = $filename;
    $name = $filename unless $name;
  }
  $param->{'name'} = $name;

  ## Has the user specified a format?
  my $f_param = $hub->param('format');
  if ($f_param) {
    $format = $f_param;
  }
  else {
    ## Try to guess the format from the extension
    unless ($method eq 'text') {
      my @parts = split('\.', $filename);
      my $ext = $parts[-1];
      if ($ext =~ /gz/i) {
        $ext = $parts[-2];
      }
      my $extensions;
      my $format_info = $hub->species_defs->DATA_FORMAT_INFO;
      foreach my $f (@{$hub->species_defs->UPLOAD_FILE_FORMATS}) {
        $format = uc $ext if ($format_info->{$f}{'ext'} =~ /$ext/i);
      }
    }
  }
  $param->{'format'} = $format;

  ## Set up parameters for file-writing
  if ($method eq 'url') {
    my $url = $hub->param('url');
    $url = 'http://'.$url unless $url =~ /^http/;
    my $response = get_url_content($url);
    $error = $response->{'error'};
    $args{'content'} = $response->{'content'};
  }
  elsif ($method eq 'text') {
    $args{'content'} = $hub->param('text');
  }
  else {
    #$args{'extension'} = $full_ext;
    $args{'tmp_filename'} = $hub->input->tmpFileName($hub->param($method));
  }

  ## Add upload to session
  if ($error) {
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'no_response';
  }
  else {
    my $file = new EnsEMBL::Web::TmpFile::Text(prefix => 'user_upload', %args);
  
    if ($file->content) {
      if ($file->save) {
        my $code = $file->md5 . '_' . $hub->session->session_id;
        my ($sec, $min, $hr, $mday, $mon, $year) = localtime();
        my $timestamp = sprintf '%s-%s-%s %s:%s:%s', (1900 + $year), ($mon + 1), $mday, $hr, $min, $sec;

        $param->{'species'} = $hub->param('species') || $hub->species;
        ## Attach data species to session
        $hub->session->add_data(
          type      => 'upload',
          filename  => $file->filename,
          filesize  => length($file->content),
          code      => $code,
          md5       => $file->md5,
          name      => $name,
          species   => $hub->param('species'),
          format    => $format,
          assembly  => $hub->param('assembly'),
          timestamp => $timestamp,
        );

        $param->{'code'} = $code;
      }
      else {
        $param->{'filter_module'} = 'Data';
        $param->{'filter_code'} = 'no_save';
      }
    }
    else {
      $param->{'filter_module'} = 'Data';
      $param->{'filter_code'} = 'empty';
    }
  }
  return $param;
}

1;
