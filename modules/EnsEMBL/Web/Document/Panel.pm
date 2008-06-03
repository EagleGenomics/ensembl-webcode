package EnsEMBL::Web::Document::Panel;
use strict;
use EnsEMBL::Web::Root;
use CGI qw(escape escapeHTML);
use EnsEMBL::Web::Document::Renderer::GzCacheFile;
use EnsEMBL::Web::Document::Renderer::Excel;
use EnsEMBL::Web::Document::Renderer::String;

our @ISA = qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;
  my $self = {
    '_renderer' => undef,
    'forms' => {},
    'components'   => {},
    'component_order' => [],
    'prefix' => 'p',
    'asychronous_components' => [],
    @_
  };
  bless $self, $class;
  return $self;
}

sub prefix {
  my ($self, $value) = @_;
  if ($value) { 
    $self->{'prefix'} = $value;
  }
  return $self->{'prefix'};
}

sub load_asynchronously {
  my ($self, @names) = @_;
  foreach my $name (@names) {
    push @{ $self->{'asynchronous_components'} }, $name;
    warn "Loading asynchronously: " . $name;
  }
}

sub is_asynchronous {
  my ($self, $name) = @_;
  my $found = 0;
  foreach my $component (@{ $self->{'asynchronous_components'} }) {
    if ($component eq $name) {  
      $found = 1;
    }
  }
  return $found;

}

sub clear_components { $_[0]{'components'} = {}; $_[0]->{'component_order'} = []; }
sub components       { return @{$_[0]{'component_order'}}; }

sub component{
  # Given a component code, returns the component itself
  my $self = shift;
  my $code = shift;
  return $self->{'components'}->{$code};
}


=head2 Panel options.

There are five functions which set, clear and read the options for the panel

=over 4

=item C<$panel-E<gt>clear_option( $key )>

resets the option C<$key>

=item C<$panel-E<gt>add_option( $key, $val )>

sets the value of option C<$key> to C<$val>

=item C<$panel-E<gt>option( $key )>

returns the value of option C<$key>

=item C<$panel-E<gt>clear_options>

resest the options list

=item C<$panel-E<gt>options>

returns an array of option keys.

=back

=cut

sub clear_options { $_[0]{_options} = {};            }
sub clear_option  { delete $_[0]->{_options}{$_[1]}; }
sub add_option    { $_[0]{_options}{$_[1]} = $_[2];  }
sub option        { return $_[0]{_options}{$_[1]};   }
sub options       { return keys %{$_[0]{_options}};  }

sub caption {
    my $self = shift;
    $self->{'caption'} = shift if (@_);
    return $self->{'caption'};
}

=head2 Panel components.

There are a number of functions which set, clear, modify the list of 
components which make up the panel.

=over 4

=item C<$panel-E<gt>add_components(       $new_key, $function_name, [...] )>

Adds one or more components to the end of the component list

=item C<$panel-E<gt>remove_component(    $key )>

Removes the function called by the component named C<$key>

=item C<$panel-E<gt>replace_component(    $key,     $function_name )>

Replaces the function called by the component named C<$key> with a new function
named C<$function_name>

=item C<$panel-E<gt>prepend_to_component( $key,     $function_name )>

Extends a component, by adding another function call to the start of the list
keyed by name C<$key>. When the page is rendered each function for the component
will be called in turn (until one returns 0)

=item C<$panel-E<gt>add_to_component(     $key,     $function_name )>

Extends a component, by adding another function call to the end of the list
keyed by name C<$key>. When the page is rendered each function for the component
will be called in turn (until one returns 0)

=item C<$panel-E<gt>add_component_before( $key,     $new_key, $function_name )>

Adds a new component to the component list before the one
named C<$key>, and gives it the name C<$new_key>

=item C<$panel-E<gt>add_component_after(  $key,     $new_key, $function_name )>

Adds a new component to the component list after the one
named C<$key>, and gives it the name C<$new_key>

=item C<$panel-E<gt>add_component_first(  $new_key, $function_name )>

Adds a new component to the start of the component list and gives it the name C<$new_key>

=item C<$panel-E<gt>add_component_last(   $new_key, $function_name )>

Adds a new component to the end of the component list and gives it the name C<$new_key>

=item C<$panel-E<gt>add_component(        $new_key, $function_name )>

Adds a new component to the end of the component list and gives it the name C<$new_key>

=back 

=cut

sub add_components {
  my $self = shift;
  while( my($code, $function) = splice( @_, 0, 2) ) {
    if( exists( $self->{'components'}{$code} ) ) {
      push @{ $self->{'components'}{$code} }, $function;
    } else {
      push @{ $self->{'component_order'} }, $code;
      $self->{'components'}{$code} = [ $function ];
    }
  }
}

