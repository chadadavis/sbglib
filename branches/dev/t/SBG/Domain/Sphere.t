#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Debug;

use Test::More;
use Carp;
use FindBin;
use File::Temp qw/tempfile/;
my $dir = $FindBin::RealBin;

use PDL::Lite;

use Test::Approx;

use SBG::Domain::Sphere;

# Sanity check
my $s = new SBG::Domain::Sphere(center => pdl(1, 2, 3),, radius => 2);
is($s->radius, 2, 'Default radius');
$s->radius(3.1);
is($s->radius, 3.1, 'Set radius');
ok($s->does('SBG::DomainI'), 'Implements DomainI');

# rmsd()
my $s1 = new SBG::Domain::Sphere(center => pdl qw(-6.61  -32.62  -53.18));
my $s2 = new SBG::Domain::Sphere(center => pdl qw/80.86   12.45  122.08/);
my $diff       = $s1->rmsd($s2);
my $expectdist = 200.99;
my $tolerance  = '1%';
is_approx($diff, $expectdist, "rmsd() between domains: $diff", $tolerance);

# overlap_lin()

# Case 1 negative (no overlap)
$s1->radius(34.1);
$s2->radius(56.66);
my $expectoverlap = -1 * $expectdist + ($s1->radius + $s2->radius);
my $overlap_lin = $s1->overlap_lin($s2);
is_approx($overlap_lin, $expectoverlap,
    "overlap_lin : no overlap : $overlap_lin", $tolerance);

# Case 2 some overlap
$s1->radius(96.1);
$s2->radius(123.66);
$expectoverlap = -1 * $expectdist + ($s1->radius + $s2->radius);
$overlap_lin = $s1->overlap_lin($s2);
is_approx($overlap_lin, $expectoverlap,
    "overlap_lin : some overlap : $overlap_lin", $tolerance);

# As a fraction
my $overlap_frac = $s1->overlap_lin_frac($s2);
my $overlap_max  = $s1->overlap_lin_max($s2);
$expectoverlap = $overlap_lin / $overlap_max;
is_approx($overlap_frac, $expectoverlap,
    "overlap_lin_frac: $expectoverlap ($overlap_lin / $overlap_max)",
    $tolerance);

# Case 3 one completely inside the other (max overlap)
$s1->radius(296.1);
$s2->radius(26.66);

# What's the maximum linear overlap
$expectoverlap = $s2->overlap_lin_max($s1);
$overlap_lin   = $s1->overlap_lin($s2);
is_approx($overlap_lin, $expectoverlap,
    "overlap_lin : max overlap : $overlap_lin", $tolerance);

# Test cloning
# NB Not sufficient to use Scalar::Util::refaddr, as the PDL is deep in memory
# Requies using PDL-specific operators
my $clone = $s->clone;
isnt($clone->coords->get_dataref,
    $s->coords->get_dataref, "Cloning: PDLs also copy'ed");

$TODO = "test overlap_vol()";

# overlap_vol()
$s1->radius(100);
$s2->radius(200);
$expectoverlap = $s1->radius + $s2->radius - $expectdist;

# is_approx($s1->overlap_vol($s2), $expectoverlap, 'overlap_vol()', $tolerance);
ok 0;

done_testing;
