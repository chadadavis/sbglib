#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use Carp;
use Data::Dumper;
use File::Temp qw/tempfile/;
$File::Temp::KEEP_ALL = 1;
# Auto-Flush STDOUT
$| = 1;

################################################################################

use SBG::U::RMSD qw/centroid superposition rmsd translation/;
use PDL;

use SBG::Transform::Affine;
use SBG::Domain::Atoms;

use 5.010;

use SBG::DomainIO::pdb;
my $io = new SBG::DomainIO::pdb(tempfile=>1);

# Homogenous coords.
my $origpointsa = pdl [[qw/-8 -2 -2 1/],[qw/-.5 3 5 1/]];
my $origpointsb = pdl [[qw/64 66.6 62 1/],[qw/63 65 67 1/]];
my $pointsa = $origpointsa->slice('0:2,');
my $pointsb = $origpointsb->slice('0:2,');

my $da = new SBG::Domain::Atoms(pdbid=>'1tim',descriptor=>'CHAIN A');
my $db = new SBG::Domain::Atoms(pdbid=>'1tim',descriptor=>'CHAIN B');

say "Centroid A " . centroid($da->coords);
say "Centroid B " . centroid($db->coords);


# Rotation
my $rot = superposition($da->coords, $db->coords);
say "Rotation\n$rot";
$da->transform($rot);

# First need to test simple translation
# This works, if used alone, i.e. only translation
# Try applying translation after rotation ...
my $transl = translation($da->coords, $db->coords);
say "Translation\n$transl";
# $da->transform($transl);

# Undo rotation
$da->transform($rot->inv);

# Should just be able to add them up and apply all at once ...
my $combo = $rot;
$combo->slice('3,0:2') += $transl->slice('3,0:2');

say "Affine\n$combo";
$da->transform($combo);


$io->write($da,$db);
say $io->file;

__END__

# my $affine = superposition($pointsa, $pointsb);
# my $affine = superposition($origpointsa, $origpointsb);
my $affine = superposition($da->coords, $db->coords);

say "CHAIN A\n" . $da->coords->slice(',0:5') . join 'x', $da->coords->dims;
say "CHAIN B\n" . $db->coords->slice(',0:5') . join 'x', $db->coords->dims;

my $t = new SBG::Transform::Affine(matrix=>$affine);
say "Transform:\n" . $t->matrix;

$t->apply($da);
say "CHAIN A\n" . $da->coords->slice(',0:5') . join 'x', $da->coords->dims;

$io->write($da,$db);
say $io->file;

say "Done\n";










__END__

# Make centroids coincident
my $centroida = centroid($pointsa);
my $centroidb = centroid($pointsb);
$pointsa -= $centroida;
$pointsb -= $centroidb;


# Covariance matrix via dot product
my $covariance = $pointsa->transpose() x $pointsb;
# TODO should it be $pointsb->transpose() x $pointsa ? ( PDL is column-major)

my $rot = rot_svd($covariance);
# my $rot = rot_inv($covariance);

# Move $pointsa back to where they came from
$pointsa += $centroida;
$pointsb += $centroidb;


my $affine = identity 4;
# Rotation matrix 3x3
$affine->slice('0:2,0:2') .= $rot;
# Translation vector (between centroids)
my $diff = $centroidb - $centroida;
$affine->slice('3,0:2') .= $diff->transpose;

print $affine;

print "Done\n";

exit;


sub rot_svd {
    my ($covariance) = @_;

    my ($V,$S,$Wt) = svd($covariance);
    # $S is the diagonal components of a diagonal matrix. We need the identity
    # matrix where the last cell (-1,-1) of the matrix should be sign-inverted
    # if the determinant of the covariance matrix is negative.  This compensates
    # for chirality by using right-handed coordinates.  As a shortcut, just
    # invert the signs in the last column, when necessary 

    # TODO or should this be the last row?
    $V->slice('-1,') *= -1 if det $covariance < 0;

    # TODO Each of these is the transpose of the other. Which is correct?
    # my $rot=$V x $Wt->transpose;
    my $rot=$Wt x $V->transpose;
    return $rot;
}

# http://www.personal.leeds.ac.uk/~bgy1mm/Bioinformatics/rmsd.html
# Doesn't (seem to) work if covariance matrix (crossprod) is non singular
use PDL::LinearAlgebra qw/mchol/;
sub rot_inv {
    my ($A) = @_;
    my $crossprod = $A->crossprod($A);
    # Symmetric square root. Will only work if matrix is positive definite.
    my $sqrt = mchol($crossprod);
    my $rot = $sqrt x $A->inv;
    return $rot;

}
