#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Debug;

use Test::More;
use File::Temp qw/tempfile/;
use Moose::Autobox;

use SBG::Split::3DR;
use Bio::SeqIO;

my $splitter = SBG::Split::3DR->new(mingap => 30);
unless ($splitter->_dbh) {
    ok warn "skip : no database\n";
    exit;
}

# A fasta file of two sequences, with various domains
my $file = "$Bin/data/85.fa";
my $in   = Bio::SeqIO->new(-file => $file);
my $seq1 = $in->next_seq;

my ($feats, $boundaries);

$feats = $splitter->query($seq1);
$boundaries = $feats->map(sub { $_->start, $_->end });
is_deeply(
    $boundaries,
    [qw/258 487 502 570 575 684/],
    "Query to Bio::SeqFeature"
);

$feats = $splitter->_smooth_feats($seq1, $feats);
$boundaries = $feats->map(sub { $_->start, $_->end });
is($boundaries->[-1], $seq1->length, "Stretching first/last domain to end");
is_deeply(
    $boundaries,
    [qw/258 494 495 572 573 686/],
    "Smoothing feature boundaries"
);

$feats = $splitter->_fill_feats($seq1, $feats);
$boundaries = $feats->map(sub { $_->start, $_->end });
is_deeply(
    $boundaries,
    [qw/1 257 258 494 495 572 573 686/],
    "Filling with dummy domains"
);

my $subseqs = $splitter->split($seq1);
is($subseqs->length, 4, "split() into subsequence domains");

done_testing;
