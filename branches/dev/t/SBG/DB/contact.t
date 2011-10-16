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

use SBG::DB::contact;

my $e1 = { id => 203891 };
my $e2 = { id => 203893 };
my @hits;

# query()
@hits = SBG::DB::contact::query($e1, $e2);
is(scalar(@hits), 1, "query()");
my ($hit1) = @hits;

# test bidirectionality
@hits = SBG::DB::contact::query($e2, $e1);
is(scalar(@hits), 1, "query()");
my ($hit2) = @hits;

is($hit1->{n_res1}, $hit2->{n_res2}, "bidirectional query");

done_testing;


