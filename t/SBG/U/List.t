#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
$, = ' ';

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";

# Autoboxing native types
use Moose::Autobox;

# Also: Look for methods of ARRAY objects in SBG::U::List
use autobox ARRAY => 'SBG::U::List';

# Add this in to test
use SBG::U::List
    qw/union intersection nsort sum flatten lcp pairs mean swap argmin argmax/;

use Test::Approx;

# Single element
my ($elem, $max) = argmax {$_} (5);
is($elem, 5);
is($max,  5);

# Multiple
($elem, $max) = argmax {$_} (5, 2, 6, 3);
is($elem, 6);
is($max,  6);

# With objects
($elem, $max) =
    argmax { $_->{val} }
({ val => 5 }, { val => 2 }, { val => 6 }, { val => 3 });
is_deeply($elem, { val => 6 });
is($max, 6);

# Scalar context
$elem =
    argmax { $_->{val} }
({ val => 5 }, { val => 2 }, { val => 6 }, { val => 3 });
is_deeply($elem, { val => 6 });

# Min
$elem =
    argmin { $_->{val} }
({ val => 5 }, { val => 2 }, { val => 6 }, { val => 3 });
is_deeply($elem, { val => 2 });

my @a       = 1 .. 10;
my @b       = 5 .. 15;
my @c       = 7 .. 12;
my @flat    = flatten([ [ \@a, @b ], [ @c, \@b ] ]);
my @ex_flat = (@a, @b, @c, @b);
is_deeply([ @a, @b, @c, @b ],
    [ flatten([ [ \@a, @b ], [ @c, \@b ] ]) ], 'flatten()');

my @un = nsort union(@a, @b, \@c, [ @b, \@a ]);
is_deeply(\@un, [ 1 .. 15 ], "union()");

my @in = nsort intersection(\@a, \@b, \@c);
is_deeply(\@in, [ 7 .. 10 ], "intersection()");

{
    # TODO test with common elements and without, prefer to use Set::Scalar
    local $TODO = "Test difference()";
    ok 0;
}

# my @strings = qw(a.2.4.1-2 a.234 a.2.4.3-1 a.2.1.5-2 a.2.1);
my @strings = qw(a.2.4.1-2 a.234.5.6.8);

lcp(@strings);

is_deeply([ pairs(1 .. 3) ], [ [ 1, 2 ], [ 1, 3 ], [ 2, 3 ] ], "pairs(1..3)");
is_deeply([ pairs(1, 2) ], [ [ 1, 2 ] ], "pairs(1,2)");
is_deeply([ pairs(1) ], [], "pairs(1)");

# Text autoboxing

my $arrayref = [ 1 .. 10 ];
$arrayref->push(4);
is_deeply($arrayref, [ 1 .. 10, 4 ]);

my @vals  = 1 .. 4;
my $rvals = \@vals;
is(mean(@vals),  mean($rvals));
is(mean(@vals),  @vals->mean);
is(mean($rvals), $rvals->mean);
is(@vals->mean,  $rvals->mean);

# nsort
my $x = [ 4 .. 10, 8 .. 15, 2 .. 6 ];
is($x->sum, 161);
is($x->min, 2);
is($x->max, 15);
is_deeply(scalar($x->uniq),  [ 4 .. 15, 2 .. 3 ]);
is_deeply(scalar($x->union), [ 4 .. 15, 2 .. 3 ]);
is_deeply(scalar($x->union->nsort), [ 2 .. 15 ]);

my @sumtest = qw/77.34 3 66.1610268378063 12.5 0 40/;
is_approx(sum(@sumtest), 199.001027, 'sum()');

# swap scalars
my ($a, $b) = 1 .. 2;
swap($a, $b);
is($a, 2);
is($b, 1);

$x = $x->uniq;
my $xs    = $x->sort;
my $perm  = $x->permute;
my $perms = $perm->sort;
is_deeply($xs, $perms);

my $dota = [ 1, 2, 3, 4 ];
my $dotb = [ 5, 6, 7, 8 ];
my $dot = SBG::U::List::dotproduct($dota, $dotb);
my $dot_expect = [ 5, 12, 21, 32 ]->sum;
is_deeply($dot, $dot_expect, "dotproduct()");

my $wtavg = SBG::U::List::wtavg([ 80, 90 ], [ 20, 30 ]);
my $wtavg_expect = 86;
is($wtavg, $wtavg_expect, 'wtavg()');

# Some objects
my $objs = [ { name => 'joe' }, { name => 'alice' }, { name => 'frank' } ];

# An accessor
my $name = sub { (shift)->{name} };

# Original order of mapped variable
my $orign = $objs->map($name);

# Order we will request (a boring example: lexicographic)
my $sortedn = $orign->sort;

$TODO = "Fix reorder() to not squash duplicates";
ok(0);

# Reorder $objs, after applying $name->(), according to $sortedn
# my $r = $objs->reorder($sortedn, $name);
# Check that the resulting objects are in the right order, by checking the names
# my $rnames = $r->map($name);
# is_deeply($rnames, $sortedn);

done_testing;
