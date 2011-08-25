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

use SBG::U::Cache qw/cache_get cache_set/;
our $cachename = 'sbgpdbseq';

=head2 pdbseq

 Function: 
 Example : 
 Returns : L<Bio::Seq>
 Args    : 


B<pdbseq> must be in your PATH

=cut

sub pdbseq {
    my (@doms) = @_;

    my @seqs = map { _cache($_) } @doms;

    return unless @seqs;
    return wantarray ? @seqs : $seqs[0];

}    # pdbseq

=head2 _cache

 Function: 
 Example : 
 Returns : 
 Args    : 

# TODO needs to be refactored into SBG::U::Cache since every module does this

=cut

sub _cache {
    my ($dom) = @_;

    our %cache;

    # Caching on by default
    #     my $cache = 1 unless defined $ops{cache};
    my $cache = 1;
    my $key   = $dom->id();
    my $seq   = cache_get($cachename, $key) if $cache;
    if (defined $seq) {

        # [] is the marker for a negative cache entry
        return if ref($seq) eq 'ARRAY';
        return $seq;
    }

    # Cache miss, run external program
    $seq = _run($dom);

    unless ($seq) {

        # failed, set negative cache entry
        cache_set($cachename, $key, []) if $cache;
        return;
    }

    cache_set($cachename, $key, $seq) if $cache;
    return $seq;

}    # _cache

=head2 _run

 Function: 
 Example : 
 Returns : 
 Args    : 



=cut

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

}    # pdbseq

1;
