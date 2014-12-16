=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::DBSQL::ProductionAdaptor;

### A simple adaptor to fetch the changelog from the ensembl_production database
### For full CRUD functionality, see public-plugins/orm, which uses the Rose::DB::Object
### ORM framework

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;

sub new {
  my ($class, $hub) = @_;

    my $self = {
    'NAME' => $hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'},
    'HOST' => $hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'HOST'},
    'PORT' => $hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'PORT'},
    'USER' => $hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'USER'},
    'PASS' => $hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'PASS'},
  };
  bless $self, $class;
  return $self;
}

sub db {
  my $self = shift;
  return unless $self->{'NAME'};
  $self->{'dbh'} ||= DBI->connect(
      "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
      $self->{'USER'}, "$self->{'PASS'}"
  );
  return $self->{'dbh'};
}

sub fetch_changelog {
### Selects all changes for the given criteria and returns them as an arrayref of hashes
  my ($self, $criteria) = @_;
  my $changes = [];
  return [] unless $self->db;
  my ($sql, $sql2, @args, $filter);

  my $order = 'ORDER BY ';
  $order .= $criteria->{'species'}  ? ' s.species_id DESC, ' : '';

  if ($criteria->{'release'}) {
    @args = ($criteria->{'release'});
    $filter .= ' c.release_id = ? AND ';
  }
  else {
    $order .= ' c.release_id DESC, ';
  }

  if ($criteria->{'category'} || $criteria->{'team'}) {
    push @args, $criteria->{'category'} if $criteria->{'category'};
    push @args, $criteria->{'team'} if $criteria->{'team'};
    $filter .= ' (';
    $filter .= ' c.category = ? ' if $criteria->{'category'};
    $filter .= ' OR ' if ($criteria->{'category'} && $criteria->{'team'});
    $filter .= ' c.team = ? ' if $criteria->{'team'};
    $filter .= ') AND ';
  }

  if ($criteria->{'site_type'}) {
    push @args, $criteria->{'site_type'};
    $filter .= ' c.site_type = ? AND ';
  }

  $order .= 'c.priority DESC ';

  if ($criteria->{'limit'}) {
    $order .= 'LIMIT '.$criteria->{'limit'};
  }
 
  if ($criteria->{'species'}) {
    $sql = qq(
      SELECT
        c.changelog_id, c.title, c.content, c.team, c.category, s.species_id, c.release_id
      FROM
        changelog as c
      LEFT JOIN 
        changelog_species as cs 
        ON c.changelog_id = cs.changelog_id
      LEFT JOIN
        species as s
        ON s.species_id = cs.species_id
      WHERE 
        $filter
        c.title != ''
        AND c.content != ''
        AND c.status = 'handed_over'
        AND (s.url_name = ? OR s.url_name IS NULL)
      $order
    );
    push @args, $criteria->{'species'};
  }
  else {
    $sql = qq(
      SELECT
        c.changelog_id, c.title, c.content, c.team, c.category, c.release_id
      FROM
        changelog as c
      WHERE 
        $filter
        c.title != ''
        AND c.content != ''
        AND c.status = 'handed_over'
      $order
    );
  }

  my $sth = $self->db->prepare($sql);
  $sth->execute(@args);

  ## Prepare species SQL
  if ($criteria->{'species'}) {
    $sql2 = qq(
      SELECT
        species_id, db_name, web_name
      FROM
        species
      WHERE
        db_name = ?
    );
  }
  else {
    $sql2 = qq(
      SELECT
        s.species_id, s.db_name, s.web_name
      FROM
        species as s, changelog_species as cs
      WHERE
        s.species_id = cs.species_id
        AND cs.changelog_id = ?
    );
  }
  my $sth2 = $self->db->prepare($sql2);

  while (my @data = $sth->fetchrow_array()) {
    
    ## get the species info for this record
    my $species = [];
    my $arg2;
    if ($criteria->{'species'}) {
      ## Only get species info if this is in fact a species-specific record!
      if ($data[4]) {
        $arg2 = $criteria->{'species'};
      }
    }
    else {
      $arg2 = $data[0];
    }
    if ($arg2) {
      $sth2->execute($arg2);
      while (my @sp = $sth2->fetchrow_array()) {
        push @$species, {
          'id'          => $sp[0],
          'url_name'    => $sp[1],
          'web_name'    => $sp[2],
        };
      }
    }

    my $record = {
      'id'            => $data[0],
      'title'         => $data[1],
      'content'       => $data[2],
      'team'          => $data[3],
      'category'      => $data[4],
      'release'       => $data[5],
      'species'       => $species,
    };
    push @$changes, $record;
  }

  return $changes;
}

1;
