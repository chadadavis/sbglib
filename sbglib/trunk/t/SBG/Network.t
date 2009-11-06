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


# Sequences becomes nodes become networks
my $seq1 = new SBG::Seq(-accession_number=>'RRP43');
my $seq2 = new SBG::Seq(-accession_number=>'RRP41');
my $net = new SBG::Network;

# Node objects are automatically created from sequence objects, and added
$net->add_seq($seq1,$seq2);

# Test node indexing
my $node1 = new SBG::Node($seq1);
my $node2 = new SBG::Node($seq2);
my $gotnode = $net->nodes_by_id('RRP43');
is($gotnode, $node1, "nodes_by_id");

# Add an interaction and re-fetch it
my $interaction = new SBG::Interaction;
$net->add_interaction(
    -nodes=>[ $node1, $node2 ],
    -interaction => $interaction,
    );
my %iactions = $net->get_interactions($net->nodes);
my ($got) = values %iactions;
is_deeply([sort $got->nodes], [sort $node1, $node2], "add_interaction");



