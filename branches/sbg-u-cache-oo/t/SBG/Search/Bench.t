#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use Carp;
$SIG{__DIE__} = \&confess;


use File::Temp qw/tempfile/;

use Moose::Autobox;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";

use SBG::Seq;
use SBG::Node;
use SBG::Search::Bench;
use SBG::Network;

use SBG::U::Log qw/log/;
my $DEBUG;
# $DEBUG = 1;
SBG::U::Log::init(undef, loglevel=>'DEBUG') if $DEBUG;

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
    new SBG::Seq(-display_id=>'1ir2B.d.58.9.1-1'),
    new SBG::Seq(-display_id=>'1ir2B.c.1.14.1-1'),
    );
$searcher = new SBG::Search::Bench;
@iactions = $searcher->search(@seqs);
is(scalar(@iactions), 4, "search()");

# Reverse
@seqs = (
    new SBG::Seq(-display_id=>'1ir2B.c.1.14.1-1'),
    new SBG::Seq(-display_id=>'1ir2B.d.58.9.1-1'),
    );
$searcher = new SBG::Search::Bench;
@iactions = $searcher->search(@seqs);
is(scalar(@iactions), 4, "search()");


my $net = new SBG::Network;
@accnos = SBG::Search::Bench::components('2os7');
@seqs = map { new SBG::Seq(-display_id=>$_) } @accnos;
@nodes = map { new SBG::Node($_) } @seqs;
$net->add_node($_) for @nodes;


$net = $net->build(new SBG::Search::Bench, cache=>0); # no limits, nocache
is($net->nodes, 12, 'Network::nodes');

my @edges = $net->edges;
is(scalar(@edges), 8, 'edges()');
# An edge may have multiple interactions
is($net->interactions, 44, 'Network::interactions');

my @subnets = $net->partition;
is(scalar(@subnets), 4, 'Network::partition');
@subnets = $net->partition(minsize=>3);
is(scalar(@subnets), 2, 'Network::partition minsize=>3');



