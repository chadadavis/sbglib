#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use Carp;
use Data::Dumper;
use File::Temp qw/tempfile/;
$File::Temp::KEEP_ALL = 1;


use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test qw/pdl_approx float_is/;

use SBG::U::DB qw/connect/;
use Scalar::Util qw/refaddr/;

# Test connection caching
my $dbh1 = connect('trans_3_0', 'pevolution.bioquant.uni-heidelberg.de');
my $dbh2 = connect('trans_3_0', 'pevolution.bioquant.uni-heidelberg.de');

# Test bad connection
my $dbh3 = connect('blahblah', 'www.embl.de');
ok(!defined($dbh3), 'Testing timeout on www.embl.de');

is(refaddr($dbh1),refaddr($dbh2), "connect() caching");

# HTTP Should be listening
ok(SBG::U::DB::_port_listening('google.com', 80), '_port_listening');
# 2 is nothing, Should not be listening
ok(! SBG::U::DB::_port_listening('localhost', 2), '_port_listening');
