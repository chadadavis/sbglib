#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp qw/tempfile/;

use SBG::U::Log qw/log/;
$SIG{__DIE__} = \&confess;
my $DEBUG;
# $DEBUG = 1;
log()->init('TRACE') if $DEBUG;
$File::Temp::KEEP_ALL = $DEBUG;


use SBG::Seq;
use SBG::Role::Storable;

# Sequences becomes nodes become networks
# my $seq1 = new SBG::Seq(-accession_number=>'RRP43');
my $seq1 = new Bio::PrimarySeq(-accession_number=>'RRP43');
my (undef, $file) = tempfile('sbg_XXXXX', TMPDIR=>1, SUFFIX=>'.stor');

store($seq1, $file);

my $seq2 = retrieve $file;

is($seq1, $seq2, "store / retrieve");





