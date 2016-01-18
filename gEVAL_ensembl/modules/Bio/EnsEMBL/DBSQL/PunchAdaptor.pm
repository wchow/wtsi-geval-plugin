
=head1 NAME

Bio::EnsEMBL::DBSQL::PunchAdaptor - Adaptor for the Punch(es)

=head1 SYNOPSIS

  $pla = $registry->get_adaptor( 'Human', 'Core', 'Punch' );


  Code by Kim Brugger (kb8@sanger.ac.uk)

=head1 DESCRIPTION

=head1 METHODS

=cut


package Bio::EnsEMBL::DBSQL::PunchAdaptor;
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
  Bio::EnsEMBL::Registry->add_adaptor('default', 'core', 'Punch', 'Bio::EnsEMBL::DBSQL::PunchAdaptor');
  Bio::EnsEMBL::Registry->add_adaptor('DEFAULT', 'pipeline', 'Punch', 'Bio::EnsEMBL::DBSQL::PunchAdaptor');
}


sub init {
  my ( @species ) = @_;
  
  foreach my $species ( @species ) {
  Bio::EnsEMBL::Registry->add_adaptor($species, 'core', 'Punch', 'Bio::EnsEMBL::DBSQL::PunchAdaptor');

  }
}



sub store {
  my ($self, @punches) = @_;

  throw("Store must be called with punch(es)") if( scalar(@punches) == 0 );

  my $dbc = $self->dbc();
  my $punch_type_adaptor = $self->db->get_PunchTypeAdaptor();

  my $sth = $self->prepare("INSERT IGNORE INTO punch (punch_type_id, name, punched, comment) VALUES (?,?,?,?)");


 PUNCH: 
  foreach my $punch ( @punches ) {
    
    if( !ref $punch || !$punch->isa("Bio::EnsEMBL::Punch") ) {
      throw("punch must be a Bio::EnsEMBL::Punch, not a [".ref($punch)."].");
    }
    

    if($punch->dbID()) {
      warning("Punch [".$punch->dbID."] is already stored" .
              " in this database, please use update.");
      next PUNCH;
    }

    $punch_type_adaptor->store( $punch->punch_type ) if ( ! $punch->punch_type->dbID() );

    $sth->bind_param(1, $punch->punch_type->dbID() );
    $sth->bind_param(2, $punch->name );
    $sth->bind_param(3, $punch->punched || 'n' );

    $sth->bind_param(4, $punch->comment || '' );

    $sth->execute();
    $punch->dbID($sth->{'mysql_insertid'});
#    $punch->adaptor($self);


  }

  $sth->finish();
}


sub update {
  my ($self, @punches) = @_;


  throw("Update must be called with punch(es)") if( scalar(@punches) == 0 );

  my $dbc = $self->dbc();
  my $punch_type_adaptor = $self->db->get_PunchTypeAdaptor();

  my $sth = $self->prepare("UPDATE punch SET punch_type_id=?, name=?, punched=? comment=? WHERE punch_id=?");


 PUNCH: foreach my $punch ( @punches ) {
   if( !ref $punch || !$punch->isa("Bio::EnsEMBL::Punch") ) {
     throw("punch must be a Bio::EnsEMBL::Punch,"
            . " not a [".ref($punch)."].");
    }

    if(! $punch->dbID()) {
      warning("Punch [".$punch->dbID."] is not already stored" .
              " in this database, reverting to use store for this one.");
      $self->store( $punch );
      next PUNCH;
    }

   $punch_type_adaptor->store( $punch->punch_type ) if ( ! $punch->punch_type->dbID() );
   
   $sth->bind_param(1, $punch->punch_type->dbID() );
   $sth->bind_param(2, $punch->name );
   $sth->bind_param(3, $punch->punched );
   $sth->bind_param(4, $punch->comment || '' );
   $sth->bind_param(5, $punch->dbID );
   
   print STDERR "UPDATING THE ENTRY :: " . $punch->dbID . " ::\n";

   $sth->execute();
   
 }

  $sth->finish();
}




  
# 
# 
# 
# Kim Brugger (07 Jul 2009)
sub fetch_by_dbID {
  my ($self, $dbID) = @_;

  return undef if ( ! $dbID );

  my $q = "SELECT * FROM punch WHERE punch_id='$dbID'";

  my $dbc = $self->dbc();
  my $sth = $dbc->prepare($q);
  $sth->execute();

  my $hash_ref = $sth->fetchrow_hashref;
  $sth->finish();

  my $pta = $self->db->get_PunchTypeAdaptor();
  my $punch_type = $pta->fetch_by_dbID( $$hash_ref{punch_type_id} );

  my $punch = Bio::EnsEMBL::Punch->new(
				       -dbid            => $hash_ref->{punch_id},
				       -adaptor         => $self,
				       -punch_type      => $punch_type,
				       -punched         => $hash_ref->{punched},
				       -name            => $hash_ref->{name}, 
				       -comment         => $hash_ref->{comment}, 
				       )  
      if ($hash_ref->{punch_id});
  
  
  return $punch;
}



# 
# 
# 
# Kim Brugger (07 Jul 2009)
sub fetch_by_punch_type {
  my ($self, $punch_code) = @_;
  
  return undef if ( ! $punch_code );

  my $dbc = $self->dbc();
  my $pta = $self->db->get_PunchTypeAdaptor();
  
  my $punch_type = $pta->fetch_by_punch_type( $punch_code );
  return [] if (!$punch_type); # exit gracefully wc2.
  my $punch_type_id = $punch_type->dbID();

  my $query = "SELECT * FROM punch WHERE punch_type_id = '$punch_type_id'";
  
  my $sth = $dbc->prepare($query);
  $sth->execute();
  
  my @punches;
  
  while (my $hash_ref = $sth->fetchrow_hashref ) {
    
    
    my $punch = Bio::EnsEMBL::Punch->new(
					 -id              => $hash_ref->{punch_id},
					 -adaptor         => $self,
					 -punch_type      => $punch_type,
					 -punched         => $hash_ref->{punched},
					 -name          => $hash_ref->{name}, 
					 -comment         => $hash_ref->{comment}, 
					 );
    push @punches, $punch;
  }  
 
  $sth->finish();
  
  return \@punches;
}



# 
# 
# 
# Kim Brugger (07 Jul 2009)
sub fetch_all {
  my ($self) = @_;
  
  my $dbc = $self->dbc();
  my $pta = $self->db->get_PunchTypeAdaptor();

  my $query = "SELECT * FROM punch";
  
  my $sth = $dbc->prepare($query);
  $sth->execute();
  
  my @punches;
  
  while (my $hash_ref = $sth->fetchrow_hashref ) {
    

    my $punch_type = $pta->fetch_by_dbID( $$hash_ref{punch_type_id} );
    
    my $punch = Bio::EnsEMBL::Punch->new(
					 -id              => $hash_ref->{punch_id},
					 -adaptor         => $self,
					 -punch_type      => $punch_type,
					 -punched         => $hash_ref->{punched},
					 -name            => $hash_ref->{name}, 
					 -comment         => $hash_ref->{comment}, 
					 );
    push @punches, $punch;
  }  
 
  $sth->finish();
  
  return \@punches;
}

1;


