#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 'no_plan';

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";

use SBG::Debug qw(debug);

use File::Temp qw/tempdir/;

use PBS::ARGV qw/qsub linen nlines/;


# TODO TEST get tests from module docs

# TODO TEST distinguish between qsub not present and qsub error

# TODO TEST job array -J option

unless (PBS::ARGV::can_connect) {
    ok warn "skip : No permissions to PBS\n";
    exit;
}


@ARGV = 1..5;
my $base = $ENV{CACHEDIR} || $ENV{HOME};
mkdir $base;
my $dir = tempdir(DIR=>$base, CLEANUP=> ! debug());
my @jobids = PBS::ARGV::qsub(directives=>["-o $dir", "-e $dir"]);
if (! defined $ENV{PBS_ENVIRONMENT}) {
    is(scalar(@ARGV), 0, "All arguments submitted as PBS jobs");
} 

