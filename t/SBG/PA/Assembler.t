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
use SBG::Log;

# Vertices in graph
# our $graphsize = 50;
our $graphsize = 20;
# Multiplier for random XYZ coords (i.e. each between 0 and $spread)
our $spread=5;
# Min dist between Vertices to creat an edge
our $minbond=2.5;
our $maxbond=2.8;
# Minimium peptide length for a solution
our $minsize = 3;


SBG::Log::init('TRACE');


$SBG::PA::Point::resolution = 1;

# NB Don't actually have to partition here, as Traversal starts at each node 
my $graph = _randomgraph($graphsize);

ok($graph, "Random graph of size: " . scalar($graph->vertices()));

my $dotfile = SBG::PA::Assembler::graphviz($graph, "graph.dot");
ok(-r $dotfile, "Plotting");
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


if (0) {
my @partitions = $graph->connected_components;
print scalar(@partitions), " trees";
my $i = 0;
foreach my $nodeset (@partitions) {
    my $subgraph = _subgraph($graph, @$nodeset);
    next unless $subgraph->vertices > 2;
    my $dotfile = SBG::PA::Assembler::graphviz(
        $subgraph, sprintf("subgraph-%03d.dot", ++$i));
    warn "subgraph of size ", scalar($subgraph->vertices()), " $dotfile\n";
}
}



################################################################################

# NB no way to abort a branch.
# Just mark it bad and let it go, pick it back up on the way back

sub _pre {
    my ($v, $traversal) = @_;
    my $h = $v->hash();

    # Started down a bad path, do nothing until it's over
    if ($traversal->get_state('bad')) {
#         print "Skipping on bad path: $v\n";
        return;
    }

    # Path is still fine, but is the point in space occupied?
    unless ($traversal->has_state($h)) {
        # Store this point's location in 3D space
        $traversal->set_state($h, 1);
        print "Set $h (a ", $v->{'res'}, ")\n";
        # Current path along a peptide
        _push($traversal, $v);
    } else {
        print "Beginning bad path from $h (", $v->{'res'}, ")\n";
        # Mark path as bad until we get to _post on this same vertex
        $traversal->set_state('bad',$v);
    }
}

sub _post {
    my ($v, $traversal) = @_;

    my $bad = $traversal->get_state('bad');
    if ($bad) {
        if ("$bad" eq "$v") {
            # If this vertex marked the beginning of a bad path, clear it now
            $traversal->delete_state('bad');
            print "Cleared badness from $v\n";
        } else {
#             print "Waiting to clear $bad\n";
            return;
        }
    } else {
        # Try to remove from path, if it was on it.
        if (_pop($traversal, $v)) {
            # Remove this vertex's 3D hash
            my $h = $v->hash();
            print "Unset $h (a ", $v->{'res'}, ")\n";
            $traversal->delete_state($h);
        }
    }
}


sub _push {
    my ($traversal, $v) = @_;
    my $current = $traversal->get_state('current') || [];
    # Add ref to next AA to current path
    push @$current, $v;
    my @sequence = map { $_->{'res'} } @$current;
    print "Peptide @sequence\n";
    $traversal->set_state('current', $current);
}


sub _pop {
    my ($traversal, $v) = @_;
    my $current = $traversal->get_state('current') || [];
    # Add ref to next AA to current path
    my $next = $current->[@$current-1];
    # Any case where this isn't true?
    if ("$next" eq "$v") {
        print "Popping $v\n";
        pop(@$current);
        my @sequence = map { $_->{'res'} } @$current;
        print "Peptide @sequence (shortened) \n";
        $traversal->set_state('current', $current);
        return 1;
    } else {
#         print "waiting for:$next,v:$v\n";
        return 0;
    }
}


sub _subgraph {
    my ($graph, @vertices) = @_;
    my $subgraph = new Graph::Undirected;
    foreach my $v (@vertices) {
        foreach my $n ($graph->neighbors($v)) {
            $subgraph->add_edge($v, $n);
        }
    }
    return $subgraph;
}


sub _randomgraph {
    my ($size) = @_;
    $size ||= 50;
#     warn "Graph size: $size\n";
    my @points = map { SBG::PA::Point::random($spread) } (1..$size);
#     my $graph = new Graph(refvertexed=>1,undirected=>1,multiedged=>1);
    my $graph = new Graph(refvertexed=>1,undirected=>1);
    for (my $i=0;$i<@points;$i++) {
        my $pi = $points[$i];
        for (my $j = $i+1; $j< @points;$j++) {
            my $pj = $points[$j];
            
#             my $d = _dist($pi->{'coords'}, $pj->{'coords'});
            my $d = $pi->dist($pj);
            if ($d < $maxbond && $d > $minbond) {
#                 $graph->add_edge($pi, $pj);
                $graph->set_edge_attribute($pi, $pj, "$pi--$pj", 1);
#                 $graph->set_edge_attribute_by_id($pi, $pj, "$pi--$pj", "$pi--$pj", 1);
            }
        }
    }
    return $graph;
}


__END__

sub _randompoint {
    my $res = ('A'..'Z')[rand 26];
#     my ($x,$y,$z) = map { sprintf "%.2f", 100*rand() } (1..3);
    my ($x,$y,$z) = map { $spread*rand() } (1..3);
    return new PA('res'=>$res, 'coords'=>[$x,$y,$z]);
}


sub _dist {
    my ($p1, $p2) = @_;
    my ($x1,$y1,$z1) = @$p1;
    my ($x2,$y2,$z2) = @$p2;
    my $d = sqrt(($x1-$x2)**2 + ($y1-$y2)**2 + ($z1-$z2)**2);

    return $d;
}

