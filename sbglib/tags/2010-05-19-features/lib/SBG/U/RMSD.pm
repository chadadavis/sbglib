#!/usr/bin/env perl

=head1 NAME

SBG::U::RMSD - 

=head1 SYNOPSIS

use SBG::U::RMSD;


=head1 DESCRIPTION

=head1 REQUIRES

PDL

=head1 AUTHOR

Chad Davis <chad.davis@embl.de>

=head1 SEE ALSO

L<PDL>

Constants at 

 /g/russell2/russell/c/cofm/rbr_aadat.h

=head1 METHODS

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut



package SBG::U::RMSD;

require Exporter;
our @ISA = qw(Exporter);
# Automatically exported symbols
our @EXPORT    = qw//;
# Manually exported symbols
our @EXPORT_OK = qw/
rmsd centroid radius_gyr radius_max globularity superposition superpose translation
/;


use PDL::Lite;
use PDL::Core qw/pdl ones inplace sclr/;
use PDL::Reduce qw/reduce/;
use PDL::Ufunc qw/sumover average max all/;
use PDL::MatrixOps qw/svd det identity/;
use PDL::LinearAlgebra; # qw/crossprod/;


=head2 rmsd

 Function: 
 Example : 
 Returns : 
 Args    : Two L<PDL>s of same dimensions

NB if $pointsa is homogenous, then $pointsb must be homogenous as well

$pointsa and $pointsb can both be single points, e.g.
$pointsa = pdl 1,2,3;
$pointsb = pdl 4,5,6;

Or they may be matrices of points, e.g.
$pointsa = pdl [ [ 1,2,3 ], [ 4,5,6 ]];
$pointsb = pdl [ [ 0,4,6 ], [ 2,5,6 ]];

They may also be homogenous coordinates (append a 1 in 4th dimension)
$pointsa = pdl [ [ 1,2,3,1 ], [ 4,5,6,1 ]];
$pointsb = pdl [ [ 0,4,6,1 ], [ 2,5,6,1 ]];


=cut
sub rmsd {
    my ($pointsa, $pointsb) = @_;
    # Creates a new matrix copy to do the calculations
    my $diff = $pointsa->copy;
    # Inplace subtraction
    $diff = inplace($diff) - $pointsb if defined $pointsb;
    # Inplace exponentiation
    $diff = inplace($diff)**2;
    # Reduce each row (each point) via sumover, producing a vector of sums.
    # Then reduce the column vector via average, producing a scalar
    return sqrt(sclr(average(sumover($diff))));

} # rmsd



=head2 centroid

 Function: 
 Example : 
 Returns : A L<PDL> of dimension 3 or 4 (if homogenous)
 Args    : 

$weights, optional, will be used to weight each point

NB if your coordinates in $points are homogenous, i.e. each point is of
dimension 4, where the 4th value is always a 1, then the resulting
centre-of-mass will also be homogenous. I.e. it will be a vector of dimension 4,
with the 4th value being 1. This makes it easy to either use homogenous
coordinates everywhere or nowhere, as things remain consistent.

See L<Bio::Tools::SeqStats> for getting amino acid weights.

=cut
sub centroid {
    my ($points, $weights) = @_;
    # Don't modify original
    my $mat = $points->copy;

    if (defined $weights) {
        # Inline multiplication of weights, if given. If not given, $mat is
        # simply a pointer to, rather than a copy of $points
        $mat = inline($mat) * $weights->transpose();
    }

    # Matrix has two dimensions (0: rows/a single point, 1: columns/X or Y or Z)
    # Reduce along the second dimension (dim 1)
    # I.e. this averages each column, producing an avg X, an avg Y, an avg Z
    return $mat->reduce('avg',1)
}



=head2 radius_gyr

 Function: 
 Example : 
 Returns : 
 Args    : $points is a matrix of coordinate (possibly homogenous)

NB the radius of gyration is just the RMSD from all the coordinates to the one
centre-of-mass coordinate;

=cut 
sub radius_gyr { 
    my ($points, $centroid) = @_;
    return rmsd($points, $centroid);
}



=head2 radius_max

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub radius_max {
    my ($points, $centroid) = @_;
    my $diff = $points - $centroid;
    $diff = inplace($diff)**2;
    return sqrt max(sumover($diff));

} # radius_max



=head2 superposition

 Function: Determines transformation required to superpose sets of points
 Example : 
 Returns : 4x4 Affine matrix defining rotation+translation 
 Args    : Two sets of points, of the same length

Assumes that points are 4D homogenous coordinates

