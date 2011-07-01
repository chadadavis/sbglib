#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Data::Dumper;
use Data::Dump qw/dump/;
use FindBin qw/$Bin/;

use SBG::InteractionIO::csv;
use SBG::InteractionIO::html;

# Connected network
my $file = shift || "$Bin/../data/ex_small.csv";
my $in = new SBG::InteractionIO::csv(file=>$file);

my @iactions;
while (my $iaction = $in->read) {
    push @iactions, $iaction;
}
# Parsed all ineractions
is(scalar(@iactions), 17, "read()");

# Verify that no duplicate nodes created
is($in->count, 6, "Unique node cache");


$TODO = "Verify written interactions";
my $out = new SBG::InteractionIO::html(tempfile=>1);
$out->write(@iactions);
ok(0);



