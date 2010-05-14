#!/usr/bin/env perl

use Test::More 'no_plan';

use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp qw/tempfile/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test 'float_is';

use SBG::U::Log qw/log/;
$SIG{__DIE__} = \&confess;
my $DEBUG;
# $DEBUG = 1;
SBG::U::Log::init(undef, loglevel=>'DEBUG') if $DEBUG;
$File::Temp::KEEP_ALL = $DEBUG;

use SBG::U::DB;
my $dbh = SBG::U::DB::connect();
unless($dbh) {
    diag "Could not connect to database. Skipping database tests\n";
    exit;
}

use SBG::Node;
use SBG::Network;
use SBG::Run::PairedBlast;
use SBG::Search::TransDBc;

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
my @nodes = map { new SBG::Node($_) } @seqs;
# Empty network
my $net = new SBG::Network;
# Each node contains one sequence object
$net->add_node($_) for @nodes;
# Searcher tries to find interaction templates (edges) to connect nodes
my $blast = SBG::Run::PairedBlast->new(method=>'standaloneblast');
my $blast = SBG::Run::PairedBlast->new(method=>'remoteblast');
my $searcher = SBG::Search::TransDBc->new(blast=>$blast);
$net = $net->build($searcher, cache=>0);

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

