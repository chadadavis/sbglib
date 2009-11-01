#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::U::Test qw/pdl_approx float_is/;
use Carp;
use Data::Dumper;
use File::Temp qw/tempfile/;
$File::Temp::KEEP_ALL = 1;


use SBG::U::DB qw/connect/;
use Scalar::Util qw/refaddr/;

# Test connection caching
my $dbh1 = connect('trans_3_0', 'wilee.embl.de');
my $dbh2 = connect('trans_3_0', 'wilee.embl.de');

is(refaddr($dbh1),refaddr($dbh2), "connect() caching");
