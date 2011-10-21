#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use Test::More;

# Load File::Slurp before File::Temp to avoid 'redefined' errors
use SBG::Debug qw(debug);
use File::Temp qw/tempfile/;

use File::Basename;
use Bio::SeqIO;

use SBG::U::DB;
use SBG::Node;
use SBG::Network;
use SBG::Run::PairedBlast;
use SBG::Search::TransDBc;

unless (SBG::U::DB::ping) {
    plan skip_all => 'No database';
}

plan skip_all => 'To test Blast, set BLASTDB=/path/to/database/dir/' unless $ENV{BLASTDB};

my $file = shift || "$Bin/../data/1g3n.fa";
my $name = basename($file, '.fa');
my $seqio = new Bio::SeqIO(-file => $file);
my @seqs;
while (my $seq = $seqio->next_seq) {
    push @seqs, $seq;
}

# Node objects from sequences
my @nodes = map { new SBG::Node($_) } @seqs;

# Empty network
my $net = new SBG::Network;

# Each node contains one sequence object
$net->add_node($_) for @nodes;

# Searcher tries to find interaction templates (edges) to connect nodes
my $blast = SBG::Run::PairedBlast->new(method => 'standaloneblast');

#my $blast = SBG::Run::PairedBlast->new(method=>'remoteblast');
my $searcher = SBG::Search::TransDBc->new(blast => $blast);
$net = $net->build($searcher, cache => ! debug());

# Potential interactions, between pairs of proteins
my $edges = scalar $net->edges;
ok($edges, "Network::edges $edges");

# Potential *types* of interactions, between all interacting pairs
# An edge may have multiple interactions
my $interactions = scalar $net->interactions;
ok($interactions, "Network::interactions: $interactions");

# Interaction network is not necessarily connected, if templates scarce
my @subnets = $net->partition;
my $subnets = scalar @subnets;
is($subnets, 1, "Network::partition: $subnets");

done_testing;
