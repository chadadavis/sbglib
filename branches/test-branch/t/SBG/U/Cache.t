#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Debug;

use Test::More;
use Carp;
use File::Temp qw/tempfile/;

use SBG::Domain;
use SBG::U::Cache qw/cache/;

my $cache = cache('sbgtest');
my $dom1 = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN A');
$cache->set('thekey2', $dom1);
my $dom2 = $cache->get('thekey2');
is($dom2, $dom1, "cache get()");

done_testing;
