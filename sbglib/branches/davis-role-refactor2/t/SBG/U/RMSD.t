#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::U::Test qw/pdl_approx float_is/;
use Carp;
use Data::Dumper;
use File::Temp qw/tempfile/;
$File::Temp::KEEP_ALL = 1;

################################################################################

use PDL;
use SBG::U::RMSD qw/centroid superposition rmsd translation/;

use SBG::Domain::Atoms;
# Homogenous coords.
my $da = new SBG::Domain::Atoms(pdbid=>'1tim',descriptor=>'CHAIN A');
my $db = new SBG::Domain::Atoms(pdbid=>'1tim',descriptor=>'CHAIN B');

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
TODO: {
    local $TODO;
    $TODO = "rmsd() seems to have low precision";
    float_is(rmsd($da->coords, $db->coords), 1.05, 2);
}



