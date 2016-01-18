#
# Ensembl module for Bio::EnsEMBL::PunchType
#

=head1 NAME

Bio::EnsEMBL::PunchType

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

Code by Kim Brugger (kb8@brugger.dk)

=head1 METHODS

=cut

use strict;
use warnings;

package Bio::EnsEMBL::PunchType;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);



sub new {
  my $caller = shift;

  # allow to be called as class or object method
  my $class = ref($caller) || $caller;

  my ($dbID, $code, $name, $desc, $feature_type) =
    rearrange([qw(DBID CODE NAME DESCRIPTION FEATURE_TYPE)], @_);

  return bless {'dbID'         => $dbID,
                'code'         => $code,
                'name'         => $name,
                'description'  => $desc,
		'feature_type' => $feature_type
                }, $class;
}




sub code {
  my ($self, $code) = @_;

  $self->{'code'} = $code if ( $code );
  return $self->{'code'};
}

sub dbID {
  my ($self, $dbID) = @_;

  $self->{'dbID'} = $dbID if ( $dbID );
  return $self->{'dbID'};
}



sub name {
  my ($self, $name) = @_;

  $self->{'name'} = $name if( $name );
  return $self->{'name'};
}


sub description {
  my ($self, $description) = @_;

  $self->{'description'} = $description if( $description );
  return $self->{'description'};
}

sub feature_type {
  my ($self, $feature_type) = @_;

  $self->{'feature_type'} = $feature_type if( $feature_type );
  return $self->{'feature_type'};
}


sub value {
  my ($self, $value) = @_;

  $self->{'value'} = $value if( $value );
  return $self->{'value'};
}


1;
