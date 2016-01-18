=head1 LICENSE


=cut

=head1 NAME

Bio::EnsEMBL::Punch 

=head1 SYNOPSIS

Code by Kim Brugger (kb8@brugger.dk)

=cut


package Bio::EnsEMBL::Punch;

use strict;

use vars qw(@ISA);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

# 
# 
# 
# Kim Brugger (06 Jul 2009), contact: kb8@sanger.ac.uk
sub new {
  my($class,@args) = @_;

  my $self = bless {}, $class;

  my ( $dbID, $adaptor, $comment, $punch_type, $punched, $name) =
      rearrange([qw(
		    DBID
		    ADAPTOR
		    COMMENT
		    PUNCH_TYPE
		    PUNCHED 
		    NAME
		    )],@args);
  
  die "Punch item needs to be associated with a punch-type (Bio::Ensembl::PunchType)\n"
      if ( ! $punch_type );

  $punched ||= 'n';

  $self->dbID( $dbID );
  $self->name( $name );
  $self->punch_type( $punch_type );
  $self->punched( $punched );

  $self->comment( $comment ) if ( $comment );

  return $self; 
}


# 
# 
# 
# Kim Brugger (06 Jul 2009), contact: kb8@sanger.ac.uk
sub adaptor {
  my ($self, $adaptor) = @_;
  
  $self->{adaptor} = $adaptor if ( $adaptor );
 
  return $self->{adaptor};
}


# 
# 
# 
# Kim Brugger (06 Jul 2009), contact: kb8@sanger.ac.uk
sub name {
  my ($self, $name) = @_;
  
  $self->{name} = $name if ( $name );
 
  return $self->{name};
}

# 
# 
# 
# Kim Brugger (06 Jul 2009), contact: kb8@sanger.ac.uk
sub comment {
  my ($self, $comment) = @_;
  
  $self->{ comment } = $comment if ( $comment );
 
  return $self->{comment};
}


# 
# 
# 
# Kim Brugger (06 Jul 2009), contact: kb8@sanger.ac.uk
sub punch_type {
  my ($self, $punch_type) = @_;
  
  if ( $punch_type ) {
    throw(" $punch_type is not of type 'Bio::EnsEMBL::PunchType'\n")
        if ( !$punch_type->isa('Bio::EnsEMBL::PunchType'));

    $self->{punch_type} = $punch_type ;
  }
 
  return $self->{punch_type};
}

# 
# 
# 
sub punched {
  my ($self, $punched) = @_;

  throw("punched should be either 'y' or 'n' not: '$punched'\n") 
      if ($punched && 
	  $punched ne 'y' && 
	  $punched ne 'n');
  
  $self->{punched} = $punched if ( $punched );
 
  return $self->{punched};
}


# 
# 
# 
sub dbID {
  my ($self, $dbID) = @_;
  
  $self->{dbID} = $dbID if ( $dbID );
 
  return $self->{dbID};
}


1;
