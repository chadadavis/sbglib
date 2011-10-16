#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Debug;

use Test::More;

use Carp;
use File::Temp qw/tempfile/;


use SBG::U::DB;

unless (SBG::U::DB::ping) {
    plan skip_all => "No database";
}

use SBG::DB::entity;

my $pdbid = '103l';
my $chain = 'A';

# query()
my @hits;

@hits = SBG::DB::entity::query(
    $pdbid, $chain,
    pdbseq  => [ 1, 300 ],
    overlap => 0
);
is(scalar(@hits), 3, "query(overlap=>0.0)");

# With a overlap min thresh of 50% of each sequence
@hits = SBG::DB::entity::query(
    $pdbid, $chain,
    pdbseq  => [ 1, 300 ],
    overlap => 0.5
);
is(scalar(@hits), 1, "query(overlap=>0.5)");

my $dom = SBG::DB::entity::id2dom(2579998);
is($dom->descriptor, "A 7 _ to A 130 _", 'id2dom()');

$TODO = 'Test query_hit()';
ok 0;

done_testing;
