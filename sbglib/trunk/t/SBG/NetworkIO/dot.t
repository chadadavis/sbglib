#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Data::Dumper;
use Data::Dump qw/dump/;
use FindBin qw/$Bin/;

use SBG::Network;
use SBG::NetworkIO::csv;
use SBG::NetworkIO::dot;

my $file = shift || "$Bin/../data/ex_small.csv";
my $in = new SBG::NetworkIO::csv(file=>$file);
my $net = $in->read;
my $out = SBG::NetworkIO::dot->new(tempfile=>1);
$out->write($net);
$out->close;

# Validate the DOT format by sending it to circo (of Graphviz) for rendering
my $cmd = join ' ', 'circo', $out->file, '>/dev/null';
ok(system($cmd) == 0, "circo accepts DOT format");



