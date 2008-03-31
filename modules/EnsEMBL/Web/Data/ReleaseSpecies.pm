package EnsEMBL::Web::Data::ReleaseSpecies;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('release_species');
__PACKAGE__->set_primary_key('release_species_id');

__PACKAGE__->add_queriable_fields(
  release_id    => 'int',
  species_id    => 'int',
  assembly_code => 'varchar(16)',
  assembly_name => 'varchar(16)',
  pre_code      => 'varchar(16)',
  pre_name      => 'varchar(16)',
);

__PACKAGE__->tie_a(species => 'EnsEMBL::Web::Data::Species');
__PACKAGE__->has_a(release => 'EnsEMBL::Web::Data::Release');

1;