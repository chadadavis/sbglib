#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Carp;

use File::Temp qw/tempfile/;
$File::Temp::KEEP_ALL = 1;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";

use SBG::U::DB qw/connect chain_case/;
use Scalar::Util qw/refaddr/;

# Test connection caching
my $dbh1 = connect('trans_3_0');
my $dbh2 = connect('trans_3_0');
is(refaddr($dbh1), refaddr($dbh2), "connect() caching");

# HTTP Should be listening
ok(SBG::U::DB::_port_listening('russelllab.org', 80), '_port_listening');

# 2 is nothing, Should not be listening
ok(!SBG::U::DB::_port_listening('russelllab.org', 2), '_port_listening');

# TODO refactor this into different module
my $chain;
$chain = 'a';
is(chain_case($chain), 'AA', 'chain_case to uc');
$chain = 'AA';
is(chain_case($chain), 'a', 'chain_case to lc');

$TODO = "How to test retry when 'too many connections'?";
ok(0);

$TODO = "skip tests if DB server not available";
ok(0);

done_testing();
