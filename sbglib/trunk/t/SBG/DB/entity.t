#!/usr/bin/env perl

use Test::More 'no_plan';

use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp qw/tempfile/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test 'float_is';
use SBG::U::Log;
$SIG{__DIE__} = \&confess;
my $DEBUG;
# $DEBUG = 1;
SBG::U::Log::init(undef, loglevel=>'DEBUG') if $DEBUG;
$File::Temp::KEEP_ALL = $DEBUG;


use SBG::DB::entity;

my $pdbid = '103l';
my $chain = 'A';

# query()
my @hits = SBG::DB::entity::query($pdbid, $chain, pdbseq=>[1, 300]);
is(scalar(@hits), 3, "query()");

my $dom = SBG::DB::entity::id2dom(2579998);
is($dom->descriptor, "A 7 _ to A 130 _", 'id2dom()');

$TODO = 'Test query_hit()';
ok 0;
