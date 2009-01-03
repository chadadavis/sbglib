#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::NetworkIO;

my $file = shift || "$installdir/t/ex_templates_descriptors.csv";

my $io = new SBG::NetworkIO(-file=>$file);
my $net = $io->read;

# GraphViz
my $graphout = "$installdir/t/graph.png";
SBG::NetworkIO::graphviz($net, $graphout,-edge_color=>'grey');
ok(-r $graphout, "GraphViz PNG creation");
unlink $graphout unless shift;

__END__

