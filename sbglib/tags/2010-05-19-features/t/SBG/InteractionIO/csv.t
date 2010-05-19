#!/usr/bin/env perl

use Test::More 'no_plan';
use Data::Dumper;
use Data::Dump qw/dump/;
use FindBin qw/$Bin/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test 'float_is';

use SBG::InteractionIO::csv;

# Connected network
my $file = shift || "$Bin/../data/ex_small.csv";
my $io = new SBG::InteractionIO::csv(file=>$file);

my @iactions;
while (my $iaction = $io->read) {
    push @iactions, $iaction;
}
# Parsed all interactions
is(scalar(@iactions), 17, "read()");

# Verify that no duplicate nodes created
is($io->count, 6, "Unique node cache");


