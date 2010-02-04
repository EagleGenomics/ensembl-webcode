# $Id$

package EnsEMBL::Web::Document::Panel;

use strict;

use HTML::Entities qw(encode_entities);
use HTTP::Request;

use EnsEMBL::Web::Document::Renderer::Assembler;
use EnsEMBL::Web::Document::Renderer::String;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;
  my $self = {
    _renderer       => undef,
    forms           => {},
    components      => {},
    component_order => [],
    prefix          => 'p',
    disable_ajax    => 0,
    asychronous_components => [],
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

sub renderer :lvalue { $_[0]->{'_renderer'}; }

sub strip_HTML { my($self,$string) = @_; $string =~ s/<[^>]+>//g; return $string; }

sub render_Text {
  my $self = shift;
  $self->{'disable_ajax'} = 1;
  if( 0 && exists( $self->{'caption'} ) ) {
    $self->renderer->printf( qq($self->{'caption'}\n\n) );
  }
  $self->content_Text();
}

sub render_XML {
  my $self = shift;
  $self->content;
}

sub render_Excel {
  my $self = shift;
  $self->content_Excel;
}

sub content_Excel { 
  my $self = shift;
  $self->content;
}

sub content_Text { 
  my $self = shift;
  my $temp_renderer = $self->renderer;
  $self->renderer = new EnsEMBL::Web::Document::Renderer::String;
  $self->content;
  my $value = $self->strip_HTML( $self->renderer->content ); 
  my $value = $self->renderer->content;
  $self->renderer = $temp_renderer;
  $self->renderer->print( $value )
}

sub render {
  my ($self, $first) = @_;
  
  if (exists $self->{'raw'}) {
    $self->renderer->print($self->{'raw'});
  } else {
    my ($hub, $object, $status);
    if ($self->{'model'}) {
      $hub = $self->{'model'}->hub;
      $object = $self->{'model'}->object;
      $status = $hub ? $hub->param($self->{'status'}) : undef;
    }
    my $content = '';
    
    if ($status ne 'off' && $self->{'delayed_write'}) {
      $content = $self->_content_delayed;
      
      return if !$content && exists $self->{'null_data'} && !defined $self->{'null_data'};
    }
    
    my $panel_type = $self->renderer->{'_modal_dialog_'} ? 'ModalContent' : 'Content';
    
    my $html = qq{<div class="panel js_panel"><input type="hidden" class="panel_type" value="$panel_type" />};
    my $counts = {};
    
    if (!$self->{'omit_header'}) {
      if (exists $self->{'previous'} || exists $self->{'next'}) {
        my @buttons = (
          [ 'previous', 'left',  '&laquo;&nbsp;%s' ],
          [ 'next',     'right', '%s&nbsp;&raquo;' ]
        );
        
        $html .= '<div class="nav-heading">';
        
        foreach (@buttons) {
          my $label = $_->[0];
          my $button_text = exists $self->{$label} && !$self->{$label}->{'external'} ? $self->{$label}->{'concise'} || $self->{$label}->{'caption'} : undef;
          
          $html .= qq{
            <div class="$_->[1]-button print_hide">};
          
          if ($button_text) {
            my $url = $self->{$label}->{'url'} || $self->{'object'}->_url({ 'action' => $self->{$label}->{'code'}, 'function' => undef });
            
            $html .= sprintf qq{<a href="%s">$_->[2]</a>}, encode_entities($url), encode_entities($button_text);
          } else {
            $html .= '<span>&nbsp;</span>'; # Do not remove this span it breaks IE7 if only a &nbsp;
          }
          
          $html .= '</div>';
        }
        
        $html .= $self->_caption_with_helplink if exists $self->{'caption'};
        $html .= '
        <p class="invisible">.</p></div>';
      } elsif (exists $self->{'caption'}) {
        $html .= $self->_caption_with_helplink;
      }
    }
    
    $self->renderer->print($html) unless $self->{'json'};
    
    if ($status ne 'off') {
      if ($self->{'_delayed_write_'}) {
        $self->renderer->print($content);
      } else {
        my $temp_renderer = $self->renderer;
        
        $self->renderer = new EnsEMBL::Web::Document::Renderer::Assembler(
          r       => $temp_renderer->r,
          cache   => $temp_renderer->cache,
          session => $object ? $object->get_session : undef,
        );

        $self->_render_content;
        $self->renderer->close;

        $content = $self->renderer->content;
        
        return qq{$content<p class="invisible">.</p>} if $self->{'json'};
        
        $self->renderer = $temp_renderer;
        $self->renderer->print($content);
      }
    }
    
    $self->renderer->print('
    <p class="invisible">.</p></div>');
  }
}

sub _caption_with_helplink {
  my $self = shift;
  my $id = $self->{'help'};
  my $html = '<h2>';
  if ( $id ) {
    $html .= sprintf(' <a href="/Help/View?id=%s" class="popup help-header" title="Click for Help">', encode_entities($id));
  }
  $html .= $self->{'raw_caption'} ? $self->{'caption'} : encode_entities($self->{caption});
  if ( $id ) {
    $html .= ' <img src="/i/help-button.png" style="width:40px;height:20px;padding-left:4px;vertical-align:middle" alt="(e?)" class="print_hide" /></a>';
  }
  $html .= '</h2>';
  return $html; 
}

sub params {
  ### a
  my $self = shift;
  return $self->{params};
}

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
  my $cap = exists( $self->{'caption'} ) ? encode_entities($self->parse($self->{'caption'})) : '';
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
  my $cap = exists( $self->{'caption'} ) ? encode_entities($self->parse($self->{'caption'})) : '';
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

sub _error {
  my($self, $caption, $message ) = @_;
  $self->print( "<h4>$caption</h4>$message" );
}

sub timer_push { $_[0]->{'timer'} && $_[0]->{'timer'}->push( $_[1], 3+$_[2] ); }

sub _is_ajax_request {
  return  $_[0]->renderer->can('r') && 
          $_[0]->renderer->r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest';
}

sub content {
  my ($self) = @_;
  
  $self->reset_buffer;
  
  if ($self->{'content'}) {
    $self->print($self->{'content'});
  }
  
  my $model = $self->{'model'};
  return $self->buffer unless $model;
  my $hub = $model->hub;
  my $object = $self->{'object'};

  foreach my $component ($self->components) {
    if ($component eq 'das_features') {
      foreach my $function_name (@{$self->{'components'}{$component}}) {
        my $result;
        (my $module_name = $function_name) =~ s/::\w+$//;
        
        if ($self->dynamic_use($module_name)) {
          my $object = $model->object;
          $object && $object->prefix($self->prefix);
          
          no strict 'refs';
          
          eval {
            $result = &$function_name($self, $model);
          };
          
          if ($@) {
            my $error = sprintf('<pre>%s</pre>', $self->_format_error($@));
            
            $self->_error(
              qq{Runtime Error in component "<b>$component</b>"},
              qq{<p>Function <strong>$function_name</strong> fails to execute due to the following error:</p>$error}
            );
            
            warn "Component $function_name (runtime failure)";
          }
        } else {
          $self->_error(
            qq{Compile error in component "<b>$component</b>"},
            qq{
              <p>Function <strong>$function_name</strong> not executed as unable to use module <strong>$module_name</strong> due to syntax error.</p>
              <pre>@{[$self->_format_error($self->dynamic_use_failure($module_name))]}</pre>
            }
          );
          
          warn "Component $function_name (compile failure)";
        }
        
        last if $result;
      }
    } else {
      foreach my $temp (@{$self->{'components'}{$component}}) {
        my ($module_name, $function_name) = split /\//, $temp;
        my $result;
        
        if ($self->dynamic_use($module_name)) {
          my $object = $model->object;
          $object && $object->prefix($self->prefix);

          no strict 'refs';
          
          my $comp_obj;
          
          eval {
            $comp_obj = $module_name->new($model);
          };
          
          $result = $comp_obj->{'_end_processing_'};

          if ($@) {
            warn $@;
            
            $self->_error(
              qq{Runtime Error in component "<strong>$component</strong> [new]"},
              qq{<p>Function <strong>$module_name</strong> fails to execute due to the following error:</p>} . $self->_format_error($@),
            );
            
            $self->timer_push("Component $module_name (runtime failure [new])");
          } else {
            my $caption = $comp_obj->caption;
            
            if (!$self->{'disable_ajax'} && $comp_obj->ajaxable && !$self->_is_ajax_request) {
              my $url = $comp_obj->ajax_url($function_name);
              
              my $class = 'ajax' . ($comp_obj->has_image ? ' image_panel' : '');
              
              # Check if ajax enabled
              if ($ENSEMBL_WEB_REGISTRY->check_ajax) {
                $self->printf(qq{<div class="$class">%s</div>}, join '', map { $_ ? sprintf '<input type="hidden" class="ajax_load" value="%s" />', encode_entities($_) : () } $caption, $url);
              } elsif ($self->renderer->isa('EnsEMBL::Web::Document::Renderer::Assembler')) {
                my @wrapper = $comp_obj->has_image ? ('<div class="image_panel">', '</div>') : ();
                
                # if ajax disabled - we get all content by parallel requests to ourself
                $self->print($wrapper[0], HTTP::Request->new('GET', $object->species_defs->ENSEMBL_BASE_URL . $url), $wrapper[1]);
              }
            } else {
              my $content;
              
              eval {
                my $FN = $self->_is_ajax_request ? lc $object->function : $function_name;
                $FN = $FN ? "content_$FN" : $FN;
                $content = $comp_obj->can($FN) ? $comp_obj->$FN : $comp_obj->content;
              };
              
              if ($@) {
                warn $@;
                
                $self->_error(
                  qq{Runtime Error in component "<strong>$component</strong> [content]"},
                  qq{<p>Function <strong>$module_name</strong> fails to execute due to the following error:</p>} . $self->_format_error($@)
                );
                
                $self->timer_push("Component $module_name (runtime failure [content])");
              } else {
                if ($content) {
                  if ($self->_is_ajax_request) {
                    my $id = $object->function eq 'sub_slice' ? '' : $comp_obj->id;
                    
                    # Only add the wrapper if $content is html, and the update_panel parameter isn't present
                    $content = qq{<div class="js_panel" id="$id">$content</div>} if !$object->param('update_panel') && $content =~ /^\s*<.+>\s*$/s;
                  } else {
                    my $caption = $comp_obj->caption;
                    $self->printf("<h2>%s</h2>", encode_entities($caption)) if $caption;
                  }
                  
                  $self->print($content);
                }
                
                $self->timer_push("Component $module_name succeeded");
              }
            }
          }
        } else {
          $self->_error(
            qq{Compile error in component "<strong>$component</strong>"},
            qq{<p>Component <strong>$module_name</strong> not used as unable to compile module.</p>} . $self->_format_error($self->dynamic_use_failure($module_name))
          );
          
          $self->timer_push("Component $module_name (compile failure)");
        }
        
        last if $result;
      }
    }
  }
  
  return $self->buffer;
}

sub ajax_is_available { 
  return 1;
}


1;
