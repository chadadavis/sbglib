#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::U::Test qw/pdl_approx float_is/;
use Carp;
use Data::Dumper;
use File::Temp qw/tempfile/;
$File::Temp::KEEP_ALL = 1;


# NB could find better test cases in the trans database(s), e.g.:

# select h.e_value, e1.idcode, e1.description, e1.start_pdbseq, e1.end_pdbseq, e2.description, e2.start_pdbseq, e2.end_pdbseq from hit h, entity e1, entity e2 where e1.idcode=e2.idcode and h.id_entity1=e1.id and h.id_entity2=e2.id limit 50


################################################################################

use PDL;
use SBG::U::RMSD qw/
centroid radius_gyr radius_max superposition rmsd translation
/;

my $pdbid = '1tim';
my $descr1 = 'CHAIN A';
my $descr2 = 'CHAIN B';


use SBG::Domain::Atoms;
# Homogenous coords.
my $da = new SBG::Domain::Atoms(pdbid=>$pdbid,descriptor=>$descr1);
my $db = new SBG::Domain::Atoms(pdbid=>$pdbid,descriptor=>$descr2);


# Test centre of mass
my $cofm = centroid($da->coords);
pdl_approx($cofm->slice('0:2'),pdl(42.049,28.931,2.163),"Centre of mass",0.5);


# Test radius of gyration
my $rg = radius_gyr($da->coords, $cofm);
float_is($rg, 16.921, "Radius of gyration");


# Test radius maximum
my $rmax = radius_max($da->coords, $cofm);
float_is($rmax, 27.773, "Radius maximum");


# Test superposition
my $rot = superposition($da->coords, $db->coords);
my $rot_ans = pdl [
    [qw/    0.71836    0.09610   -0.68901         7.17512 /],
    [qw/    0.09744   -0.99455   -0.03712        88.33370 /],
    [qw/   -0.68882   -0.04048   -0.72380        30.24184 /],
    [qw/    0          0          0               1       /],
    ];
pdl_approx($rot, $rot_ans, "superposition", 0.5);


# Test rmsd
use SBG::Transform::Affine;
my $t = new SBG::Transform::Affine(matrix=>$rot);
$t->apply($da);
# rmsd() seems to have low precision, vs. expected vals from STAMP
float_is(rmsd($da->coords, $db->coords), 1.05, 'rmsd', 0.25);




