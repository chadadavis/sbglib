#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test 'float_is';
use Carp;
use Data::Dumper;
$, = ' ';


use SBG::Storable qw(retrieve_files);
use SBG::Network;
use SBG::Node;
use File::Temp qw(tempfile);
use SBG::Seq;
use SBG::Interaction;
use Bio::Network::Node;
use SBG::Search::SCOP;

my $net = new SBG::Network;
my $seq1 = new SBG::Seq(-accession_number=>'RRP43');
my $seq2 = new SBG::Seq(-accession_number=>'RRP41');
my $seqn = new Bio::Seq(-accession_number=>'RRP43');
my $node1 = new SBG::Node($seq1);
my $node2 = new SBG::Node($seq2);
my $noden = new Bio::Network::Node($seqn);

$net->add($node1);

@nodes = $net->nodes_by_id($seq1->accession_number);
# @nodes = $net->nodes_by_id('RRP43');

my $interaction = new SBG::Interaction(-id=>'iaction');
$net->add_interaction(
    -nodes=>[ $node1, $node2 ],
    -interaction => $interaction,
    );

@nodes = $net->nodes;
print "nodes:@nodes:\n";
%iactions = $net->get_interactions($net->nodes);
for (keys %iactions) {
    print "$_ : ", $iactions{$_}, "\n";
}


$net = new SBG::Network;

my @accnos = SBG::Search::SCOP::domains('2os7');
my @seqs = map { new SBG::Seq(-accession_number=>$_) } @accnos;
my @nodes = map { new SBG::Node($_) } @seqs;
$net->add($_) for @nodes;

$net->build(new SBG::Search::SCOP);
print "iactions: " . join("\n", sort $net->interactions), "\n";

my $subnets = $net->partition;
foreach my $subnet (@$subnets) {
    print "Subnet:$subnet\n"
}

my $subnet = $subnets->[0];
my $dotfile = $subnet->graphviz();
ok(-s $dotfile, "graphviz: $dotfile");
`dot -Tpng $dotfile | display`;


__END__



