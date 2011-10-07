#!/usr/bin/env perl

=head1 NAME

SBG::Run::pdbseq - Wrapper for running B<pdbseq>


=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainI>

=cut

package SBG::Run::pdbseq;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT_OK = qw/pdbseq/;

use File::Temp qw/tempfile/;
use Bio::SeqIO;
use SBG::DomainIO::stamp;
use IO::String;

use SBG::Cache qw/cache/;

=head2 pdbseq

 Function: 
 Example : 
 Returns : L<Bio::Seq>
 Args    : 


B<pdbseq> must be in your PATH

=cut

sub pdbseq {
    my (@doms) = @_;
    my @seqs;
    my $cache = cache();
    for my $dom (@doms) {
        my $key   = $dom->id();
        my $seq   = $cache->get($key);
        if (! defined $seq) {
            # Cache miss, run external program
            $seq = _run($dom);
            $seq ||= [];
            $cache->set($key, $seq);
        }
        if (ref($seq) ne 'ARRAY') { push @seqs, $seq; }
    }
    # Assum we won't be called in scalar context with multiple inputs
    return wantarray ? @seqs : $seqs[0];

}    # pdbseq

sub _run {
    my (@doms) = @_;
    my $domio = SBG::DomainIO::stamp->new(tempfile => 1);
    $domio->write($_) for @doms;
    $domio->close;    # Flush
    my $dompath = $domio->file;
    my (undef, $fapath) = tempfile(TMPDIR => 1);
    my $seqstr = `pdbseq -min 1 -f $dompath`;
    return unless $seqstr && $seqstr =~ /^>/;
    my $instr = IO::String->new($seqstr);
    my $faio = Bio::SeqIO->new(-fh => $instr, -format => 'Fasta');
    my @seqs;

    while (my $seq = $faio->next_seq) {
        push @seqs, $seq;
    }
    return unless @seqs;
    return wantarray ? @seqs : $seqs[0];

}

1;
