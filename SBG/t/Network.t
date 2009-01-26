#!/usr/bin/env perl

use Test::More 'no_plan';

use strict;
use SBG::Network;
use SBG::NetworkIO;

my $file = shift || "$installdir/t/ex_disconnected.csv";
# my $file = shift || "$installdir/t/ex_small.csv";

my $io = new SBG::NetworkIO(-file=>$file);
my $net = $io->read;

print join("|", $net->nodes), "\n";

# TODO update NetworkIO to return SBG::Network
bless $net, 'SBG::Network';

# my @graphs = $net->partition();
my @graphs = SBG::Network::partition($net);


foreach my $g (@graphs) {
#     print  Dumper $g;
    print "$g\n";
}
