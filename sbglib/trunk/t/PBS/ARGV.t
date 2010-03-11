#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 'no_plan';
use FindBin qw/$Bin/;

use PBS::ARGV qw/qsub linen nlines/;


# TODO TEST get tests from module docs

# TODO TEST distinguish between qsub not present and qsub error

# TODO TEST job array -J option

if (PBS::ARGV::has_qsub) {

    @ARGV = 1..5;
    my @jobids = qsub();
    if (! defined $ENV{'PBS_ENVIRONMENT'}) {
        is(scalar(@ARGV), 0, "All arguments submitted as PBS jobs");
    } 

} else {
    ok(1, "has_qsub() false, skipping");
}


my $file = "$Bin/data/lines.csv";
is(nlines($file), 4, 'nlines');

# last line of file
is(linen($file, 3), 'three', "linen");

# first line of file
is(linen($file, 0), 'zero', "linen");

# Doesn't exist
ok(! linen($file, 4), "linen");
