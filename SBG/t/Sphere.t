#!/usr/bin/env perl

use Test::More 'no_plan';
use feature 'say';

use SBG::Sphere;
use PDL::Lite;
use PDL::Matrix;
use List::Util;
use SBG::Test qw(float_is);

################################################################################
# Sanity check

$p = mpdl (1,2,3,1);
$s = new SBG::Sphere(centre=>$p);
isa_ok($s, "SBG::Sphere");
isa_ok($s->centre, "PDL::Matrix");
$s->centre([4,5,6]);
isa_ok($s->centre, "PDL::Matrix");
$s->centre('4 5 6');
isa_ok($s->centre, "PDL::Matrix");


################################################################################
# Requires


################################################################################
# Provides

# new()
$s = new SBG::Sphere(centre=>[-6.61,-32.62,-53.18]);
is($s->centre, mpdl (-6.61,-32.62,-53.18,1));

# asarray()
$s = new SBG::Sphere();
my @abc = qw(80.86   12.45  122.08);
my $p = mpdl (@abc,1);
$s->centre($p);
# Ignore 4th element (radius)
my @a = ($s->asarray)[0..2];
is_deeply(\@a, [@abc]);

# dist()
$s1 = new SBG::Sphere(qw(-6.61  -32.62  -53.18));
$s2 = new SBG::Sphere(qw(80.86   12.45  122.08));
my $diff = $s1->dist($s2);
$expectdist = 200.99;
$sigdigits = 5;
float_is($diff, $expectdist, $sigdigits);

# overlap()
$s1->radius(100);
$s2->radius(200);
$expectoverlap = $s1->radius + $s2->radius - $expectdist;
$sigdigits = 4;
float_is($s1->overlap($s2), $expectoverlap, $sigdigits);

# overlaps()
my $delta = 0.01; # Tolerate 1% error
$expectfrac = $expectoverlap / (2 * List::Util::min($s1->radius,$s2->radius));

ok($s1->overlaps($s2, $expectfrac-$delta), 
   'overlaps at lower thresh');
ok(! $s1->overlaps($s2, $expectfrac+$delta), 
   'overlaps not at upper thresh');

# Test voverlap and voverlaps

# TODO test applying non-trivial transformation 

# TODO Another test. 
# Validate that the raw cofm times the cumulative
# transform is the cum. cofm But still, should maintain current cofm, for sake
# of overlap detection