Simple explanation:

 http://en.wikipedia.org/wiki/Kabsch_algorithm


Original reference:

 Kabsch, Wolfgang, (1976) "A solution of the best rotation to relate two sets of
 vectors", Acta Crystallographica 32:922. doi:10.1107/S0567739476001873

=cut
sub superposition {
    my ($pointsa, $pointsb) = @_;
    my $copya = $pointsa->copy;

    # Identify centroid, to move points to common centre-of-mass before rotation
    my $centroida = centroid($pointsa);
    my $centroidb = centroid($pointsb);
    # Translate $pointsa to the origin
    $copya -= $centroida;

    # Covariance matrix. Does crossprod on the matrix after being placed at
    # commone centre.
    my $covariance = $copya->crossprod($pointsb - $centroidb);
    # Derive rotation matrix
    my $rot = _rot_svd($covariance);
    # Create an affine transformation matrix 4x4 from the 3x3
    my $affine = _affine($rot);

    # The following steps have to be done in this order to be compatible with
    # the order in which STAMP does it.

    # Translate copya back to where it came from
    $copya += $centroida;

    # Rotate $copya (about the origin)
    $copya = _apply($affine, $copya);

    # Determine the translation required to get the rotated copya onto pointsb
    my $transl = $centroidb - centroid($copya);

    # Make the affine matrix: combine rotation and translation
    $affine = _affine($affine, $transl);

    return $affine;

} # superposition



=head2 superpose

 Function: Determines the transformation matrix to superpose A onto B
 Example : my $transform = superpose($points_a, $points_b);
 Returns : Transformation matrix
 Args    : 

Unlike L<superposition> which just returns the transformation matrix, this also actually performs the transformation on A.


=cut
sub superpose {
    my ($pointsa,$pointsb) = @_;
    my $t = superposition($pointsa, $pointsb);
    $pointsa .= _apply($t, $pointsa);
    return $t;

} # superpose



=head2 globularity

 Function: 
 Example : 
 Returns : [0,1]
 Args    : 

Estimates the extent of globularity of a set of coordinates as the ratio of the
radius of gyration to the maximum radius, over all of the coordinates in (which
may be all atoms, just residues, just centres-of-mass, etc)

This provides some measure of how compact, non-linear, the components in a
complex are arranged. E.g. high for an exosome, low for actin fibers

=cut
sub globularity {
    my ($pdl) = @_;

    my $centroid = centroid($pdl);
    my $radgy = radius_gyr($pdl, $centroid);
    my $radmax = radius_max($pdl, $centroid);

    # Convert PDL to scalar
    return ($radgy / $radmax);

} # globularity



sub _apply {
    my ($mat, $vect) = @_;
    return ($mat x $vect->transpose)->transpose;
}


sub _affine {
    my ($rot, $transl) = @_;
    my $affine = identity 4;
    # Rotation matrix 3x3
    $affine->slice('0:2,0:2') .= $rot->slice('0:2,0:2')
        if defined $rot;
    # Translation vector (between centroids)
    $affine->slice('3,0:2') .= $transl->slice('0:2')->transpose 
        if defined $transl;
    return $affine;
}



# Determine rotation matrix based on singular value decomposition
# From: http://boscoh.com/protein/rmsd-root-mean-square-deviation
sub _rot_svd {
    my ($covariance) = @_;

    # Do a slice to make sure it's 3x3
    my ($V,$S,$Wt) = svd($covariance->slice('0:2,0:2'));
    # $S is the diagonal components of a diagonal matrix. We need the identity
    # matrix where the last cell (-1,-1) of the matrix should be sign-inverted
    # if the determinant of the covariance matrix is negative.  This compensates
    # for chirality by using right-handed coordinates.  As a shortcut, just
    # invert the signs in the last column, when necessary 

    if (det $covariance < 0) {
        # This doesn't seem to ever happen
        warn "determinant < 0";
        $V->slice('-1,') *= -1;
    }

    my $rot=$Wt x $V->transpose;
    return $rot;
}



=head2 translation

 Function: 
 Example : 
 Returns : Transformation matrix that translates $pointsa to $pointsb
 Args    : 

Based on the centres-of-mass of the two sets of points

=cut
sub translation {
    my ($pointsa, $pointsb) = @_;

    my $centroida = centroid($pointsa);
    my $centroidb = centroid($pointsb);
    my $diff = $centroidb - $centroida;
    my $mat = identity 4;
    $mat->slice('3,0:2') .= $diff->slice('0:2')->transpose;
    return $mat;

} # translation

###############################################################################

1;

__END__
