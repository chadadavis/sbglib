#!/usr/bin/env perl

=head1 NAME

SBG::RepresentationI - Simplified structure representation (a L<Moose::Role>)

=head1 SYNOPSIS

 package MyClass;
 use Moose;
 with 'SBG::RepresentationI'; 


=head1 DESCRIPTION

If your class uses this role, it will need to define all the methods below.

=head1 SEE ALSO

L<SBG::Sphere> , L<SBG::Domain>, L<Moose::Role>

=cut

################################################################################

package SBG::RepresentationI;
use Moose::Role;



################################################################################
=head2 dist

 Function: Positive distance between objects.
 Example : my $linear_distance = $dom1->dist($dom2);
 Returns : Positive scalar
 Args    : L<SBG::RepresentationI>

positive (Euclidean) distance between this object and some other

=cut
requires 'dist';


################################################################################
=head2 hash

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
requires 'hash';


################################################################################
=head2 sqdist

 Function: Squared linar distance between objects
 Example : 
 Returns : 
 Args    : 


=cut
requires 'sqdist';


################################################################################
=head2 rmsd

 Function:
 Example :
 Returns : 
 Args    :

RMSD between the points of B<$self>'s representation and B<$other>
=cut
requires 'rmsd';


################################################################################
=head2 evaluate

 Function: To what extent is $self a good approximation for $obj
 Example :
 Returns : 
 Args    :


=cut
requires 'evaluate';



################################################################################
=head2 volume

 Function:
 Example :
 Returns : 
 Args    :


=cut
requires 'volume';


################################################################################
=head2 transform

 Function: Transform this object by the given transformation
 Example :
 Returns : 
 Args    : L<SBG::Transform>

=cut
requires 'transform';


################################################################################
=head2 overlap

 Function: Similar to L<rmsd>, but considers the radius of gyration 'rg'
 Example : my $linear_overlap = $dom1->overlap($dom2);
 Returns : Positive: linear overlap along line connecting centres of spheres
           Negative: linear distance between surfaces of spheres
 Args    : Another L<SBG::Domain>

=cut
requires 'overlap';


################################################################################
=head2 overlaps

 Function: Whether two spheres overlap, beyond an allowed threshold (Angstrom)
 Example : if($dom1->overlaps($dom2,20.5)) { print "Clash!\n"; }
 Returns : true if L<overlap> exceeds given thresh
 Args    : L<SBG::Domain> 
           thresh - default 0

=cut
requires 'overlaps';


################################################################################
1;

