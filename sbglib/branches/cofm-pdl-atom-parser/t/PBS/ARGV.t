#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 'no_plan';

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";

my $DEBUG;
# $DEBUG = 1;

use File::Temp qw/tempdir/;

use PBS::ARGV qw/qsub linen nlines/;


# TODO TEST get tests from module docs

# TODO TEST distinguish between qsub not present and qsub error

# TODO TEST job array -J option

if (PBS::ARGV::can_connect) {

    @ARGV = 1..5;
    my $base = $ENV{'CACHEDIR'} || $ENV{'HOME'};
    mkdir $base;
    my $dir = tempdir(DIR=>$base, CLEANUP=>!$DEBUG);
    my @jobids = PBS::ARGV::qsub(directives=>["-o $dir", "-e $dir"]);
    if (! defined $ENV{'PBS_ENVIRONMENT'}) {
        is(scalar(@ARGV), 0, "All arguments submitted as PBS jobs");
    } 

} else {
    ok(1, "No PBS (permissions) skipping");
}

