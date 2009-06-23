#!/usr/bin/env perl


use Test::More 'no_plan';
use SBG::Test 'float_is';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
my $dir = $FindBin::RealBin;
$, = ' ';

use PDL::Lite;
use PDL::Matrix;

use SBG::Domain;
use SBG::Domain::CofM;


################################################################################
# Sanity check


$s = new SBG::Domain::CofM(centre=>"1 2 3",radius=>2);
is($s->radius,2);
$s->radius(3.1);
is($s->radius,3.1);
ok($s->does('SBG::DomainI'));


# dist()
$s1 = new SBG::Domain::CofM(centre=>[qw(-6.61  -32.62  -53.18)]);
$s2 = new SBG::Domain::CofM(centre=>"80.86   12.45  122.08");
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


# Floating point precision
$prec = 4;


# DB fetching
$s = new SBG::Domain::CofM(pdbid=>'2nn6', descriptor=>'CHAIN A');
($tx, $ty, $tz, $trg) = (80.860, 12.450, 122.080, 26.738);
@a = $s->asarray;
float_is($a[0], $tx, $prec);
float_is($a[1], $ty, $prec);
float_is($a[2], $tz, $prec);
float_is($s->radius, $trg, $prec);


# Running
$s = new SBG::Domain::CofM(pdbid=>'2nn6', descriptor=>'A 50 _ to A 120 _');
($tx, $ty, $tz, $trg) = (83.495, 17.452, 114.562, 15.246);
@a = $s->asarray;
float_is($a[0], $tx, $prec);
float_is($a[1], $ty, $prec);
float_is($a[2], $tz, $prec);
float_is($s->radius, $trg, $prec);


# With negative coords
$s = new SBG::Domain::CofM(pdbid=>'1jzd', descriptor=>'A -3 _ to A 60 _');
($tx, $ty, $tz, $trg) = (16.005,   50.005,   31.212, 11.917);
@a = $s->asarray;
float_is($a[0], $tx, $prec);
float_is($a[1], $ty, $prec);
float_is($a[2], $tz, $prec);
float_is($s->radius, $trg, $prec);


# Running multiple segments
$s = new SBG::Domain::CofM(pdbid=>'1dan', descriptor=>'CHAIN T U 91 _ to U 106 _');
($tx, $ty, $tz, $trg) = (33.875, 22.586, 43.569, 12.424);
@a = $s->asarray;
float_is($a[0], $tx, $prec);
float_is($a[1], $ty, $prec);
float_is($a[2], $tz, $prec);
float_is($s->radius, $trg, $prec);


# Storable
my (undef, $file) = tempfile(SUFFIX=>".stor");
ok($s->store($file), "Serializing to $file");


TODO: {
    local $TODO = "test applying non-trivial transformation";
    ok(1);

    # Validate that the raw cofm times the cumulative
    # transform is the cum. cofm But still, should maintain current cofm, for sake
    # of overlap detection
    local $TODO = "test cumulative transform";
    ok(1);

    local $TODO = "test with residue insertion codes in descriptor";
    ok(1);

}



__END__

# TODO
use SBG::Domain::CofMVol;
# Test voverlap and voverlaps

$s = new SBG::Domain::CofM(pdbid=>'2nn6', descriptor=>'A 50 _ to A 120 _');


__END__
# Copy construction
sub type { 'SBG::Domain::CofM' }
my $dom = new SBG::Domain(pdbid=>'2nn6', descriptor=>'A 50 _ to A 120 _');
print 'dom:', Dumper $dom, "\n";
my $cdom = type()->new(%$dom);
print 'cdom:', Dumper $cdom, "\n";