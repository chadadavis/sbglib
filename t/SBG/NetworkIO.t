#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test 'float_is';
use feature 'say';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
my $dir = $FindBin::RealBin;
$, = ' ';

use SBG::NetworkIO qw(graphviz graphvizmulti);
use SBG::Storable qw/retrieve_files/;

# my $file = shift || "$dir/ex_descriptors.csv";
my $file = shift || "$dir/ex_small.csv";
my $io = new SBG::NetworkIO(file=>$file);
my $net = $io->read;

SKIP: {
    skip "GraphViz needs update";

# GraphViz
# my $graphout = "$dir/graph.png";
$graphout = "$dir/graph.dot";
graphviz($net, $graphout, -edge_color=>'grey',-fontsize=>8);
ok(-r $graphout, "GraphViz conversion: $graphout");
# unlink $graphout unless shift;

$graphmultiout = "$dir/graph.dot";
graphvizmulti($net, $graphmultiout);
ok(-r $graphout, "GraphViz (multiedged) conversion: $graphmultiout");
# unlink $graphmultiout unless shift;

};

$file = shift || "$dir/ex_disconnected.csv";
# my $file = shift || "$dir/ex_small.csv";

$io = new SBG::NetworkIO(file=>$file);
$net = $io->read;

my @graphs = $net->partition();
foreach my $g (@graphs) {
    say "\tconnected component:$g";
}

my (undef, $tfile) = tempfile();
$net->store($tfile);
my ($retrieved) = retrieve_files($tfile);
is($net, $retrieved, "retrieved: $retrieved");


