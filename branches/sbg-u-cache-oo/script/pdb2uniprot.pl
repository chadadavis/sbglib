#!/usr/bin/env perl

=head1 NAME

B<pdb2uniprot> - Convert Fasta files from PDB chain IDs to Uniprot sequences 

=head1 SYNOPSIS

pdb2uniprot sequences.fa more_sequences.fa ...

=head1 DESCRIPTION

Each sequence in each fasta file must have a PDB chain ID for the identifier. This can look like any of these:

 * 3jqoa
 * 3JQOa
 * 3jqo|a
 * 3jqo.a
 * 3jqo*a
 
PDB IDs are not case-sensitive. Chain IDs are case-sensitive.

The resulting Uniprot sequences are written to a file with the same name in the current directory, unless it already exists, in which case '-uniprot' is appended.

The identifier will be unchanged, but the Uniprot ID will be prepended to the description line of the sequence.


=head1 SEE ALSO

L<Bio::DB::SGD>,

=cut 


use strict;
use warnings;

use Bio::SeqIO;
use File::Basename;
use Bio::DB::SwissProt;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::U::Map qw/pdb_chain2uniprot_acc/;

my $sp = Bio::DB::SwissProt->new;

foreach my $file (@ARGV) {
    my $in = Bio::SeqIO->new(-file=>$file);
    my $outfile = basename($file, '.fa');
    $outfile .= '.fa';
    if (-e $outfile) { 
        warn "Skipping existing $outfile\n";
        next;
    } 
    warn "$outfile\n";
    my $out = Bio::SeqIO->new(-file=>">$outfile");
    while (my $pdbseq = $in->next_seq) {
        my $pdbchainid = $pdbseq->display_id;
        $pdbseq->desc($pdbchainid . ' ' . $pdbseq->desc);
        my $uniprotacc = pdb_chain2uniprot_acc($pdbchainid);
        my $acc = $uniprotacc || $pdbchainid;
        my $seq = spseq($uniprotacc) || $pdbseq;
        
        $seq->display_id($pdbchainid);
        $out->write_seq($seq);
    }    
}

sub spseq {
    my ($uniprotacc) = @_;
    return unless $uniprotacc;   
    our %seqcache; 
    warn "\tFetching $uniprotacc\n";
    my $spseq = $seqcache{$uniprotacc};
    unless ($spseq) {
        $spseq = $sp->get_Seq_by_acc($uniprotacc);
        $spseq->desc($uniprotacc . ' ' . $spseq->desc);
        $seqcache{$uniprotacc} = $spseq;
    }
    return $spseq;
    
}
    
exit;

