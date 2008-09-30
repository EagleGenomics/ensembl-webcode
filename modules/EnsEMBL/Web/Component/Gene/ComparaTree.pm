package EnsEMBL::Web::Component::Gene::ComparaTree;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

use EnsEMBL::Web::Constants;
use Bio::AlignIO;
use IO::Scalar;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self           = shift;
  my $object         = $self->object;

  #----------
  # Get the Member and ProteinTree objects 
  my $member = $object->get_compara_Member || die("No compara Member"); 
  my $tree   = $object->get_ProteinTree    || die("No ProteinTree");

  #----------
  # Draw the tree
  my $wuc          = $object->image_config_hash( 'genetreeview' );
  my $image_width  = $object->param( 'image_width' ) || 800;

  $wuc->set_parameters({
    'container_width'   => $image_width,
    'image_width',      => $image_width,
    'slice_number',     => '1|1',
  });

  #$wuc->tree->dump("GENE TREE CONF", '([[caption]])');
  my @highlights = ($object->stable_id, $member->genome_db->dbID);
  # Keep track of collapsed nodes

  my $collapsed_nodes = $object->param('collapse');

  unless( defined( $collapsed_nodes ) ){
    my $leaf_node = $tree->get_leaf_by_Member($member);
    if( $leaf_node ){
      $collapsed_nodes = join(',', 
                              map{$_->node_id=>1} 
                              @{$leaf_node->get_all_adjacent_subtrees});
    } else {
      warn sprintf( "[WARN] Member %s not in tree %s", 
                    $member->stable_id, $tree->node_id );
    }
  }

  push @highlights, $collapsed_nodes || undef;

  my $image  = $object->new_image
      ( $tree, $wuc, [@highlights] );
#  $image->cacheable   = 'yes';
  $image->image_type  = 'genetree';
  $image->image_name  = ($object->param('image_width')).'-'.$object->stable_id;
  $image->imagemap    = 'yes';

  $image->{'panel_number'} = 'tree';
  $image->set_button( 'drag', 'title' => 'Drag to select region' );

  return $image->render;
}

sub content_align {
  my $self           = shift;
  my $object         = $self->object;

  #----------
  # Get the ProteinTree object
  my $tree   = $object->get_ProteinTree;

  #----------
  # Return the text representation of the tree
  my $htmlt = qq(
<p>Multiple sequence alignment in FASTA format:</p>
<p>The species included in the tree can be configured using the
'configure tree' link in the left panel.<p>
<pre>%s</pre>);
  my $align_format = $object->param( 'text_format' ) || 'fasta'; # TODO: user configurable format
  my $formatted; # Variable to hold the formatted alignment string
  my $SH = IO::Scalar->new(\$formatted);
  #print $SH "FOO\n";
  my $aio = Bio::AlignIO->new( -format => $align_format, -fh => $SH );
  $aio->write_aln( $tree->get_SimpleAlign );

  return sprintf( $htmlt, $formatted );
}

sub content_text {
  my $self           = shift;
  my $object         = $self->object;

  #----------
  # Get the ProteinTree object
  my $tree   = $object->get_ProteinTree;

  #----------
  # Return the text representation of the tree
  my $htmlt = qq(
<p>The following is a representation of the tree in
<a href=http://en.wikipedia.org/wiki/Newick_format>newick</a> format</p>
<p>The species included in the tree can be configured using the
'configure tree' link in the left panel.<p>
<pre>%s</pre>);

  my %formats = EnsEMBL::Web::Constants::TREE_FORMATS();

  my $mode = $object->param('tree_format');
     $mode = 'newick' unless $formats{$mode};
  my $fn   = $formats{$mode}{'method'};

  my @params = map { $object->param( $_ ) } @{ $formats{$mode}{'parameters'} || [] };
  warn "MODE $mode FN $fn PARAMS @{ $formats{$mode}{'parameters'} || [] } PARAMS @params";
  my $string = $tree->$fn(@params);
  if( $formats{$mode}{'split'} ) {
    my $reg = '(['.quotemeta($formats{$mode}{'split'}).'])';
    $string =~ s/$reg/\1\n/g;
  }
  return sprintf( $htmlt, $string );
}

1;
