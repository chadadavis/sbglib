#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
$SIG{__DIE__} = \&confess;
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp qw/tempfile/;

use Moose::Autobox;

use SBG::Seq;
use SBG::Node;
use SBG::Search::Bench;
use SBG::Network;

use SBG::U::Log qw/log/;
log()->init('TRACE');

my @accnos;
my @seqs;
my @nodes;
my $searcher;
my @iactions;

my @ids = SBG::Search::Bench::pdbids();
is(scalar(@ids), 1155, "pdbids()");

@accnos = SBG::Search::Bench::components('2os7');
is(scalar(@accnos), 12, "components()");

@seqs = (
    new SBG::Seq(-accession_number=>'1ir2B.d.58.9.1-1'),
    new SBG::Seq(-accession_number=>'1ir2B.c.1.14.1-1'),
    );
$searcher = new SBG::Search::Bench;
@iactions = $searcher->search(@seqs);
is(scalar(@iactions), 4, "search()");

# Reverse
@seqs = (
    new SBG::Seq(-accession_number=>'1ir2B.c.1.14.1-1'),
    new SBG::Seq(-accession_number=>'1ir2B.d.58.9.1-1'),
    );
$searcher = new SBG::Search::Bench;
@iactions = $searcher->search(@seqs);
is(scalar(@iactions), 4, "search()");


my $net = new SBG::Network;
@accnos = SBG::Search::Bench::components('2os7');
@seqs = map { new SBG::Seq(-accession_number=>$_) } @accnos;
@nodes = map { new SBG::Node($_) } @seqs;
$net->add_node($_) for @nodes;


$net = $net->build(new SBG::Search::Bench, 0, 1); # no limits, nocache
is($net->nodes, 12, 'Network::nodes');

my @edges = $net->edges;
is(scalar(@edges), 8, 'edges()');
# An edge may have multiple interactions
is($net->interactions, 44, 'Network::interactions');

my @subnets = $net->partition;
is(scalar(@subnets), 2, 'Network::partition');


$TODO = "Test making Complex object from benchmark network";
ok 0;


