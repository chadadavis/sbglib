#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
$File::Temp::KEEP_ALL = 1;
my $dir = $FindBin::RealBin;
# Space-separated outputs
$, = ' ';
# Auto-Flush STDOUT
$| = 1;

################################################################################

