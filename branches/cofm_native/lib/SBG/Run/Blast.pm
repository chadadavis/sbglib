#!/usr/bin/env perl

=head1 NAME

SBG::Run::Blast - Common options for running local blastpgp, with caching

=head1 SYNOPSIS

 use SBG::Run::Blast;

 # Defaults: 
 # database => 'pdbaa', e => 1e-2, j=> 2, b => 500
 my $blast = SBG::Run::Blast->new(
     database => 'swissprot', min_id => .50, max_id => .75, 
 );
 my ($hits_a, $hits_b) = 
     $blast->search([$seqA, $seqB]);
 foreach my $hit (@$hits_a) {
     # For more details, see Bio::Search::Hit::HitI
     print $hit->name, "\n";
 }

=head1 DESCRIPTION

Blasts (multiple) sequences and returns a list of lists of hits. Given 3 query
sequences, 3 ArrayRefs will be returned. Each may contain zero or more
instances of L<Bio::Search::Hit::HitI>

Note, due to a bug in Blast's processing of the -e (e-value) parameter for
certain sequence, this module does not use that feature, but post-filters the
hits which do not meet the threshold. This results in the same semantics, with
a small performance penalty.

Remember to set the following variables (at least C<BLASTDB> )

=over 4

=item * BLASTDB      

to the directory containing the blast databases

=item * BLASTDATADIR 

to the directory containing the blast databases (also)

=item * BLASTMAT     

to the directory containing the BLOSUM/ PAM substitution matrices

=back

=head1 SEE ALSO

=over 4

=item * L<Bio::Tools::Run::StandAloneBlast>

=item * L<Bio::Tools::Run::RemoteBlast>

=item * L<Bio::Search::Hit::HitI>

=back

=head1 TODO

warn if database is not an absolute path and C<BLASTDB> isn't set.

=cut


package SBG::Run::Blast;
use strict;
use warnings;
use Moose;
use Exporter;
extends qw/Moose::Object Exporter/;
our @EXPORT_OK = qw(expand_aliases hits_by_pdbid);

use Moose::Autobox;
use namespace::autoclean;

use Bio::Tools::Run::StandAloneBlast;
use Log::Any qw/$log/;
use Scalar::Util qw/refaddr/;
use Digest::MD5 qw/md5_base64/;
use Carp;

# For cloning alias hits (duplicate sequences)
# NB Cannot use the (preferred) Storable::dclone here, as Hit contains CODEREFs
use Clone qw/clone/;

use SBG::U::Map qw(gi2pdbid);
use SBG::Debug qw(debug);
use SBG::Cache qw(cache);


=head2 j

Number of iterations of PSI-Blast. Default 2.

=cut 

has 'j' => (
    is      => 'rw',
    isa     => 'Maybe[Int]',
    default => 2,
);

=head2 e

Upper expectation value threshold. Default 0.01.

=cut 

has 'e' => (
    is      => 'rw',
    isa     => 'Maybe[Num]',
    default => 0.01,
);

=head2 b

Number of hits to keep, per iteration of PSI-BLAST. Default 500.

=cut 

has 'b' => (
    is      => 'rw',
    isa     => 'Maybe[Int]',
    default => 500,
);

=head2 database

Blast database name. Ddefault pdbaa.

=over 4

=item * pdbaa

pdbaa is the database from the NCBI which is based on the SEQRES field of the
PDB entry.

=item * pdbseq

pdbseq is the database created using the pdbseq tool from STAMP, whose
sequences are based on the residues actually present in a given structure
(based on C-alpha atoms).

=item * trans_3_0

trans_3_0 is the database of clustered interfaces.

=back

=cut

has 'database' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'pdbaa',
);


# Handle to Bio::Tools::Run::StandAloneBlast
has 'standalonefactory' => (
    is         => 'ro',
    lazy_build => 1,
    handles    => [qw/blastpgp/],
);


sub _build_standalonefactory {
    my ($self) = @_;
    # Don't use the 'e' option here
    # Bioperl option format: preceeded by dash:
    my $ops = { map { '-' . $_ => $self->{$_} } qw(b j database) };

    my $factory = Bio::Tools::Run::StandAloneBlast->new(%$ops);
    $factory->save_tempfiles(debug());
    return $factory;
}

=head2 search

Runs blastpgp on an ArrayRef of L<Bio::SeqI> and returns a list of ArrayRefs
of L<Bio::Search::Hit::HitI>

