#!/usr/bin/env perl

use Test::More 'no_plan';

use strict;

use SBG::List qw(union intersection nsort flatten lcp pairs);

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


# TODO test reorder()