sub replace_component {
  my( $self, $code, $function, $flag ) = @_;
  if( $self->{'components'}{$code} ) {
    $self->{'components'}{$code} = [$function ];
  } elsif( $flag ne 'no' ) {
    $self->add_component_last( $code, $function );
  }
}

sub prepend_to_component {
  my( $self, $code, $function ) = @_;
  return $self->add_component_first( $code, $function ) unless exists $self->{'components'}{$code};
  unshift @{ $self->{'components'}{$code} }, $function;
}

sub add_to_component {
  my( $self, $code, $function ) = @_;
  return $self->add_component_last( $code, $function ) unless exists $self->{'components'}{$code};
  push @{ $self->{'components'}{$code} }, $function;
}

sub add_component_before {
  my( $self, $oldcode, $code, $function ) = @_;
  return $self->prepend_to_component( $code, $function )    if exists $self->{'components'}{$code};
  return $self->add_component_first( $code, $function ) unless exists $self->{'components'}{$oldcode};
  my $C = 0;
  foreach( @{$self->{'component_order'}} ) {
    if( $_ eq $oldcode ) {
      splice @{$self->{'component_order'}}, $C,0,$code;
      $self->{'components'}{$code} = [ $function ];
      return;
    }
    $C++;
  }
}

sub add_component_first {
  my( $self, $code, $function ) = @_;
  return $self->prepend_to_component( $code, $function )    if exists $self->{'components'}{$code};
  unshift @{ $self->{'component_order'} }, $code;
  $self->{'components'}{$code} = [ $function ];
}

sub add_component { my $self = shift; $self->add_component_last( @_ ); }

sub add_component_last {
  my( $self, $code, $function ) = @_;
  return $self->add_to_component( $code, $function )    if exists $self->{'components'}{$code};
  push @{ $self->{'component_order'} }, $code;
  $self->{'components'}{$code} = [ $function ];
}

sub add_component_after {
  my( $self, $oldcode, $code, $function ) = @_;
  return $self->add_to_component( $code, $function )    if exists $self->{'components'}{$code};
  return $self->add_component_first( $code, $function ) unless exists $self->{'components'}{$oldcode};

  my $C = 0;
  foreach( @{$self->{'component_order'}} ) {
    if( $_ eq $oldcode ) {
      splice @{$self->{'component_order'}}, $C+1,0,$code;
      $self->{'components'}{$code} = [ $function ];
      return;
    }
    $C++;
  }
  $self->{'components'}{$code} = [ $function ];
}

sub remove_component {
  my( $self, $code ) = @_;
  my $C = 0;
  foreach( @{$self->{'component_order'}} ) {
    if( $_ eq $code ) {
      splice( @{$self->{'component_order'}}, $C, 1 );
      delete $self->{'components'}{$code};
      return;
    }
    $C++;
  }
}

sub add_form { 
  my( $self, $page, $key, $function_name ) = @_;
  (my $module_name = $function_name ) =~s/::\w+$//;
  if( $self->dynamic_use( $module_name ) ) {
    no strict 'refs';
    eval {
      my $T = &$function_name( $self, $self->{'object'} );
      $self->{'forms'}{$key} = $T if $T;
    };
    if( $@ ) {
      warn $@;
      my $error = $self->_format_error($@);
      $self->print( qq(<h4>Runtime error</h4>
      <p>Unable to execute <strong>$function_name</strong> to add form:</p>
      $error) );
    }
    if( $self->form($key) ) {
      my $DATA = $self->form($key)->render_js;
      $page->javascript->add_source( $DATA->{'scripts'} );
      $page->javascript->add_script( $DATA->{'head_vars'} );
      $page->add_body_attr( 'onload' => $DATA->{'body_code'} );
    }
  } else {
    $self->printf( qq(<h4>Compile error</h4>
    <p>Unable to compile <strong>$module_name</strong></p>
    %s), $self->_format_error( $self->dynamic_use_failure( $module_name ) ) );
  }
}

sub form {
  my( $self, $key ) = @_;
  return $self->{'forms'}{$key};
}

sub renderer :lvalue { $_[0]->{'_renderer'}; }

