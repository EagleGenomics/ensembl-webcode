package EnsEMBL::Web::Data::Component;

## Object representing help for an individual Ensembl component
## N.B. the keyword for this type of record links it to the component module

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::WebDBAdaptorNEW (__PACKAGE__->species_defs);

__PACKAGE__->table('help_record');
__PACKAGE__->set_primary_key('help_record_id');

__PACKAGE__->add_fields(content => 'text');

__PACKAGE__->_type('component');

__PACKAGE__->add_queriable_fields(
  keyword     => 'string',
  status      => "enum('draft','live','dead')",
  helpful     => 'int',
  not_helpful => 'int',
);

1;