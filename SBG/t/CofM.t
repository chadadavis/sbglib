#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::CofM;
use SBG::Domain;

use PDL;
use PDL::Matrix;

my ($x, $y, $z, $rg, $file, $desc);

#NB the numerical coparisons below are not at al reliable. Better way?

my $tol = 0.05;

# query()
my @a = SBG::CofM::query('2nn6', 'A');
ok(@a, "SBG::CofM::query('2nn6', 'A')");
my ($x, $y, $z, $rg, $file, $desc) = @a;
my ($tx, $ty, $tz, $trg) = (80.860, 12.450, 122.080, 26.738);

ok($x >= $tx-$tol  && $x <= $tx+$tol,  "x ~ $tx +/- $tol");
ok($y >= $ty-$tol  && $y <= $ty+$tol,  "y ~ $ty +/- $tol");
ok($z >= $tz-$tol  && $z <= $tz+$tol,  "z ~ $tz +/- $tol");
ok($rg >= $trg-$tol  && $rg <= $trg+$tol,  "rad. gyr. ~ $trg +/- $tol");

is($desc, "CHAIN A", "CofM::query descriptor: CHAIN A");
ok($file, "CofM::query file set");
print "\tfile: $file\n";

# run()
my $dom = new SBG::Domain(-label=>'2nn6A');
my @b = SBG::CofM::run($dom);
($x, $y, $z, $rg, $file, $desc) = @b;

ok($x >= $tx-$tol  && $x <= $tx+$tol,  "x ~ $tx +/- $tol");
ok($y >= $ty-$tol  && $y <= $ty+$tol,  "y ~ $ty +/- $tol");
ok($z >= $tz-$tol  && $z <= $tz+$tol,  "z ~ $tz +/- $tol");
ok($rg >= $trg-$tol  && $rg <= $trg+$tol,  "rad. gyr. ~ $trg +/- $tol");

is($desc, "CHAIN A", "CofM::query descriptor: CHAIN A");
ok($file, "CofM::query file set");
print "\tfile: $file\n";

# get_cofm()
my $dom2 = new SBG::Domain(-label=>'2nn6A');
get_cofm($dom2);
ok(defined($dom2->cofm), "get_cofm cofm");
ok($dom2->rg, "get_cofm rg");
is($dom2->descriptor, "CHAIN A", "get_cofm descriptor: CHAIN A");
ok($dom2->file, "get_cofm file");
print "\tfile: $file\n";

$dom2->descriptor("A 50 _ to A 120 _");
get_cofm($dom2);
my ($x, $y, $z, $rg) = ($dom2->_cofm2array, $dom2->rg);
($tx, $ty, $tz, $trg) = (83.495, 17.452, 114.562, 15.246);
ok($x >= $tx-$tol  && $x <= $tx+$tol,  "x ~ $tx +/- $tol");
ok($y >= $ty-$tol  && $y <= $ty+$tol,  "y ~ $ty +/- $tol");
ok($z >= $tz-$tol  && $z <= $tz+$tol,  "z ~ $tz +/- $tol");
ok($rg >= $trg-$tol  && $rg <= $trg+$tol,  "rad. gyr. ~ $trg +/- $tol");


__END__


