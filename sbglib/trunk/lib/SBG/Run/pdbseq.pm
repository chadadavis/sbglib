#!/usr/bin/env perl

=head1 NAME

SBG::Run::pdbseq - Wrapper for running B<pdbseq>


=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainI>

=cut



package SBG::Run::pdbseq;
use base qw/Exporter/;
our @EXPORT_OK = qw/pdbseq/;

use File::Temp qw/tempfile/;
use Bio::SeqIO;
use SBG::DomainIO::stamp;
use IO::String;


=head2 pdbseq

 Function: 
 Example : 
 Returns : L<Bio::Seq>
 Args    : 


B<pdbseq> must be in your PATH

=cut
sub pdbseq {
    my (@doms) = @_;
    my $domio = SBG::DomainIO::stamp->new(tempfile=>1);
    $domio->write($_) for @doms;
    $domio->close; # Flush
    my $dompath = $domio->file;
    my (undef, $fapath) = tempfile(TMPDIR=>1);
    my $seqstr = `pdbseq -min 1 -f $dompath`;
    return unless $seqstr && $seqstr =~ /^>/;
    my $instr = IO::String->new($seqstr); 
    my $faio = Bio::SeqIO->new(-fh=>$instr, -format=>'Fasta');
    my @seqs;
    while (my $seq = $faio->next_seq) {
        push @seqs, $seq;
    }
    return unless @seqs;
    return wantarray ? @seqs : $seqs[0];

} # pdbseq



1;
