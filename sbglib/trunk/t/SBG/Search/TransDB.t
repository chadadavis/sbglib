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
$DEBUG = 1;
log()->init('TRACE') if $DEBUG;
$File::Temp::KEEP_ALL = $DEBUG;

use SBG::Run::PairedBlast;
use SBG::Search::TransDB;
use SBG::Network;
use Bio::SeqIO;

use FindBin qw/$Bin/;
my $io = new Bio::SeqIO(-file=>"$Bin/../data/2br2AB.fa");
my $seq1 = $io->next_seq;
my $seq2 = $io->next_seq;

my $transdb = SBG::Search::TransDB->new();
my @interactions = $transdb->search($seq1, $seq2);

is(scalar(@interactions), 12, "clustered interaction search");



__END__

# Sequence objects (Need to explicitly make SBG::Seq objects here?)
# @seqs = map { new SBG::Seq(-accession_number=>$_) } @accnos;
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
$net->build(new SBG::Search::TransDB);

# Number of nodes shouldn't change
is($net->nodes, 12, 'Network::nodes');

my @edges = $net->edges;
is(scalar(@edges), 8, 'edges()');
# An edge may have multiple interactions
is($net->interactions, 44, 'Network::interactions');

my @subnets = $net->partition;
is(scalar(@subnets), 2, 'Network::partition');



