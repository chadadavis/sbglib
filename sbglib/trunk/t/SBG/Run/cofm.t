#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 'no_plan';
use SBG::U::Test qw/float_is pdl_approx/;
use Data::Dumper;
use Data::Dump qw/dump/;

use SBG::Run::cofm qw/cofm/;
use SBG::Domain;

use PDL::Lite;
use PDL::Core qw/pdl/;

# Precision
my $prec = 0.1;


sub _test {
    my ($pdbid, $descriptor, $radius, @coords) = @_;

    my $input = new SBG::Domain(pdbid=>$pdbid, descriptor=>$descriptor);
    my $sphere = cofm($input);
    my $exp_center = pdl(@coords, 1.0);
    my $exp_r = $radius;
    pdl_approx($sphere->center, $exp_center, "center $exp_center", $prec);
    float_is($sphere->radius, $exp_r, "radius $exp_r", $prec);
}


# Simple segment
_test('2nn6', 'A 50 _ to A 120 _', 
      15.246, (83.495, 17.452, 114.562));


# With negative residue IDs
_test('1jzd', 'A -3 _ to A 60 _', 
      11.917, (16.005,   50.005,   31.212));


# Multi-segment
_test('2frq', 'B 100 _ to B 131 A B 150 _ to B 155 B',
      17.395, (70.445, 30.823, 55.482));


# Multi-segment
_test('1dan', 'CHAIN T U 91 _ to U 106 _', 
      12.424, (33.875, 22.586, 43.569));


# With Insertion codes
$TODO = "test insertion codes";
ok 0;


