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

use SBG::U::DB;
my $dbh = SBG::U::DB::connect();
unless($dbh) {
    diag "Could not connect to database. Skipping database tests\n";
    exit;
}

use SBG::DB::contact;

my $e1 = { id=> 203891 };
my $e2 = { id=> 203893 };
my @hits;

# query()
@hits = SBG::DB::contact::query($e1,$e2);
is(scalar(@hits),1,"query()");
my ($hit1) = @hits;

# test bidirectionality
@hits = SBG::DB::contact::query($e2,$e1);
is(scalar(@hits),1,"query()");
my ($hit2) = @hits;

is($hit1->{n_res1},$hit2->{n_res2}, "bidirectional query");

