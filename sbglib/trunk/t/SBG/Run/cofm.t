#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 'no_plan';
use Data::Dumper;
use Data::Dump qw/dump/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test qw/float_is pdl_approx/;
use SBG::U::Log;

my $DEBUG;
#$DEBUG = 1;
SBG::U::Log::init( undef, loglevel => 'DEBUG' ) if $DEBUG;

use SBG::Run::cofm qw/cofm/;
use SBG::Domain;

use PDL::Lite;
use PDL::Core qw/pdl/;

# Precision (or error tolerance)
my $prec = '2%';


sub _test {
    my ($input, $radius, @coords) = @_;
    my $sphere = cofm($input, cache=>$DEBUG);
    my $exp_center = pdl(@coords, 1.0);
    my $exp_r = $radius;
    pdl_approx($sphere->center, $exp_center, "center $exp_center", $prec);
    float_is($sphere->radius, $exp_r, "radius $exp_r", $prec);
}

my $input;


# Simple segment
$input = SBG::Domain->new(pdbid=>'2nn6', descriptor=>'A 50 _ to A 120 _');
_test($input, 15.246, (83.495, 17.452, 114.562));


# With negative residue IDs
$input = SBG::Domain->new(pdbid=>'1jzd', descriptor=>'A -3 _ to A 60 _');
_test($input, 11.917, (16.005,   50.005,   31.212));


# Multi-segment
$input = SBG::Domain->new(pdbid=>'2frq', descriptor=>'B 100 _ to B 131 A B 150 _ to B 155 B');
_test($input, 17.395, (70.445, 30.823, 55.482));


# Multi-segment
$input = SBG::Domain->new(pdbid=>'1dan', descriptor=>'CHAIN T U 91 _ to U 106 _');
_test($input, 12.424, (33.875, 22.586, 43.569));


# Without a PDB ID;
$input = SBG::Domain->new(file=>"$Bin/../data/docking2.pdb", descriptor=>'CHAIN A');
_test($input, 17.094, (-1.106,    3.405,    1.805));

# With Insertion codes
$TODO = "test insertion codes";
ok 0;


