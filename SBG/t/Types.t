#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test 'float_is';
use feature 'say';
use Carp;
use Data::Dumper;
# $, = ' ';


use SBG::Types qw/$pdb41/;

my $thing = '2nn6A';
my ($pdb,$ch) = $thing =~ /$pdb41/;
is($pdb, '2nn6');
is($ch, 'A');


################################################################################
# Requires (outside functionality that I assume)



################################################################################
# Provides (promises made to users of my module)



