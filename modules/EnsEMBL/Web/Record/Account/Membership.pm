package EnsEMBL::Web::Record::Account::Membership;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Record::Trackable;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Record::Trackable);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key('group_member_id');
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => 'group_member' }));
  $self->add_queriable_field({ name => 'webgroup_id', type => "int" });
  $self->add_queriable_field({ name => 'user_id', type => "int" });
  $self->add_queriable_field({ name => 'level', type => "enum('member','administrator','superuser')" });
  $self->add_queriable_field({ name => 'member_status', type => "enum('active','inactive','pending','barred')" });
  $self->populate_with_arguments($args);
}

}

1;
