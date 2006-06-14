package EnsEMBL::Web::Object::ArchiveStableId;


=head1 NAME


=head1 DESCRIPTION

This object stores ensembl archive ID objects and provides a thin wrapper around the  ensembl-core-api. 

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Fiona Cunningham - webmaster@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);


=head2 stable_id

 Arg1        : data object
 Description : fetches stable_id off the core API object 
 Return type : string

=cut

sub stable_id {
  my $self = shift;
  return $self->Obj->stable_id;
}

=head2 version

 Arg1        : data object
 Description : fetches version off the core API object 
 Return type : string

=cut

sub version {
  my $self = shift;
  return $self->Obj->version;
}

=head2 type

 Arg1        : data object
 Description : fetches type off the core API object 
 Return type : string

=cut

sub type {
  my $self = shift;
  return $self->Obj->type;
}

=head2 release

 Arg1        : data object
 Description : fetches release number off the core API object 
 Return type : string

=cut

sub release {
  my $self = shift;
  return $self->Obj->release;
}

=head2 assembly

 Arg1        : data object
 Description : fetches assembly off the core API object 
 Return type : string

=cut

sub assembly {
  my $self = shift;
  return $self->Obj->assembly;
}


=head2 db_name

 Arg1        : data object
 Description : fetches db_name off the core API object 
 Return type : string

=cut

sub db_name {
  my $self = shift;
  return $self->Obj->db_name;
}


=head2 get_current_object

 Arg1        : data object
 Arg2        : type e.g. 'Translation', 'Peptide', 'Gene' (string)
 Arg3        : stable id (string)
 Description : tries to fetch an object of type $type and with id $id and
               version $version. Used to see if ID exists in the current db.
 Return type : object with this id if it still exists (even if the version number is different

=cut

sub get_current_object {
  my ($self, $type, $id) = @_;
  $type = ucfirst(lc($type));
  $type = 'Translation' if $type eq 'Peptide';
  $id ||= $self->stable_id;
  my $call = "get_$type"."Adaptor";
  my $adaptor = $self->database('core')->$call;
  return $adaptor->fetch_by_stable_id($id) || undef;
}


=head2 transcript

 Arg1        : data object
 Description : fetches transcript archive IDs off the core API object 
 Return type : listref of Bio::EnsEMBL::ArchiveStableId

=cut

sub transcript {
  my $self = shift;
  return $self->Obj->get_all_transcript_archive_ids;
}


=head2 peptide

 Arg1        : data object
 Description : fetches peptide archive IDs off the core API object 
 Return type : listref of Bio::EnsEMBL::ArchiveStableId

=cut

sub peptide {
  my $self = shift;
  return $self->Obj->get_all_translation_archive_ids;
}


=head2 _adaptor

 Arg1        : data object
 Description : internal call to get archive stable ID adaptor
 Return type : ArchiveStableId adaptor

=cut

sub _adaptor {
  my $self = shift;
  return $self->database('core')->get_ArchiveStableIdAdaptor;
}

=head2 history

 Arg1        : data object
 Description : gets the archive id history tree based around this ID
 Return type : listref of Bio::EnsEMBL::ArchiveStableId
               As every ArchiveStableId knows about it's successors, this is
                a linked tree.

=cut

sub history {
  my $self = shift;
  my $adaptor = $self->_adaptor;
  return unless $adaptor;
  my $history = $adaptor->fetch_archive_id_history($self->Obj);
  return $history;
}


1;
