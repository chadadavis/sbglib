#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
use Data::Dumper;
# $, = ' ';


use SBG::Types qw/$pdb41 $re_descriptor/;

my $thing = '2nn6A';
my ($pdb,$ch) = $thing =~ /$pdb41/;
is($pdb, '2nn6');
is($ch, 'A');




my $desc;

$desc = 'A 3 _ to A 189 _';
ok($desc =~ /^\s*($re_descriptor)\s*$/, "Multi-segment descriptor");

$desc = 'A 3 _ to A 189 _ CHAIN A';
ok($desc =~ /^\s*($re_descriptor)\s*$/, "Multi-segment descriptor");

$desc = 'A 3 _ to A 189 _ A 353 _ to A 432 _';
ok($desc =~ /^\s*($re_descriptor)\s*$/, "Multi-segment descriptor");

$desc = 'A 3 A to A 189 B A 353 B to A 432 _';
ok($desc =~ /^\s*($re_descriptor)\s*$/, 
   "Multi-segment descriptor with insertion codes");


################################################################################
# Requires (outside functionality that I assume)



################################################################################
# Provides (promises made to users of my module)