=cut

sub search {
    my ($self, $seqs, %ops) = @_;
    my $sets = [];
    for my $seq (@$seqs) {
        $sets->push($self->_blast1($seq));
    }
    return $sets;
}

my %_cache;
sub _blast1 {
    my ($self, $seq, %ops) = @_;

    if (! defined $ENV{BLASTDB}) {
        # Since the BioPerl error is not informative:
        croak "\n", 'To run local Blast, set BLASTDB=/path/to/database/dir/', "\n";
    }

    # Note, cannot use the file system cache, because HitI contains CODE which
    # cannot be serialized by Storable.
    # Hash the amino acid sequence (case sensitive)
    my $key    = md5_base64($seq->seq);
    my $hits = $_cache{$key};
    if (defined $hits) {
        $log->debug($seq->primary_id, ': ', $hits->length, " Hits (cached)");
        return $hits;
    }

    my $res = $self->blastpgp($seq)->next_result;
    $hits = [ $res->hits ];
    $log->debug($seq->primary_id, ': ', $hits->length, " Hits (raw)");

    # Only take the Hits that have > 0 HSPs
    $hits = $hits->grep(sub { $_->hsps });
    # E-value filtering here, as it's broken when using the -e option
    $hits = $hits->grep(sub { $_->significance < $self->e() });
    $log->debug($seq->primary_id, ': ', $hits->length, " Hits (filtered)");

    if ($ops{expand}) {
        $hits = expand_aliases($hits);
        $log->debug($seq->primary_id, ': ', $hits->length, " Hits (expanded)");
    }

    # Sort them descending by the Blast bit score of the best HSP of the Hit
    $hits = [ sort { $b->hsp->score <=> $a->hsp->score } @$hits ];
    $_cache{$key} = $hits;

    if (defined $ops{maxid}) {
        $ops{maxid} /= 100.0 if $ops{maxid} > 1;
        $log->debug("Maxium sequence identity fraction: ", $ops{maxid});
        $hits = $hits->grep(sub { $_->hsp->frac_identical <= $ops{maxid} });
    }

    if (defined $ops{minid}) {
        $ops{minid} /= 100.0 if $ops{minid} > 1;
        $log->debug("Minimum sequence identity fraction: ", $ops{minid});
        $hits = $hits->grep(sub { $_->hsp->frac_identical >= $ops{minid} });
    }

    return $hits;
}    # _blast1

=head2 hits_by_pdbid

Index hits by their PDB ID (for pdbaa database)

=cut

sub hits_by_pdbid {
    my ($hits) = @_;
    # Index by pdbid
    my $hitsbyid = {};
    foreach my $h (@$hits) {
        my $pdbid = gi2pdbid($h->name);
        $hitsbyid->{$pdbid} ||= [];
        $hitsbyid->at($pdbid)->push($h);
    }
    return $hitsbyid;
}

=head2 expand_aliases

Clone each hit that has multiple names, so that we can index everything by one
name.

 my $hits = $blast->expand_aliases($hits);

NB this depends on the blast database being formatted to include the
aliases. This is not the case for the pre-formatted databases downloaded from
the NCBI. Rather, download the fasta file and create the database with
formatdb or makeblastdb

=cut

sub expand_aliases {
    my ($hits) = @_;
    my $exphits = [];
    foreach my $hit (@$hits) {

        # $hit->name contains the name of the actual hit, get its ID too
        my $longdesc = $hit->name . ' ' . $hit->description;
        my @hitnames = gi2pdbid($longdesc);
        foreach my $hitname (@hitnames) {
            my ($pdb, $chain) = @$hitname;

            # Reformat it, respecting any lowercase chain names now
            my $name  = "pdb|$pdb|$chain";
            my $clone = clone($hit);
            $clone->accession($pdb);
            $clone->name($name);
            $clone->hsp->{HIT_NAME} = $name;

            # Trace history
            $clone->{refaddr} = refaddr $hit;
            push @$exphits, $clone;
        }
    }
    return $exphits;
}


__PACKAGE__->meta->make_immutable;


# Overload stringification of external package
use Bio::Search::Hit::BlastHit;
package Bio::Search::Hit::BlastHit;
use overload (
    '""'     => 'stringify',
    fallback => 1,
);
sub stringify { (shift)->name }

1;
