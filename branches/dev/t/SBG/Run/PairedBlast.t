#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use Test::More;

use Bio::SeqIO;

use SBG::Debug qw(debug);
use SBG::Run::PairedBlast;

{
    my $seq = Bio::SeqIO->new(-file => "$Bin/../data/P25359.fa")->next_seq;
    my $blast = SBG::Run::PairedBlast->new(
        method   => 'standaloneblast',
        e        => 0.01,
        database => 'pdbaa'
    );
    my $test_id = '2NN6';
    my $hits    = $blast->_blast1($seq)->{$test_id};
    my $nhits   = @$hits;
    ok($nhits > 0, "Blast -e bug workaround: RRP43 hits on $test_id: $nhits");
}


{
    my $io   = new Bio::SeqIO(-file => "$Bin/../data/2br2AB.fa");
    my $seq1 = $io->next_seq;
    my $seq2 = $io->next_seq;

    # Get pairs of hits from common PDB structure
    my $method = 'standaloneblast';
    ok(blastmethod($method, $seq1, $seq2), "$method");
}

SKIP: {
    skip "Not using remote NCBI blast", 1;
    my $io   = new Bio::SeqIO(-file => "$Bin/../data/2br2AB.fa");
    my $seq1 = $io->next_seq;
    my $seq2 = $io->next_seq;

    my $method = 'remoteblast';
    ok(blastmethod($method, $seq1, $seq2), "$method");
}

sub blastmethod {
    my ($method, $seq1, $seq2) = @_;

    my $database = $method =~ /standalone/i ? 'pdbseq' : 'pdbaa';
    my $blast = SBG::Run::PairedBlast->new(
        verbose  => debug(),
        method   => $method,
        database => $database,
    );
    my @hitpairs = $blast->search($seq1, $seq2);
    return scalar @hitpairs;

}

# Test limit
# NB this does not imply that always 10 pairs are returned
# Only that each monomer has 10 hits, max
# Pairing them generally results in more than 10 hits
{
    my $io   = new Bio::SeqIO(-file => "$Bin/../data/2br2AB.fa");
    my $seq1 = $io->next_seq;
    my $seq2 = $io->next_seq;

    my $blast = SBG::Run::PairedBlast->new(
        verbose  => debug(),
        method   => 'remoteblast',
        database => 'pdbaa',
    );
    my @hitpairs = $blast->search($seq1, $seq2, limit => 10);
    ok(scalar(@hitpairs), 'with limit=10 monomeric hits on each side');
}


done_testing;