sub strip_HTML { my($self,$string) = @_; $string =~ s/<[^>]+>//g; return $string; }

sub render_AjaxMenu {
  my $self = shift;
  $self->renderer->print( qq(<$self->{'type'}>) ); 
}

sub render_Text {
  my $self = shift;
  if( 0 && exists( $self->{'caption'} ) ) {
    $self->renderer->printf( qq($self->{'caption'}\n\n) );
  }
  $self->content_Text();
}

sub render_XML {
  my $self = shift;
  $self->content();
}

sub render_Excel {
  my $self = shift;
  $self->content_Excel();
}


sub content_Excel() { 
  my $self = shift;
#  $self->renderer = new EnsEMBL::Web::Document::Renderer::Excel();
  $self->content();
#  $self->renderer->print( qq(<$self->{'caption'}>))
}


sub content_Text() { 
  my $self = shift;
  my $temp_renderer = $self->renderer;
  $self->renderer = new EnsEMBL::Web::Document::Renderer::String();
  $self->content();
  my $value = $self->strip_HTML( $self->renderer->value() ); 
  $self->renderer = $temp_renderer;
  $self->renderer->print( $value )
}

sub render {
  my( $self, $first ) = @_;

  if( exists $self->{'raw'} ) {
    $self->renderer->print( $self->{'raw'} );
  } else {
    my $status = $self->{'object'} ? $self->{'object'}->param($self->{'status'}) : undef;
    my $content = '';
    if( $status ne 'off' && $self->{'delayed_write'} ) {
      $content = $self->_content_delayed();
      if( !$content && exists( $self->{null_data} ) && ! defined( $self->{null_data} ) ) {
        return;
      }
    }
    my $HTML = q(
    <div class="panel">);
    my $button_text;
    my $counts = {};
    if( exists $self->{'previous'} || exists $self->{'next'} ) {
      $HTML .= q(
      <div class="nav-heading">
        <div class="left-button">);
      if( exists $self->{'previous'} && $self->{'previous'}{'url'} ) {
        $button_text = $self->{'previous'}{'concise'} || $self->{'previous'}{'caption'};
        $HTML .= sprintf q(<a href="%s">&laquo;&nbsp;%s</a>), $self->{'previous'}{'url'}, $button_text;
      } else {
        $HTML .= q(&nbsp;);
      }
      $HTML .= q(</div>
        <div class="right-button">);
      if( exists $self->{'next'} && $self->{'next'}{'url'} ) {
        $button_text = $self->{'next'}{'concise'} || $self->{'next'}{'caption'};
        $HTML .= sprintf q(<a href="%s">%s&nbsp;&raquo;</a>), $self->{'next'}{'url'}, $button_text;
      } else {
         $HTML .= q(&nbsp;);
      }
      $HTML .= q(</div>);
      if( exists $self->{'caption'} ) {
        $HTML .= sprintf q(
        <h2>%s</h2>), CGI::escapeHTML($self->{caption});
      }
      $HTML .= q(
      <p class="invisible">.</p></div>);
    } elsif( exists $self->{'caption'} ) {
      $HTML .= sprintf q(
      <h2>%s</h2>), CGI::escapeHTML($self->{caption});
    }
    $self->renderer->print($HTML);
    if( $status ne 'off' ) {
      if( $self->{'cacheable'} eq 'yes' ) { ### We can cache this panel - so switch the renderer!!!
        my $temp_renderer = $self->renderer;
        $self->renderer = new EnsEMBL::Web::Document::Renderer::GzCacheFile( $self->{'cache_type'}, $self->{'cache_filename'} );
        if( $self->{'_delayed_write_'} ) {
          $self->renderer->print($content)    unless( $self->renderer->{'exists'} eq 'yes' );
        } else {
          $self->_render_content()            unless( $self->renderer->{'exists'} eq 'yes' );
        }
        $self->renderer->close();
        $content = $self->renderer->content;
        $self->renderer = $temp_renderer;
        $self->renderer->print( $content );
      } else {
        if( $self->{'_delayed_write_'} ) {
          $self->renderer->print($content);
        } else {
          $self->_render_content();
        }
      }
    }
    $self->renderer->print( q(
    <p class="invisible">.</p></div>) );
  }
}

sub params {
  ### a
  my $self = shift;
  return $self->{params};
}

=pod
## getter/setter already defined, above!
sub caption {
  ### a
  my $self = shift;
  return $self->{caption};
}
=cut

sub status {
  ### a
  my $self = shift;
  return $self->{status};
}

sub code {
  ### a
  my $self = shift;
  return $self->{code};
}

sub _content {
  my $self = shift;
  my $output = $self->content();
  return unless $output;
  my $output = q(
      <div class="content">$output);
  my $cap = exists( $self->{'caption'} ) ? CGI::escapeHTML($self->parse($self->{'caption'})) : '';
  if( $self->{'link'} ) {
    $output .= sprintf( q(
        <div class="more"><a href="%s">more about %s ...</a></div>), $self->{'link'}, $cap );
  }
  $output .= q(
      </div>);
  return $output;
}

sub _render_content {
  my $self = shift;
  $self->renderer->print( q(
      <div class="content">));
  $self->content();
  my $cap = exists( $self->{'caption'} ) ? CGI::escapeHTML($self->parse($self->{'caption'})) : '';
  if( $self->{'link'} ) {
    $self->renderer->printf( q(
        <div class="more"><a href="%s">more about %s ...</a></div>), $self->{'link'}, $cap );
  }
  $self->renderer->print( q(
      </div>));
}

sub render_image {
  my $self = shift;
  
  my $HTML;
  if ($self->{'image'}{'object'}) { 
    $HTML .= $self->{'image'}{'object'}->render_img_tag();
    if( @{$self->{'image'}{'formats'}} ) {
        $HTML .= '<br />Render as: '. join( "; ", map { $self->{'image'}{'object'}->render_img_link($_) } @{$self->{'image'}{'formats'}} ).'.';
    }
    if( @{$self->{'image'}{'map'}} ) {
        $HTML .= $self->{'image'}{'object'}->render_img_map();
    }
  } else {
    $HTML = '<p>Sorry, no image object has been created.</p>';
  }
  return $HTML;
}

sub parse {
  my $self = shift;
  my $string = shift;
  $string =~ s/\[\[object->(\w+)\]\]/$self->{'object'}->$1/eg;
  return $string;
}

=head2 get_params

   Arg[1]      : hashref
                    the key 'style' can be "web" or "form"
                    the key 'omit' contains a hashref of key /value pairs
                        where the keys are the params to omit
   Example     :  my $param_form = $self->get_params({ style =>"form", 
                                   omit  => {snp =>1, c =>1, gene=>1 }} );
   Description : if style is 'web', it returns cgi parameters in form: 
                 param1=$value1&param2=$value2
                 if style is 'form', it returns cgi parameters in form:
                 <input type="hidden" name="$_" value="$value" />;
   Return type : string

=cut

sub get_params {
  my ( $self, $object, $info ) = @_;
  my $omit_ref  = $info->{omit};
  my %omit = $omit_ref ? %$omit_ref : ();
  my @params;

  if ($info->{style} eq "form") {
    foreach ( $object->param ) { 
      next unless $object->param($_);
      next if $omit{$_};
      push @params, { "name" => $_, "value" =>$object->param($_)};
    }
  }
  elsif ($info->{style} eq "web" ) {
    foreach ( $object->param ) { 
      next unless $object->param($_);
      next if $omit{$_};
      push @params, "$_=".$object->param($_);  
    }
  }
  return \@params;
}

sub raw_component {
    my ($self, $function_name, $loop) = @_;
    (my $module_name = $function_name ) =~s/::\w+$//;
    if( $self->dynamic_use( $module_name ) ) {
        no strict 'refs';
        my $result = 0;
        eval {
          $result = &$function_name( $self, $self->{'object'} );
        };
        if( $@ ) {
          my $error = $self->_format_error($@);
          # if( $@ =~ /^Undefined subroutine / ) {
          #  $error = "<p>This function is not defined</p>";
          # }
          $self->{'raw'} = qq( <h4>Runtime Error</h4>
      <p>Function <strong>$function_name</strong> fails to execute due to the following error:</p>\n$error);
        }
        if ($loop) {
            last if $result;
        }
      } else {
        $self->{'raw'} =  sprintf (qq(<h4>Compile error</h4>
      <p>Function <strong>$function_name</strong> not executed as unable to use
module <strong>$module_name</strong> due to syntax error.</p>
      %s), $self->_format_error( $self->dynamic_use_failure($module_name)
            )  );
      }
}

sub buffer :lvalue { $_[0]{_temp_}; }
sub reset_buffer   { $_[0]{_temp_} = ''; }

sub print          { 
  my $self = shift;
  if( $self->{'_delayed_write_'} ) {
    $self->{_temp_} .= join("",@_); 
  } else {
    $self->renderer->print( @_ );
  }
}

sub printf {
  my($self,$template,@pars) = @_;
  if( $self->{'_delayed_write_'} ) {
    $self->{_temp_} .= sprintf($template,@pars);
  } else {
    $self->renderer->printf( $template, @pars );
  }
}

sub _start { }
sub _end   { }
sub _error {
  my($self, $caption, $message ) = @_;
  $self->print( "<h4>$caption</h4>$message" );
}

sub _prof { $_[0]->{'timer'} && $_[0]->{'timer'}->push( $_[1], 3+$_[2] ); }

sub _is_ajax_request {
  return $_[0]->renderer->{'r'}->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest';
}
sub content {
  my( $self ) = @_;
  $self->reset_buffer;
  $self->_start;
  if( $self->{'content'} ) {
    $self->print( $self->{'content'} );
  }
  foreach my $component ($self->components) {
#warn "Starting component $component";
    foreach my $module_name ( @{$self->{'components'}{$component}} ) { 
      my $result;
      # (my $module_name = $function_name ) =~s/::\w+$//;
      if( $self->dynamic_use( $module_name ) ) {
        $self->{'object'} && $self->{'object'}->prefix( $self->prefix );
        no strict 'refs';
        my $comp_obj;
        eval {
          $comp_obj = $module_name->new( $self->{'object'} ); # &$function_name( $self, $self->{'object'} );
        };
        $result = $comp_obj->{_end_processing_};
        if( $@ ) {
         warn $@;
          $self->_error( qq(Runtime Error in component "<b>$component</b> [new]"),
            qq(
    <p>
      Function <strong>$module_name</strong> fails to
      execute due to the following error:
    </p>).$self->_format_error($@)
             );
          $self->_prof( "Component $module_name (runtime failure [new])" );
        } else {
          my $caption = $comp_obj->caption;
          if( $comp_obj->ajaxable() && !$self->_is_ajax_request ) {
	    my( $ensembl, $plugin, $component, $type, @T ) = split '::', $module_name;
	    my $URL = join '/',
	       '', $ENV{'ENSEMBL_SPECIES'},'Component',$ENV{'ENSEMBL_TYPE'},$plugin,@T;
            $URL .= "?$ENV{'QUERY_STRING'}"; # $self->renderer->{'r'}->parsed_uri->query;
	    if( $caption ) {
              $self->printf( qq(<div class="ajax" title="['%s','%s']"></div>), CGI::escapeHTML($caption),CGI::escapeHTML($URL) );
	    } else {
              $self->printf( qq(<div class="ajax" title="['%s']"></div>), CGI::escapeHTML($URL) );
	    }
	  } else {
            my $content;
            eval {
              $content = $comp_obj->content;
            };
            if( $@ ) {
              warn $@;
              $self->_error( qq(Runtime Error in component "<b>$component</b> [content]"),
                qq(
    <p>
      Function <strong>$module_name</strong> fails to
      execute due to the following error:
    </p>).$self->_format_error($@)
              );
              $self->_prof( "Component $module_name (runtime failure [content])" );
            } else {
              if( $content ) {
		if( ! $self->_is_ajax_request ) {
                  my $caption = $comp_obj->caption;
                  $self->printf( "<h2>%s</h2>", CGI::escapeHTML($caption) ) if $caption;
		}
                $self->print( $content );
              }
              $self->_prof( "Component $module_name succeeded" );
            }
	  }
        }
      } else {
        $self->_error( qq(Compile error in component "<b>$component</b>"),
          qq(
    <p>
      Component <strong>$module_name</strong> not used
      as unable to compile module.
    </p>). $self->_format_error( $self->dynamic_use_failure($module_name) )
        );
        $self->_prof( "Component $module_name (compile failure)" );
      }
      last if $result;
    }
#warn "Ending component $component";
  }
  $self->_end;
  return $self->buffer;
}

sub popup_help {
  my ($self, $object, $help_id, $option) = @_;

  my $species = $object->species;
  my $script  = $object->script;
  my $modular = $object->species_defs->ENSEMBL_MODULAR_HELP;

  $help_id = 0 unless $help_id;
  my $anchor = $$option{'anchor'} ? '#'.$$option{'anchor'} : '';
  my $image_align = $$option{'image'};
  my $popup_align = $$option{'popup'};

  my ($html, $class);
  my $offset_x = 0;
  my $offset_y = 0;
  if ($image_align eq 'right') {
    $class = 'float-right';
    $html .= qq(<img src="/img/blank.gif" alt="" width="20" class="float-left" />);
  }
  if ($popup_align eq 'center') {
    $offset_x = -200;
  }
  elsif ($popup_align eq 'right') {
    $offset_x = -400;
  }
  my $button = qq(<img src="/img/e-quest.gif" alt="(?)" title="Help" class="round-button $class");

  if ($modular) {
    $html .= qq#$button onclick="javascript:void(miniPopup(event, $help_id, '$species', '$script', $offset_x, $offset_y))" />#;
  }
  else {
    $html .= qq#<a href="javascript:void(window.open('/$species/helpview?se=1;kw=$script$anchor','helpview','width=700,height=550,resizable,scrollbars'))">$button /></a>#;
  }
  return $html;
}

sub ajax_is_available { 
  return 1;
}


1;

