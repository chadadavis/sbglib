#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::NetworkIO qw(graphviz graphvizmulti);

# my $file = shift || "$installdir/t/ex_templates_descriptors.csv";
my $file = shift || "$installdir/t/ex_small.csv";

my $io = new SBG::NetworkIO(-file=>$file);
my $net = $io->read;

# GraphViz
# my $graphout = "$installdir/t/graph.png";
my $graphout = "$installdir/t/graph.dot";
graphviz($net, $graphout, -edge_color=>'grey',-fontsize=>8);
ok(-r $graphout, "GraphViz conversion");

graphvizmulti($net, $graphout);
ok(-r $graphout, "GraphViz (multiedged) conversion");

# unlink $graphout unless shift;


__END__

