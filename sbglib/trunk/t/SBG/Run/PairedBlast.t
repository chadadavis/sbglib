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
$DEBUG = 1;
log()->init('TRACE') if $DEBUG;
$File::Temp::KEEP_ALL = $DEBUG;

use SBG::Run::PairedBlast;
use Bio::SeqIO;

use FindBin qw/$Bin/;
my $io = new Bio::SeqIO(-file=>"$Bin/../data/2br2AB.fa");
my $seq1 = $io->next_seq;
my $seq2 = $io->next_seq;

# Get pairs of hits from common PDB structure
my $blast = SBG::Run::PairedBlast->new(-verbose=>1);

my @hitpairs = $blast->search($seq1, $seq2);
is(scalar(@hitpairs), 210, 'PairedBlast::search()');

# Test limit
@hitpairs = $blast->search($seq1, $seq2, 10);
is(scalar(@hitpairs), 7, 'limit=10 monomeric hits each');


$TODO = "Test caching";
@hitpairs = $blast->search($seq1, $seq2);
ok(0);








