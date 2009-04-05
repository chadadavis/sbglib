#!/usr/bin/env perl

use Test::More 'no_plan';
$,=' ';

# Autoboxing native types
use Moose::Autobox;
# Also: Look for methods of ARRAY objects in SBG::List
use autobox ARRAY => SBG::List;
# Add this in to test
use SBG::List qw(union intersection nsort flatten lcp pairs mean swap);


my @a = 1..10;
my @b = 5..15;
my @c = 7..12;
my @ex = nsort(flatten([[\@a,@b],[@c, \@b]]));
my @ex_chk = nsort(@a,@b,@c,@b);
is_deeply(\@ex, \@ex_chk, "flatten()");

my @un = nsort union(@a,@b,\@c, [@b,\@a]);
is_deeply(\@un, [1..15], "union()");

my @in = nsort intersection(\@a,\@b,\@c);
is_deeply(\@in, [7..10], "intersection()");

# my @strings = qw(a.2.4.1-2 a.234 a.2.4.3-1 a.2.1.5-2 a.2.1);
my @strings = qw(a.2.4.1-2 a.234.5.6.8);

lcp(@strings);

is_deeply([pairs(1..3)], [[1,2],[1,3],[2,3]], "pairs(1..3)");
is_deeply([pairs(1,2)], [[1,2]], "pairs(1,2)");
is_deeply([pairs(1)], [], "pairs(1)");

# Text autoboxing

my $arrayref = [ 1..10 ];
$arrayref->push(4);
is_deeply($arrayref, [1..10,4]);

@vals = 1..4;
my $rvals = \@vals;
is(mean(@vals), mean($rvals));
is(mean(@vals), @vals->mean);
is(mean($rvals), $rvals->mean);
is(@vals->mean, $rvals->mean);

# nsort
$x = [4..10, 8..15,2..6];
is($x->sum, 161);
is($x->min, 2);
is($x->max, 15);
is_deeply(scalar($x->uniq), [4..15,2..3]);
is_deeply(scalar($x->union), [4..15,2..3]);
is_deeply(scalar($x->union->nsort), [2..15]);

# swap scalars
my ($a, $b) = 1..2;
swap($a,$b);
is($a,2);
is($b,1);

$x = $x->uniq;
$xs = $x->sort;
$perm = $x->permute;
$perms = $perm->sort;
is_deeply($xs, $perms);


# Some objects
$objs = [ { name=>'joe'}, {name=>'alice'}, {name=>'frank'} ];
# An accessor
my $name = sub { (shift)->{name} };
# Original order of mapped variable
my $orign = $objs->map($name);
# Order we will request (a boring example: lexicographic)
my $sortedn = $orign->sort;
# Reorder $objs, after applying $name->(), according to $sortedn
$r = $objs->reorder($sortedn, $name);
# Check that the resulting objects are in the right order, by checking the names
$rnames = $r->map($name);
is_deeply($rnames, $sortedn);
