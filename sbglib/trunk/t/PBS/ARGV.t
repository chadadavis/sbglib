#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 'no_plan';

use PBS::ARGV qw/qsub/;

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
