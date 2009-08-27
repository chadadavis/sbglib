#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Data::Dumper;
use Data::Dump qw/dump/;
use FindBin qw/$Bin/;

use SBG::InteractionIO::csv;

# Connected network
$file = shift || "$Bin/../data/ex_small.csv";
$io = new SBG::InteractionIO::csv(file=>$file);

my @iactions;
while (my $iaction = $io->read) {
    push @iactions, $iaction;
}
# Parsed all interactions
is(scalar(@iactions), 17, "read()");

# Verify that no duplicate nodes created
is($io->count, 6, "Unique node cache");


