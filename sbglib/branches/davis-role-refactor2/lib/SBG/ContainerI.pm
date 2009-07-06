#!/usr/bin/env perl

=head1 NAME

SBG::ContainerI - A set of L<SBG::DomainI>

=head1 SYNOPSIS

 package SBG::Domain::MyDomainImplementation;
 use Moose;
 with 'SBG::ContainerI'; 

 sub domains { return \@domains }

=head1 DESCRIPTION

If your class uses this role, it will need to define all the methods below.

=head1 SEE ALSO

L<SBG::DomainI>, L<Moose::Role>


=cut

################################################################################

package SBG::ContainerI;
use Moose::Role;


with qw/
SBG::Role::Storable
SBG::Role::Dumpable
SBG::Role::Clonable
SBG::Role::Transformable
/; 


################################################################################
=head2 domains

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has 'domains' => (
    is => 'rw',
    isa => 'ArrayRef[SBG::DomainI]',
    );


################################################################################
=head2 transform

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub transform {
    my ($self, $matrix) = @_;

    foreach (@{$self->domains}) {
        $_->transform($matrix);
    }
    return $self;
}


################################################################################
no Moose::Role;
1;

