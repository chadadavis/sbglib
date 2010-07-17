#!/usr/bin/env perl

=head1 NAME




=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 SEE ALSO



=cut



package SBG::DB::res_mapping;
use base qw/Exporter/;
our @EXPORT_OK = qw/query aln2locations/;

use DBI;
use Log::Any qw/$log/;
use List::Util qw/min/;

use SBG::U::DB qw/chain_case/;


# TODO DES OO
our $database = "trans_3_0";
our $host;


=head2 query

 Function: 
 Example : 
 Returns : L<SBG::DomainI>
 Args    : 
    

Takes an ArrayRef rather than $start, $end now. This should contain all the
positions in between that also need to be fetched.  Rows are returned according
to the order in sequence, not in the structure, i.e. the residue IDs returned
are not necessarily in order, but they do correspond to the order of the
sequence given, as long as the sequence is ordered.

       
=cut
sub query {
    my ($pdbid, $chainid, $pdbseq) = @_;
    our $database;
    our $host;

    my $dbh = SBG::U::DB::connect($database, $host);

    my $pdbseqstr = join(',', @$pdbseq);
    # Covert lower case to uppercase, if necessary
    $chainid = chain_case($chainid);


    my $query = <<END;
SELECT
resseq
FROM 
res_mapping
WHERE idcode='$pdbid'
AND chain='$chainid'
AND pdbseq in ($pdbseqstr)
ORDER BY pdbseq
END

    my $resseq = $dbh->selectcol_arrayref($query);

    unless ($resseq) {
        $log->error($dbh->errstr);
        return;
    }
    unless (scalar @$resseq) {
        $log->error("No residues mapped for $pdbid$chainid");
        return;
    }
    return $resseq;

} # query




=head2 aln2locations

 Function: Converts a L<Bio::SimpleAlign> to ArrayRefs of sequence coordinates
 Example : my %coords = aln2locations($mybiosimplealign);
 Returns : Hash, keyed by the Bio::Seq->display_id()
 Args    : L<Bio::SimpleAlign>, e.g. from a Blast hit.

Removes any gapped columns (columns with any gaps at all), and truncates the longer sequence in the alignment. I.e. the ArraysRefs are both of equal length (i.e. only for alignments of exactly two sequences).

Each ArrayRef can be fed to L<query> to lookup corresponding PDB residue IDs.


=cut
sub aln2locations {
    my ($aln) = @_;

    # Bio::Seq objects
    my $seq1 = $aln->get_seq_by_pos(1);
    my $seq2 = $aln->get_seq_by_pos(2);
    # Extract raw character strings, and chop to equal length
    my ($seq1seq, $seq2seq) = flush_seqs($seq1->seq, $seq2->seq);
    # Relative sequence begin of each sequence in the alignment, 1-based
    my $seq1i = $seq1->start;
    my $seq2i = $seq2->start;
    # Jump over gaps, incrementally count other positions
    my @seq1pos = map { /[.-]/ ? undef : $seq1i++ } split '', $seq1seq;
    my @seq2pos = map { /[.-]/ ? undef : $seq2i++ } split '', $seq2seq;
    # Which positions are not gapped in either sequence
    my @mask = 
        grep { defined $seq1pos[$_] && defined $seq2pos[$_] } 0 .. $#seq1pos;
    # Filter out positions that are gapped in either sequence
    @seq1pos = @seq1pos[@mask];
    @seq2pos = @seq2pos[@mask];

    # Get keys from alignment
    my %locations = ($seq1->display_id => [ @seq1pos ],
                     $seq2->display_id => [ @seq2pos ],
        );
    return %locations;

} # aln2locations


# Make two strings the same length, by chopping the longer
sub flush_seqs {
    my ($seq1, $seq2) = @_;
    my $minlen = min(length($seq1), length($seq2));
    $seq1 = substr($seq1, 0, $minlen);
    $seq2 = substr($seq2, 0, $minlen);
    return ($seq1, $seq2);
}



1;
