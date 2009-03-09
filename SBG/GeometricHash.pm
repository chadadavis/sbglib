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

The interface is based on L<Moose::Autobox::Hash>

       at
       put
       exists
       keys
       values
       kv
       slice
       meta
       print
       say

=cut

################################################################################

package SBG::GeometricHash;

use PDL::Lite;
use PDL::Core;
use PDL::Matrix;
use PDL::Ufunc;





sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    $self->{_gh} = {};
    return $self;
}



################################################################################
# Public

################################################################################
=head2 at

 Function: 
 Example : 
 Returns : 
 Args    : $model a L<PDL::Matrix> of dimension nx3

Returns a hash of votes for specific models.

=cut
sub at {
    my ($self,$model) = @_;

} # at


################################################################################
=head2 put

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub put {
    my ($self,$points,$modelid) = @_;

    foreach () {
        # Note not to quantize the addt'l rows/cols in a homogenous matrix
        $qpoint = _quantize($point);
        $self->{_gh}{$qpoint} ||= [];
        push @{ $self->{_gh}{$qpoint} }, $modelid;
    }


} # put



################################################################################
# Private

################################################################################
=head2 _quantize

 Function: 
 Example : 
 Returns : 
 Args    : 

For example, with binsize=5, converts:

 [ 6.1724927 -1.3568784]
 [-5.2222763  18.794775]

to:

 [ 5  0]
 [-5 15]

NB The bin that straddles 0 will be twice the size it should be.  This is
because floor() is not applicable to PDL data. Instead we use PDL::long() which
just converts to an integer.

=cut
# NB This is done inplace. I.e. $matrix is modified
sub _quantize {
    my ($matrix, $binsize) = @_;
    $binsize ||= 1;

    # inplace division
    $matrix /= $binsize;
    # convert to integer
    $matrix = long $matrix;
    # inplace multiplication
    $matrix *= $binsize;
    return $matrix;

}


################################################################################
=head2 _transform

 Function: 
 Example : 
 Returns : 
 Args    : 

Determine the basis transformation, which is the transformation that puts the
first point at the origin and the second point at X=1


=cut
sub _transform {
    my ($self,$points) = @_;

    my $t = mpdl [ [1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1] ];

    # First translate the first point to the origin

    # Then rotate about the origin to get the second point into the X axis

    # Two separate rotations required to get into X axis:

    # Scale down to unit length

    return $t;

} # _transform


################################################################################
1;

