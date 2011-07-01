#!/usr/bin/env perl

use Test::More 'no_plan';

use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;

use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";
use SBG::U::Test 'float_is';
use SBG::Network;
use SBG::Node;
use SBG::Seq;
use SBG::Interaction;


# Sequences becomes nodes become networks
my $seq1 = new SBG::Seq(-display_id=>'RRP43');
my $seq2 = new SBG::Seq(-display_id=>'RRP41');
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

# Test symmetry
use Bio::SeqIO;
my $io = Bio::SeqIO->new(-file=>"$Bin/data/bovine-f1-atpase.fa");
my $snet = SBG::Network->new;
while (my $seq = $io->next_seq) { $snet->add_seq($seq); }

my $symm = $snet->symmetry;
my @cc = $symm->connected_components;
my $str = join(',', sort map { '(' . join(',',sort @$_) . ')' } @cc);
my $str_expected = 
    '(1e79A,1e79B,1e79C),(1e79D,1e79E,1e79F),(1e79G),(1e79H),(1e79I)';

is($str, $str_expected, 'symmetry()');
    
