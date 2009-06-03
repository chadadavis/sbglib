#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
my $dir = $FindBin::RealBin;
$, = ' ';
$| = 1;

################################################################################

use SBG::PA::Assembler;
use SBG::PA::Point;
use Graph::Undirected;
use SBG::Traversal;
use SBG::U::Log;

SBG::U::Log::init('TRACE');

$SBG::PA::Point::resolution = 1;

# Vertices in graph
our $graphsize = 20;
# Multiplier for random XYZ coords (i.e. each between 0 and $spread)
our $spread=5;
# Min dist between Vertices to creat an edge
our $minbond=2.5;
our $maxbond=2.8;
# Minimium peptide length for a solution
our $minsize = 3;


# NB Don't actually have to partition here, as Traversal starts at each node 
my $graph = _randomgraph($graphsize);
ok($graph, "Random graph of size: " . scalar($graph->vertices()));

my $dotfile = SBG::PA::Assembler::graphviz($graph, "graph.dot");
ok(-r $dotfile, "Plotting $dotfile");
unlink $dotfile;

my $t = new SBG::Traversal(graph=>$graph, 
                           sub_test=>
                           \&SBG::PA::Assembler::sub_test, 
#                            sub_solution=>\&PA::sub_solution_gh,
                           sub_solution=>
                           \&SBG::PA::Assembler::sub_solution_pathhash,
                           minsize=>$minsize,
    );
my $accepted = $t->traverse();
ok($accepted, "Solutions: $accepted");

exit;

################################################################################



sub _randomgraph {
    my ($size) = @_;
    $size ||= 50;
    my @points = map { SBG::PA::Point::random($spread) } (1..$size);
    # NB Bug in Graph prevents correct usage of refvertexed=>1
    # Nonetheless, objects can be stored in the graph even with refvertexed=>0
#     my $graph = new Graph(refvertexed=>1,undirected=>1);
    my $graph = new Graph(refvertexed=>0,undirected=>1);
    for (my $i=0;$i<@points;$i++) {
        my $pi = $points[$i];
        for (my $j = $i+1; $j< @points;$j++) {
            my $pj = $points[$j];
            
            my $d = $pi->dist($pj);
            if ($d < $maxbond && $d > $minbond) {
                # Optional to add edge, also automatic via set_edge_attribute
#                 $graph->add_edge($pi, $pj);
                $graph->set_edge_attribute($pi, $pj, "$pi--$pj", 1);
                # Following isn't necessary, unless multi-edged graph
#                 $graph->set_edge_attribute_by_id($pi, $pj, "$pi--$pj", "$pi--$pj", 1);
            }
        }
    }
    return $graph;
}

