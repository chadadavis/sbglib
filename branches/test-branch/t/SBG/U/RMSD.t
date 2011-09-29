#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Debug;

use Test::More;
use Carp;
use File::Temp qw/tempfile/;
use Test::Approx;
use PDL::Lite;

use SBG::U::Test qw/pdl_approx/;
use SBG::U::RMSD qw/
    centroid radius_gyr radius_max superposition rmsd translation identity
    /;

# NB could find better test cases in the trans database(s), e.g.:

# select h.e_value, e1.idcode, e1.description, e1.start_pdbseq, e1.end_pdbseq, e2.description, e2.start_pdbseq, e2.end_pdbseq from hit h, entity e1, entity e2 where e1.idcode=e2.idcode and h.id_entity1=e1.id and h.id_entity2=e2.id limit 50

my $id = identity(4);
pdl_approx($id,
    pdl([ 1, 0, 0, 0 ], [ 0, 1, 0, 0 ], [ 0, 0, 1, 0 ], [ 0, 0, 0, 1 ]),
    'identity');

my $numericError = 0.00001;

# Test warning for known bad input
# Simple triangle
my $points0a = pdl [ [ 0, 0, 0, 1 ], [ 10, 0, 0, 1 ], [ 5, 20, 0, 1 ] ];

# Same points shifted by 10 in z-direction
my $points0b = pdl [ [ 0, 0, 10, 1 ], [ 10, 0, 10, 1 ], [ 5, 20, 10, 1 ] ];

# Transformation will fail with a warning and return nothing
{

    # Make warnings fatal, so that eval can catch them and we can test them:
    local $SIG{__WARN__} = sub { die $_[0] };
    eval { SBG::U::RMSD::superposition($points0a, $points0b) };
    like($@, qr/cannot superpose/i, "Catch no SVD error");
}

# More complex points
my $pointsA =
    pdl [ [ 8, 4, 2, 1 ], [ 6, 2, 6, 1 ], [ 6, 4, 2, 1 ], [ 6, 6, 7, 1 ] ];

# Same points shifted by 10 in z-direction
my $pointsB =
    pdl [ [ 8, 4, 12, 1 ], [ 6, 2, 16, 1 ], [ 6, 4, 12, 1 ],
    [ 6, 6, 17, 1 ] ];

# Test1 (expected result for transformation matrix)
my $A1 =
    pdl [ [ 1, 0, 0, 0 ], [ 0, 1, 0, 0 ], [ 0, 0, 1, 10 ], [ 0, 0, 0, 1 ] ];
pdl_approx(
    $pointsB,
    ($A1 x $pointsA->transpose)->transpose,
    "expected transformation matrix",
    $numericError
);

#Test (superposition)
my $A2 = SBG::U::RMSD::superposition($pointsA, $pointsB);
my $diff2 = $pointsB - ($A2 x $pointsA->transpose)->transpose;
pdl_approx($A2, $A1, "superposition", $numericError);

#Test (superpose)
my $A3 = SBG::U::RMSD::superpose($pointsA, $pointsB, 10);
pdl_approx($pointsB, $pointsA, "superpose", $numericError);

my $pdbid = '2br2';

# Explicitly use the same lenghts, so we can superpose without aligning
my $descr1 = 'D 10 _ to D 240 _';
my $descr2 = 'B 10 _ to B 240 _';

use SBG::Domain::Atoms;

# Homogenous coords.
my $da = new SBG::Domain::Atoms(pdbid => $pdbid, descriptor => $descr1);
my $db = new SBG::Domain::Atoms(pdbid => $pdbid, descriptor => $descr2);

# Test centre of mass
my $cofm       = centroid($da->coords);
my $cofmexpect = pdl qw/-26.529  -51.676  -10.790/;
pdl_approx($cofm->slice('0:2'), $cofmexpect, "Centre of mass", 1.0);

# Test radius of gyration
my $rg = radius_gyr($da->coords, $cofm);
is_approx($rg, 17.745, "Radius of gyration", 1.5);

# Test radius maximum
my $rmax = radius_max($da->coords, $cofm);
is_approx($rmax, 30.581, "Radius maximum", 1.5);

# Must have same number of points to do optimal superimposition
is($da->coords->dim(1), $db->coords->dim(1), "Equal length domains");

# Test superposition

# D onto B
my $rot_ans = pdl [
    [ +0.10928, +0.99255, +0.05393, +8.939940 ],
    [ +0.04190, -0.05881, +0.99739, -0.933000 ],
    [ +0.99313, -0.10673, -0.04801, -10.24173 ],
    [ 0,        0,        0,        1 ],
];

my $rot = superposition($da->coords, $db->coords);
pdl_approx($rot, $rot_ans, "superposition", 1.0);

# Visual inspection
# use SBG::Run::rasmol qw/rasmol/;
# $da->transform($rot);
# rasmol($da, $db);

# Test rmsd
use SBG::Transform::Affine;
my $t = new SBG::Transform::Affine(matrix => $rot);
$t->apply($da);

# rmsd() seems to have low precision, vs. expected vals from STAMP
is_approx(rmsd($da->coords, $db->coords), 0.282, 'rmsd', 0.1);

$TODO = "Test globularity()";
ok(0);

done_testing;
