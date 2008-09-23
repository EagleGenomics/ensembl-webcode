package EnsEMBL::Web::Component::Search::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Search);
use CGI qw(escapeHTML);

sub _init {
    my $self = shift;
    $self->cacheable( 0 );
    $self->ajaxable(  0 );
}

sub content {
    my $self = shift;
    my $html = '';
    my $exa_obj = $self->object->Obj;
    my $renderer = new ExaLead::Renderer::HTML( $exa_obj );
    return;
}

1;

