#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Run::cofm qw/cofm/;
use SBG::U::Test qw/float_is/;
use Data::Dumper;
$, = ' ';


# Precision
my $prec = 4;

# Don't use a whole chain here, as those are cached in the DB
my $res;
$res = _test1('2nn6', "A 50 _ to A 120 _", 
              83.495, 17.452, 114.562, 15.246, 22.781);

$res = _test1('2frq', 'B 100 _ to B 131 A B 150 _ to B 155 B', 
              70.445, 30.823, 55.482, 17.395, 26.443);


$TODO = "test on multi-chain or multi-segment domains";
ok 0;

$TODO = "test insertion codes";
ok 0;


sub _test1 {
    my ($pdb, $descriptor, $tx, $ty, $tz, $trg, $trmax) = @_;
    my $res = cofm($pdb, $descriptor);
    float_is($res->{Cx},  $tx,   'Cx'  ,$prec);
    float_is($res->{Cy},  $ty,   'Cy'  ,$prec);
    float_is($res->{Cz},  $tz,   'Cz'  ,$prec);
    float_is($res->{Rg},  $trg,  'Rg'  ,$prec);
    float_is($res->{Rmax},$trmax,'Rmax',$prec);
    return $res;
}


# With negative coords
$TODO = 'With negative res IDs';
$s = new SBG::Domain::Sphere(pdbid=>'1jzd', descriptor=>'A -3 _ to A 60 _');
($tx, $ty, $tz, $trg) = (16.005,   50.005,   31.212, 11.917);
@a = $s->asarray;
float_is($a[0], $tx, 'tx', $tolerance);
float_is($a[1], $ty, 'ty', $tolerance);
float_is($a[2], $tz, 'tz', $tolerance);
float_is($s->radius, $trg, 'trg', $tolerance);


# Running multiple segments
$TODO = 'With multi-segment domains';
$s = new SBG::Domain::Sphere(pdbid=>'1dan', descriptor=>'CHAIN T U 91 _ to U 106 _');
($tx, $ty, $tz, $trg) = (33.875, 22.586, 43.569, 12.424);
@a = $s->asarray;
float_is($a[0], $tx, 'tx', $tolerance);
float_is($a[1], $ty, 'ty', $tolerance);
float_is($a[2], $tz, 'tz', $tolerance);
float_is($s->radius, $trg, 'trg', $tolerance);


