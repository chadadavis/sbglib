#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Debug;
use Test::More;

use SBG::Network;
use SBG::NetworkIO::csv;
use SBG::NetworkIO::dot;

my $file = shift || "$Bin/../data/ex_small.csv";
my $in  = SBG::NetworkIO::csv->new(file => $file);
my $net = $in->read;
my $out = SBG::NetworkIO::dot->new(tempfile => 1);
$out->write($net);
$out->close;
ok(-s $out->file, 'File created');

# Validate the DOT format by sending it to circo (of Graphviz) for rendering
use IPC::Cmd qw/run can_run/;
SKIP: {
    my $path = can_run('circo');
    skip 'format validation: circo (GraphViz) not installed', 1 unless $path;
    my ($ok, undef, undef, undef, $stderr) =
        run(command => [ $path, $out->file ]);
    ok($ok, "circo accepts DOT format") or diag join "\n", @$stderr;

}

done_testing;
