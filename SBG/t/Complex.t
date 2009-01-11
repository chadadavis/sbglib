#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::Complex;
use SBG::Domain;

my $d = new SBG::Domain(-label=>'2br2d');
my $b = new SBG::Domain(-label=>'2br2b');
my $complex = new SBG::Complex;

# Test lvalue routines, for adding Domain's to a Complex
# Test the ->comp($key) method (returns an lvalue)

# TODO
# $complex->comp($b->label) = $b;
# is($b,$complex->comp($b->label), "Lvalue assignment to Complex::comp(\$key)");
# Also test the "add"
$complex->add($b, $d);
is($d,$complex->comp($d->label), "SBG::Complex::add(SBG::Domain)");

my @doms = $complex->asarray;
is(2, @doms, "Complex stores Domain's");

# Test clone()
my $clone = $complex->clone;
@doms = sort @doms;
my @cdoms = sort $clone->asarray;
is(@doms, @cdoms, "Clone contains same # of components");
for (my $i = 0; $i < @doms; $i++) {
    ok($doms[$i] == $cdoms[$i], "Clone also contains $doms[$i]");
}

# TODO test: if ($comp->clashes($dom)) { ... }

# TODO Test Complex::rmsd()



