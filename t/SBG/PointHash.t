#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::Test 'float_is';
use feature 'say';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
my $dir = $FindBin::RealBin;
$, = ' ';

################################################################################

use Math::Round qw/nearest/;
use Moose::Autobox;

my $h = {};

my $pt1 = _round([1.2,5.5,7.7]);
my $pt2 = _round([1.3,5.7,7.9]);

$h->put("@$pt1");

say Dumper $h;


################################################################################
sub _round {
    my ($coords) = @_;
    our $cellsize = 1;
    [ map { nearest($cellsize, $_) } @$coords ];
}
