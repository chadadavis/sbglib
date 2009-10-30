#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';

use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp qw/tempfile/;

use SBG::U::Log qw/log/;
$SIG{__DIE__} = \&confess;
my $DEBUG;
# $DEBUG = 1;
log()->init('TRACE') if $DEBUG;
$File::Temp::KEEP_ALL = $DEBUG;

use SBG::Node;
use SBG::Network;
use SBG::Run::PairedBlast;
use SBG::Search::TransDB;

use Bio::SeqIO;
use File::Basename;
use FindBin qw/$Bin/;
my $file = shift || "$Bin/../data/1g3n.fa";
my $name = basename($file, '.fa');
my $seqio = new Bio::SeqIO(-file=>$file);
my @seqs;
while (my $seq = $seqio->next_seq) {
    push @seqs, $seq;
}
# Node objects from sequences
@nodes = map { new SBG::Node($_) } @seqs;
# Empty network
$net = new SBG::Network;
# Each node contains one sequence object
$net->add_node($_) for @nodes;
# Searcher tries to find interaction templates (edges) to connect nodes
$net = $net->build(new SBG::Search::TransDB,cache=>0);

# Potential interactions, between pairs of proteins
my @edges = $net->edges;
is(scalar(@edges), 10, 'edges()');

# Potential *types* of interactions, between all interacting pairs
# An edge may have multiple interactions
is($net->interactions, 487, 'Network::interactions');

# Interaction network is not necessarily connected, if templates scarce
my @subnets = $net->partition;
is(scalar(@subnets), 1, 'Network::partition');
