#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;

use SBG::Network;
use SBG::Node;
use SBG::Seq;
use SBG::Interaction;

# use Bio::Network::Node;
# use SBG::Search::SCOP;


# Sequences becomes nodes become networks
my $seq1 = new SBG::Seq(-accession_number=>'RRP43');
my $seq2 = new SBG::Seq(-accession_number=>'RRP41');
my $node1 = new SBG::Node($seq1);
my $node2 = new SBG::Node($seq2);
my $net = new SBG::Network;
$net->add_node($_) for ($node1, $node2);


# Test node indexing
my $gotnode = $net->nodes_by_id('RRP43');
is($gotnode, $node1, "nodes_by_id");


# Add an interaction and re-fetch it
my $interaction = new SBG::Interaction;
$net->add_interaction(
    -nodes=>[ $node1, $node2 ],
    -interaction => $interaction,
    );
%iactions = $net->get_interactions($net->nodes);
my ($got) = values %iactions;
is_deeply([sort $got->nodes], [sort $node1, $node2], "add_interaction");



