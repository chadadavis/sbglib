#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Debug;

use Test::More;

use SBG::Network;
use SBG::NetworkIO::csv;

# Connected network
my $file = shift || "$Bin/../data/ex_small.csv";
my $io = new SBG::NetworkIO::csv(file => $file);
my $net = $io->read;
is(scalar($net->nodes),        6,  "nodes()");
is(scalar($net->interactions), 17, "interactions()");

# Disconnected network
$file = shift || "$Bin/../data/ex_disconnected.csv";
$io = new SBG::NetworkIO::csv(file => $file);
$net = $io->read;
is(scalar($net->nodes),        6, "nodes() (disconnected)");
is(scalar($net->interactions), 9, "interactions() (disconnected)");
my @graphs = $net->partition();
is(scalar(@graphs), 2, "partition()");

# Probably will require defining == for SBG::Network
$TODO = "Test write()";
ok 0;

# $io = new SBG::NetworkIO::csv;
# $io->write($net);

done_testing;
