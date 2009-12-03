# $Id$

package EnsEMBL::Web::Document::HTML::Content;

use strict;

use EnsEMBL::Web::Root;

use base qw(EnsEMBL::Web::Document::HTML);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new('panels' => [], 'first' => 1, 'form' => '');
  my $timer = shift;
  $self->{'timer'} = $timer;  
  return $self;
}

sub first         :lvalue { $_[0]->{'first'};       }
sub form          :lvalue { $_[0]->{'form'};        }
sub filter_module :lvalue { $_[0]{'filter_module'}; }
sub filter_code   :lvalue { $_[0]{'filter_code'};   }

sub timer_push      { $_[0]->{'timer'} && $_[0]->{'timer'}->push($_[1], 2); }
sub add_panel_first { $_[1]->renderer = $_[0]->renderer; unshift @{$_[0]{'panels'}}, $_[1]; }
sub add_panel_last  { $_[1]->renderer = $_[0]->renderer;    push @{$_[0]{'panels'}}, $_[1]; }
sub add_panel       { $_[1]->renderer = $_[0]->renderer;    push @{$_[0]{'panels'}}, $_[1]; }

sub add_panel_after {
  my ($self, $panel, $code) = @_;
  
  $panel->renderer = $self->renderer;
  
  my $counter = 0;
  
  foreach (@{$self->{'panels'}}) {
    $counter++;
    last if $_->{'code'} eq $code;
  }
  
  splice @{$self->{'panels'}}, $counter, 0, $panel;
}

sub add_panel_before {
  my ($self, $panel, $code) = @_;
  
  $panel->renderer = $self->renderer;
  
  my $counter = 0;
  
  foreach (@{$self->{'panels'}}) {
    last if $_->{'code'} eq $code;
    $counter++;
  }
  
  splice @{$self->{'panels'}}, $counter, 0, $panel;
}

sub replace_panel {
  my ($self, $panel, $code) = @_;
  
  $panel->renderer = $self->renderer;
  
  my $counter = 0;
  
  foreach (@{$self->{'panels'}}) {
    last if $_->{'code'} eq $code;
    $counter++;
  }
  
  splice @{$self->{'panels'}}, $counter, 1, $panel;
}

sub remove_panel {
  my ($self, $code) = @_;
  
  my $counter = 0;
  
  foreach (@{$self->{'panels'}}) {
    if ($_->{'code'} eq $code) {
      splice @{$self->{'panels'}}, $counter, 1;
      return;
    }
    
    $counter++;
  }
}

# Lists the codes for each panel in this page content
sub panels {
  my $self = shift;
  return map $_->{'code'}, @{$self->{'panels'} || []};
}

sub panel {
  my ($self, $code) = @_;
  
  foreach (@{$self->{'panels'}}) {
    return $_ if $code eq $_->{'code'};
  }
  
  return undef;
}

sub render {
  my $self = shift;
  
  $self->print("\n$self->{'form'}") if $self->{'form'};
  
  # Include any access warning at top of page
  if ($self->filter_module) {
    my $class = 'EnsEMBL::Web::Filter::' . $self->filter_module;
    my $html;
    
    if ($class && EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
      my $filter = $class->new;
      
      $html .= '<div class="panel print_hide">';
      $html .= sprintf '<div style="width:80%" class="error"><h3>Error</h3><div class="error-pad">%s</div></div>', $filter->error_message($self->filter_code);
      $html .= '</div>';
      
      #$self->print($html);
    }
  }
  
  foreach my $panel (@{$self->{'panels'}}) { 
    $panel->{'timer'} = $self->{'timer'};
    $panel->render($self->{'first'});
    $self->{'first'} = 0;
    $self->timer_push("Rendered panel $panel->{'code'}");
  }
  
  $self->print("\n</form>") if $self->{'form'};
}

sub get_json {
  my $self = shift;
  
  my $panel_type = 'ModalContent';
  my $single = (scalar @{$self->{'panels'}} == 1);
  my $wrapper = 'modal_wrapper' . ($single ? ' panel' : '');
  
  my $filter;
  my $content;
  
  # Include any access warning at top of page
  if ($self->filter_module) {
    my $class = 'EnsEMBL::Web::Filter::' . $self->filter_module;
    
    if ($class && EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
      $filter = $class->new;
      
      $content .= sprintf '<div style="width:80%" class="error print_hide"><h3>Error</h3><div class="error-pad">%s</div></div>', $filter->error_message($self->filter_code);
    }
  }
  
  foreach my $panel (@{$self->{'panels'}}) { 
    $panel->{'json'} = 1;
    
    $content .= $panel->render;
    
    $panel_type = 'Configurator' if ref($panel) =~ /Configurator/;
  }
  
  $content = "$self->{'form'}$content</form>" if $self->{'form'};
  
  $content =~ s/\n/\\n/g;
  $content =~ s/\r//g;
  $content =~ s/'/&#39;/g;
  
  return qq{'content':'$content','wrapper':'<div class="$wrapper"></div>','panelType':'$panel_type'};
}

## DO NOT REMOVE: Needed by BioMart to wrap mart pages 
sub _start { $_[0]->print(); return 1; }
sub _end {   $_[0]->print(); }

1;

