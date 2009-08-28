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

my $pdbid = '2br2';
# Explicitly use the same lenghts, so we can superpose without aligning
my $descr1 = 'D 10 _ to D 240 _';
my $descr2 = 'B 10 _ to B 240 _';


use SBG::Domain::Atoms;
# Homogenous coords.
my $da = new SBG::Domain::Atoms(pdbid=>$pdbid,descriptor=>$descr1);
my $db = new SBG::Domain::Atoms(pdbid=>$pdbid,descriptor=>$descr2);


# Test centre of mass
my $cofm = centroid($da->coords);
my $cofmexpect = pdl qw/-26.529  -51.676  -10.790/;
pdl_approx($cofm->slice('0:2'), $cofmexpect, "Centre of mass", 1.0);

# Test radius of gyration
my $rg = radius_gyr($da->coords, $cofm);
float_is($rg, 17.745 , "Radius of gyration", 1.5);


# Test radius maximum
my $rmax = radius_max($da->coords, $cofm);
float_is($rmax, 30.581, "Radius maximum", 1.5);


# Must have same number of points to do optimal superimposition
is($da->coords->dim(1), $db->coords->dim(1), "Equal length domains");


# Test superposition

# D onto B
my $rot_ans = pdl [
    [qw/    0.10928    0.99255    0.05393         8.93994  /],
    [qw/    0.04190   -0.05881    0.99739        -0.93300  /],
    [qw/    0.99313   -0.10673   -0.04801       -10.24173  /],
    [qw/    0          0          0               1        /],
    ];


my $rot = superposition($da->coords, $db->coords);
pdl_approx($rot, $rot_ans, "superposition", 1.0);


# Visual inspection
# use SBG::Run::rasmol qw/rasmol/;
# $da->transform($rot);
# rasmol($da, $db);


# Test rmsd
use SBG::Transform::Affine;
my $t = new SBG::Transform::Affine(matrix=>$rot);
$t->apply($da);
# rmsd() seems to have low precision, vs. expected vals from STAMP
float_is(rmsd($da->coords, $db->coords), 0.282, 'rmsd', 0.1);


