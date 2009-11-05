#!/usr/bin/env perl

=head1 NAME

SBG::Run::pdbseq - Wrapper for running B<pdbseq>


=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainI>

=cut

################################################################################

package SBG::Run::pdbseq;
use base qw/Exporter/;
our @EXPORT_OK = qw/pdbseq/;

use File::Temp qw/tempfile/;
use Bio::SeqIO;
use SBG::DomainIO::stamp;


################################################################################
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
    my $dompath = $domio->file;
    my (undef, $fapath) = tempfile(TMPDIR=>1);
    `pdbseq -f $dompath > $fapath`;
    my $faio = Bio::SeqIO->new(-file=>$fapath);
    my @seqs;
    while (my $seq = $faio->next_seq) {
        push @seqs, $seq;
    }
    return unless @seqs;
    return wantarray ? @seqs : $seqs[0];

} # pdbseq


################################################################################
1;
