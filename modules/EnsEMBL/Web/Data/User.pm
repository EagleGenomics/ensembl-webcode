package EnsEMBL::Web::Data::User;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::UserDBConnection (__PACKAGE__->species_defs);
use EnsEMBL::Web::DASConfig;

__PACKAGE__->table('user');
__PACKAGE__->set_primary_key('user_id');

__PACKAGE__->add_queriable_fields(
  name         => 'tinytext',
  email        => 'tinytext',
  salt         => 'tinytext',
  password     => 'tinytext',
  organisation => 'tinytext',
  status       => 'tinytext',
);

## These are 'honeypot' fields designed to catch out spambots!
__PACKAGE__->add_fields(
  address         => 'text',
  surname         => 'text',
  subscription    => 'text', #not honeypot, but for sending subscription email - does not go to db, so kept here
);

__PACKAGE__->add_has_many(
  records        => 'EnsEMBL::Web::Data::Record',
  bookmarks      => 'EnsEMBL::Web::Data::Record::Bookmark',
  configurations => 'EnsEMBL::Web::Data::Record::Configuration',
  annotations    => 'EnsEMBL::Web::Data::Record::Annotation',
  dases          => 'EnsEMBL::Web::Data::Record::DAS',
  newsfilters    => 'EnsEMBL::Web::Data::Record::NewsFilter',
  sortables      => 'EnsEMBL::Web::Data::Record::Sortable',
  currentconfigs => 'EnsEMBL::Web::Data::Record::CurrentConfig',
  specieslists   => 'EnsEMBL::Web::Data::Record::SpeciesList',
  uploads        => 'EnsEMBL::Web::Data::Record::Upload',
  urls           => 'EnsEMBL::Web::Data::Record::URL',
  histories      => 'EnsEMBL::Web::Data::Record::History',
  bams           => 'EnsEMBL::Web::Data::Record::BAM',
);

__PACKAGE__->has_many(_groups => ['EnsEMBL::Web::Data::Membership' => 'webgroup']);

sub groups {
  my $self = shift;

  return grep { $_->status eq 'active' } $self->_groups(@_);
}

sub find_administratable_groups {
  my $self = shift;

  my @admin_groups = (
    $self->groups(level => 'administrator', member_status => 'active'),
    $self->groups(level => 'superuser', member_status => 'active'),
  );

  return @admin_groups;
}

sub find_nonadmin_groups {
  my $self = shift;
  return $self->groups(level => 'member', member_status => 'active');
}

sub is_administrator_of {
  my ($self, $group) = @_; 
  return grep {$group eq $_} $self->find_administratable_groups;
}

sub is_member_of {
  my ($self, $group) = @_;
  return grep {$group eq $_} $self->groups;
}

sub update_invitations {
  ## Loops through current invitations and turns any accepted ones into memberships
  my $self = shift;

  ## Safe mode require, just in case we dont have it here yet
  $self->_require_class('EnsEMBL::Web::Data::Record::Invite::Group');
  $self->_require_class('EnsEMBL::Web::Data::Group');

  my @invitations = EnsEMBL::Web::Data::Record::Invite::Group->search_like(data => '%'.$self->email.'%');
  foreach my $invite (@invitations) {
    next unless $invite->status eq 'accepted';
    unless ($self->is_member_of($invite->webgroup_id)) {
      my $member_id = EnsEMBL::Web::Data::Group->new($invite->webgroup_id)->add_user($self);
      #warn "Added member ".$invite->email." ($member_id) to group ".$invite->webgroup_id;
      ## Remove any completed invitations
      $invite->destroy if $member_id;
    }
  }
}

sub get_all_das {
  my $self    = shift;
  my $species = shift || $ENV{'ENSEMBL_SPECIES'};
  
  if ( $species eq 'common' ) {
    $species = '';
  }
  
  my %by_name = ();
  my %by_url  = ();
  for my $data ( $self->dases ) {
    # Create new DAS source from value in database...
    my $das = EnsEMBL::Web::DASConfig->new_from_hashref( $data );
    $das->matches_species( $species ) || next;
    $das->category( 'user' );
    $by_name{ $das->logic_name } = $das;
    $by_url { $das->full_url   } = $das;
  }
  
  return wantarray ? ( \%by_name, \%by_url ) : \%by_name;
}


sub add_das {
  my ( $self, $das ) = @_;
  if ($das && ref $das && ref $das eq 'EnsEMBL::Web::DASConfig') { ## Sanity check
    $das->category( 'user ');
    $das->mark_altered();
    return $self->add_to_dases($das);
  }
  return;
}


###################################################################################################
##
## Cache related stuff
##
###################################################################################################

sub invalidate_cache {
  my $self  = shift;
  my $cache = shift;
  
  $self->SUPER::invalidate_cache($cache, 'user['.$self->id.']');
}

sub propagate_cache_tags {
  my $self = shift;
  $self->SUPER::propagate_cache_tags('user['.$self->id.']')
    if ref $self;
}

1;
