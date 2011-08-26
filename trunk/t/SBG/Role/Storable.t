#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';

use Carp;

use File::Temp qw/tempfile/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Debug;
use SBG::Seq;
use SBG::Role::Storable;

# Sequences becomes nodes become networks
# my $seq1 = new SBG::Seq(-display_id=>'RRP43');
my $seq1 = new Bio::PrimarySeq(-display_id => 'RRP43');
my (undef, $file) = tempfile('sbg_XXXXX', TMPDIR => 1, SUFFIX => '.stor');

store($seq1, $file);

my $seq2 = retrieve $file;

is($seq1, $seq2, "store / retrieve");

