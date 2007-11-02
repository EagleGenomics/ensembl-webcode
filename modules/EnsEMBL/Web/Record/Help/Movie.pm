package EnsEMBL::Web::Record::Help::Movie;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Record::Trackable;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Record::Trackable);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key('help_record_id');
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new(
                        {table => 'help_record',
                        adaptor => 'websiteAdaptor'}
  ));
  $self->set_data_field_name('data');
  $self->add_field({ name => 'title', type => 'string' });
  $self->add_field({ name => 'filename', type => 'string' });
  $self->add_field({ name => 'width', type => 'int' });
  $self->add_field({ name => 'height', type => 'int' });
  $self->add_field({ name => 'filesize', type => 'float(3,1)' });
  $self->add_field({ name => 'length', type => 'string' });
  $self->add_field({ name => 'frame_count', type => 'int' });
  $self->add_field({ name => 'frame_rate', type => 'int' });
  $self->add_field({ name => 'list_position', type => 'int' });
  $self->add_queriable_field({ name => 'keyword', type => 'string' });
  $self->add_queriable_field({ name => 'status', type => "enum('draft','live','dead')" });
  $self->add_queriable_field({ name => 'helpful', type => 'int' });
  $self->add_queriable_field({ name => 'not_helpful', type => 'int' });
  $self->add_queriable_field({ name => 'type', type => 'string' });
  $self->type('movie');
  $self->populate_with_arguments($args);
}

}

1;
