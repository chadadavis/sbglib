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


# use SBG::Seq;
use SBG::Domain;
use SBG::U::Cache qw/cache/;

my $cache = cache('sbgtest');
my $dom1 = SBG::Domain->new(pdbid=>'2br2', descriptor=>'CHAIN A');
$cache->set('thekey2', $dom1);
my $dom2 = $cache->get('thekey2');
is($dom2, $dom1, "cache get()");



