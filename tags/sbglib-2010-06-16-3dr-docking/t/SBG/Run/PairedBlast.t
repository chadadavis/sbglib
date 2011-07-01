#!/usr/bin/env perl

use Test::More 'no_plan';

use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp qw/tempfile/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test 'float_is';
use SBG::U::Log;


$SIG{__DIE__} = \&confess;
my $DEBUG;
# $DEBUG = 1;
SBG::U::Log::init(undef, loglevel=>'DEBUG') if $DEBUG;
$File::Temp::KEEP_ALL = $DEBUG;


use SBG::Run::PairedBlast qw/gi2pdbid/;
use Bio::SeqIO;


# Convert upper to lower case chain names:
my $pdbgi = 'pdb|1g3n|BB pdb|1tim|AA';
my @res = SBG::Run::PairedBlast::gi2pdbid($pdbgi);
my @gi_expect = ( [ qw/1g3n b/ ], [ qw/1tim a/ ] );
is_deeply(\@res, \@gi_expect, 
          "gi2pdbid(): Blast double uppercase chain to lowercase");

# Lowercase retained?
$pdbgi = 'pdb|1g3n|0';
@res = gi2pdbid($pdbgi);
@gi_expect = ( [ qw/1g3n 0/ ]);
is_deeply(\@res, \@gi_expect, 
          "gi2pdbid(): CHAIN 0 respected");


my $io = new Bio::SeqIO(-file=>"$Bin/../data/2br2AB.fa");
my $seq1 = $io->next_seq;
my $seq2 = $io->next_seq;

# Get pairs of hits from common PDB structure
# my $blast = SBG::Run::PairedBlast->new();
my $blast;
my $method;
$method = 'standaloneblast';
ok(blastmethod($method, $seq1, $seq2), "$method");
$method = 'remoteblast';
ok(blastmethod($method, $seq1, $seq2), "$method");

sub blastmethod {
    my ($method, $seq1, $seq2) = @_;
    my $blast =SBG::Run::PairedBlast->new(verbose=>$DEBUG, 
                                          method=>$method);
    my @hitpairs = $blast->search($seq1, $seq2);
    return scalar @hitpairs;

}


# Test limit
# NB this does not imply that always 10 pairs are returned
# Only that each monomer has 10 hits, max
# Pairing them generally results in more than 10 hits
$blast =SBG::Run::PairedBlast->new(verbose=>$DEBUG, 
                                      method=>'remoteblast');
my @hitpairs = $blast->search($seq1, $seq2, limit=>10);
ok(scalar(@hitpairs), 'with limit=10 monomeric hits on each side');


# gi2pdbid









