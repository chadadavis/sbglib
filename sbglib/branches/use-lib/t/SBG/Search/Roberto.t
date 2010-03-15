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
use Bio::SeqIO;

use SBG::Seq;
use SBG::Network;
use SBG::Search::Roberto;

use SBG::U::Log qw/log/;
my $DEBUG;
# $DEBUG = 1;
SBG::U::Log::init(undef, loglevel=>'DEBUG') if $DEBUG;

use FindBin qw/$Bin/;
my $file = shift || "$Bin/030.fa";

my $seqio = Bio::SeqIO->new(-file=>$file);
my $net = SBG::Network->new;
while (my $seq = $seqio->next_seq) {
    $net->add_seq($seq);
}
is(scalar($net->nodes), 4, "nodes");

my $roberto = SBG::Search::Roberto->new;
$net->build($roberto);
# diag join("\n", $net->interactions);

__END__

my @edges = $net->edges;
is(scalar(@edges), 8, 'edges()');
# An edge may have multiple interactions
is($net->interactions, 44, 'Network::interactions');

my @subnets = $net->partition;
is(scalar(@subnets), 4, 'Network::partition');
@subnets = $net->partition(minsize=>3);
is(scalar(@subnets), 2, 'Network::partition minsize=>3');



