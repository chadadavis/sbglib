#!/usr/bin/env perl
use Modern::Perl;
use Bio::SeqIO;

# Interface templates are clustered ('c')
# Alternatively use SBG::Search::TransDB for a redundant set
use SBG::Search::TransDBc;
# or use PairedBlast, which does not verify contacts: SBG::Search::PairedBlast

use SBG::U::List qw/pairs/;

my $fasta_file = shift or die "Gimme a Fasta file\n";
my $io = Bio::SeqIO->new(-format=>'fasta',-file=>$fasta_file);
my @seqs;
while (my $seq = $io->next_seq) { push @seqs, $seq }

# Interface template search method, per pair of sequences
my $searcher = SBG::Search::TransDBc->new();

# All pairs of sequences read
my @pairs = pairs(@seqs);

foreach my $pair (@pairs) {
    my ($seq1, $seq2) = @$pair;
    my @interface_templates = $searcher->search($seq1, $seq2);
    next unless @interface_templates;

    # If you want to see what's in the objects;
    # use Data::Dumper;
    # say Dumper for @interface_templates;
    say for @interface_templates;
}

    
    
