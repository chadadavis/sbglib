#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Data::Dumper;
use Data::Dump qw/dump/;
use FindBin qw/$Bin/;

use SBG::Network;
use SBG::NetworkIO::csv;


# Connected network
$file = shift || "$Bin/data/ex_small.csv";
$io = new SBG::NetworkIO::csv(file=>$file);
$net = $io->read;
is(scalar($net->nodes), 6, "nodes()");
is(scalar($net->interactions), 17, "interactions()");


# Disconnected network
$file = shift || "$Bin/data/ex_disconnected.csv";
$io = new SBG::NetworkIO::csv(file=>$file);
$net = $io->read;
is(scalar($net->nodes), 6, "nodes() (disconnected)");
is(scalar($net->interactions), 9, "interactions() (disconnected)");
my @graphs = $net->partition();
is(scalar(@graphs), 2, "partition()");


# Probably will require defining == for SBG::Network
$TODO = "Test write()";
ok 0;
$io = new SBG::NetworkIO::csv;
# $io->write($net);


