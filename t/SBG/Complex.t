#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test 'float_is';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
my $dir = $FindBin::RealBin;
$, = ' ';

################################################################################

use SBG::Complex;
use SBG::Domain;
use Moose::Autobox;

my $d = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN D');
my $b = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN B');

my $complex = new SBG::Complex;

$complex->model('RRP43', $b);
$complex->model('RRP41', $d);

is($b, $complex->model('RRP43'), "Added to complex");
is($d, $complex->model('RRP41'), "Added to complex");

my $models = $complex->models->keys;
is($models->length, 2, "Complex stores Domain's");

# Test clone()
my $clone = $complex->clone;
@doms = sort @doms;
my @cdoms = sort $clone->asarray;
is(@doms, @cdoms, "Clone contains same # of components");

for (my $i = 0; $i < @doms; $i++) {
    ok($doms[$i] == $cdoms[$i], "Clone also contains $doms[$i]");
}

TODO: {
    local $TODO = 'test: if ($comp->clashes($dom)) { ... }';
    ok(1);

    local $TODO = 'Test Complex::rmsd()';
    ok(1);

    local $TODO = 'test ($rmsd, $trans) = $model_complex->min_rmsd($truth)';
    ok(1);

}
