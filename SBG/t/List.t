#!/usr/bin/env perl

use Test::More 'no_plan';

use strict;

use SBG::List qw(union intersection nsort);

my @a = 1..10;
my @b = 5..15;
my @c = 7..12;
my @ex = nsort(SBG::List::_expand_array([[\@a,@b],[@c, \@b]]));
my @ex_chk = nsort(@a,@b,@c,@b);
is_deeply(\@ex, \@ex_chk, "_expand_array()");

my @un = nsort union(@a,@b,\@c, [@b,\@a]);
is_deeply(\@un, [1..15], "union()");

my @in = nsort intersection(\@a,\@b,\@c);
is_deeply(\@in, [7..10], "intersection()");

# TODO test reorder()

