#!/usr/bin/env perl

=head1 NAME

SBG::GeometricHash - 

=head1 SYNOPSIS

 use SBG::GeometricHash;
 my $h = new SBG::GeometricHash;
 $h->put(...,$model_object);
 %candidates = $h->at($points);


=head1 DESCRIPTION

3D geometric hash, for indexing things described by points in 3D, e.g. molecular
 structures.


=head1 SEE ALSO

1. Wolfson, H. & Rigoutsos, I. Geometric hashing: an overview. Computational Science & Engineering, IEEE 4, 10-21(1997).

=cut

################################################################################

package SBG::GeometricHash;
use Moose;

with 'SBG::Storable';
with 'SBG::Dumpable';


################################################################################
# Accessors


################################################################################
# Public

################################################################################
=head2 at

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub at {
    my ($self,$points) = @_;

} # at


################################################################################
=head2 put

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub put {
    my ($self,$points,$model) = @_;


} # put



################################################################################
# Private


################################################################################
__PACKAGE__->meta->make_immutable;
1;

