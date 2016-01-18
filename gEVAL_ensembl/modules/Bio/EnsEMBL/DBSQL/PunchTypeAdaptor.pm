
=head1 NAME

Bio::EnsEMBL::DBSQL::PunchtypeAdaptor - Adaptor for the Punchtype associated with the punchlist 

=head1 SYNOPSIS

  $pla = $registry->get_adaptor( 'Human', 'Core', 'Punchtype' );


  Code by Kim Brugger (kb8@sanger.ac.uk)

=head1 DESCRIPTION

=head1 METHODS

=cut


package Bio::EnsEMBL::DBSQL::PunchTypeAdaptor;
use vars qw(@ISA);
use strict;
use Data::Dumper;
use Bio::EnsEMBL::Punch;
use Bio::EnsEMBL::PunchType;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

use Bio::EnsEMBL::Registry;
BEGIN {
  Bio::EnsEMBL::Registry->add_adaptor('default', 'core', 'PunchType', 'Bio::EnsEMBL::DBSQL::PunchTypeAdaptor');
  Bio::EnsEMBL::Registry->add_adaptor('DEFAULT', 'pipeline', 'PunchType', 'Bio::EnsEMBL::DBSQL::PunchTypeAdaptor');
}


sub init {
  my ( @species ) = @_;
  
  foreach my $species ( @species ) {
  Bio::EnsEMBL::Registry->add_adaptor($species, 'core', 'PunchType', 'Bio::EnsEMBL::DBSQL::PunchTypeAdaptor');

  }
}

sub store {
  my ($self, $punch_type) = @_;

  throw("Store must be called with a PunchType ") if( ! $punch_type );

  my $dbc = $self->dbc();
  my $punch_type_adaptor = $self->db->get_PunchTypeAdaptor();

  my $sth = $self->prepare("INSERT IGNORE INTO punch_type (code, name, description, feature_type) VALUES (?,?,?,?) ");


  if( !ref $punch_type || !$punch_type->isa("Bio::EnsEMBL::PunchType") ) {
    throw("punch must be a Bio::EnsEMBL::PunchType,"
	  . " not a [".ref($punch_type)."].");
  }
  
  if(my $pt = $self->fetch_by_punch_type( $punch_type->code) ) {
#    warning("PunchType [".$pt->dbID."] is already stored" .
#	    " in this database, please use update.");
    $punch_type->dbID( $pt->dbID);
  }
  
  
  $sth->bind_param(1,$punch_type->code);
  $sth->bind_param(2,$punch_type->name);
  $sth->bind_param(3,$punch_type->description);
  $sth->bind_param(4,$punch_type->feature_type);
  
  $sth->execute();
  $punch_type->dbID($sth->{'mysql_insertid'});
  
  $sth->finish();

  return $punch_type;
}


sub update {
  my ($self, $punch_type) = @_;

  throw("Store must be called with a PunchType ") if( ! $punch_type );

  my $dbc = $self->dbc();
  my $punch_type_adaptor = $self->db->get_PunchTypeAdaptor();

  my $sth = $self->prepare("UPDATE punch_type set code=?, name=?, description=?, feature_type=? where punch_type_id=?");


  if( !ref $punch_type || !$punch_type->isa("Bio::EnsEMBL::PunchType") ) {
    throw("punch must be a Bio::EnsEMBL::PunchType,"
	  . " not a [".ref($punch_type)."].");
  }

  if(! $punch_type->dbID() ) {
    warning("PunchType [".$punch_type->dbID."] is not already stored" .
	    " in this database, using store instead.");
    $self->store( $punch_type );

    return undef;
  }
  
  
  $sth->bind_param(1,$punch_type->code);
  $sth->bind_param(2,$punch_type->name);
  $sth->bind_param(3,$punch_type->description);
  $sth->bind_param(4,$punch_type->feature_type);
  $sth->bind_param(5,$punch_type->dbID);
  
  $sth->execute();
  $punch_type->dbID($sth->{'mysql_insertid'});
  
  $sth->finish();

  return $punch_type;
}


 
# 
# 
# 
# Kim Brugger (07 Jul 2009)
sub fetch_by_dbID {
  my ($self, $dbID) = @_;

  return undef if ( ! $dbID );

  my $q = "SELECT * FROM punch_type WHERE punch_type_id='$dbID'";

  my $dbc = $self->dbc();
  my $sth = $dbc->prepare($q);
  $sth->execute();

  my $hash_ref = $sth->fetchrow_hashref;
  $sth->finish();

  my $punch_type = Bio::EnsEMBL::PunchType->new(
    -dbID            => $hash_ref->{punch_type_id},
    -adaptor         => $self,
    -code            => $hash_ref->{code},
    -name            => $hash_ref->{name}, 
    -description     => $hash_ref->{description},
    -feature_type    => $hash_ref->{feature_type},
      )  if ($hash_ref->{punch_type_id});
  
  
  return $punch_type;
}




 
# 
# 
# 
# Kim Brugger (07 Jul 2009)
sub fetch_by_punch_type {
  my ($self, $code) = @_;

  return undef if ( ! $code );

  my $q = "SELECT * FROM punch_type WHERE code='$code'";

  my $dbc = $self->dbc();
  my $sth = $dbc->prepare($q);
  $sth->execute();

  my $hash_ref = $sth->fetchrow_hashref;
  $sth->finish();

  my $punch_type = Bio::EnsEMBL::PunchType->new(
    -dbID            => $hash_ref->{punch_type_id},
    -code            => $hash_ref->{code},
    -name            => $hash_ref->{name}, 
    -description     => $hash_ref->{description},
    -feature_type    => $hash_ref->{feature_type},
      )  if ($hash_ref->{punch_type_id});
  
  
  return $punch_type;
}



# 
# 
# 
# Kim Brugger (07 Jul 2009)
sub fetch_all {
  my ($self) = @_;
  
  my $query = "SELECT * FROM punch_type";
  
  my $dbc = $self->dbc();
  my $sth = $dbc->prepare($query);
  $sth->execute();
  
  my @punch_types;
  
  while (my $hash_ref = $sth->fetchrow_hashref ) {
    
    
    my $punch_type = Bio::EnsEMBL::PunchType->new(
          -id              => $hash_ref->{punch_id},
  	  -adaptor         => $self,
          -code            => $hash_ref->{code},
          -name            => $hash_ref->{name}, 
          -description     => $hash_ref->{description},
	  -feature_type    => $hash_ref->{feature_type},
        );

    push @punch_types, $punch_type;
  }  
 
  $sth->finish();
  
  return \@punch_types;
}




1;


