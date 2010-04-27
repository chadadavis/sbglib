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

if (PBS::ARGV::has_permission) {

    @ARGV = 1..5;
    my $base = $ENV{'CACHEDIR'} || $ENV{'HOME'};
    my $dir = tempdir(DIR=>$base, CLEANUP=>!$DEBUG);
    diag $dir;
    my @jobids = qsub(directives=>["-o $dir", "-e $dir"]);
    if (! defined $ENV{'PBS_ENVIRONMENT'}) {
        is(scalar(@ARGV), 0, "All arguments submitted as PBS jobs");
    } 

} else {
    ok(1, "No PBS (permissions) skipping");
}


my $file = "$Bin/data/lines.csv";
is(nlines($file), 4, 'nlines');

# last line of file
is(linen($file, 3), 'three', "linen");

# first line of file
is(linen($file, 0), 'zero', "linen");

# Doesn't exist
ok(! linen($file, 4), "linen");
