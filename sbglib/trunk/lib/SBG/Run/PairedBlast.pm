#!/usr/bin/env perl

=head1 NAME

SBG::Search::PairedBlast - Find PDB entries, where two sequences hit one entry

=head1 SYNOPSIS

use SBG::Run::PairedBlast;

# Defaults: -database=>'pdbaa',-j=>2,-e=>1e-2
my $blast = SBG::Run::PairedBlast->new();
my $pairs_of_hits = $blast->search($seqA, $seqB);
foreach my $pair (@$pairs_of_hits) {
    my ($hit1, $hit2) = @$pair; # Bio::Search::Hit::HitI
    print $hit1->name, ',', $hit2->name, "\n";
}

=head1 DESCRIPTION


Blasts two sequences and returns a list of pairs of
L<Bio::Search::Hit::BlastHit> such that each hit of a pair come from the same
PDB ID, as given by the B<pdbaa> Blast sequence database.

Does not check any structural properties, i.e. whether the two matching regions
are actually in contact, that they do not overlap along a single chain. Also
performs no coordinate mapping. The coordinates of the hit objects refer to the
sequence coordinates of B<pdba> which correspond to the SEQRES sequence. These
are not the residue IDs of the structure.

The order of the tuples in the returned array correspond to the order of the two
given sequences. I.e. the first element of each pair corresponds to a hit for
the first sequence given; analogously for the second hit of each pair.

Remember to set the following variables:

BLASTDB to the directory containing the blast databases
BLASTDATADIR to the directory containing the blast databases
BLASTMAT to the directory containing the BLOSUM and PAM substitution matrices


=head1 SEE ALSO

L<SBG::SearchI>

=cut

################################################################################

use Bio::Search::Hit::BlastHit;
# Overload stringification of external package
package Bio::Search::Hit::BlastHit;
use overload ('""' => 'stringify');
sub stringify { (shift)->name }


package SBG::Run::PairedBlast;
use Moose;
use Bio::Tools::Run::StandAloneBlast;

use Moose::Autobox;

use SBG::U::List qw/intersection pairs2/;
use SBG::U::Log qw/log/;


has 'cache' => (
    isa => 'HashRef[Bio::Search::Hit::HitI]',
    is => 'ro',
    lazy => 1,
    default => sub { {} },
    );


has 'j' => (
    is => 'rw',
    isa => 'Maybe[Int]',
    default => 2,
    );


has 'e' => (
    is => 'rw',
    isa => 'Maybe[Num]',
    default => 0.01,
    );


# Number of hits to keep, per iteration of PSI-BLAST
has 'b' => (
    is => 'rw',
    isa => 'Maybe[Int]',
    default => 500,
    );

has 'database' => (
    is => 'rw',
    isa => 'Str',
    default => 'pdbaa',
    );

has 'verbose' => (
    is => 'rw',
    isa => 'Bool',
    );

has 'blast' => (
    is => 'ro',
    lazy_build => 1,
    handles => [ qw/blastpgp/ ],
    );

sub _build_blast {
    my ($self) = @_;
    my $factory = Bio::Tools::Run::StandAloneBlast->new();

    $factory->verbose($self->verbose);
    $factory->save_tempfiles($self->verbose);

    $factory->database($self->database);
    $factory->j($self->j) if $self->j;
    $factory->e($self->e) if $self->e;
    $factory->b($self->b) if $self->b;
    return $factory;

}


################################################################################
=head2 search

 Function: 
 Example : 
 Returns : Array of 2-tuples (i.e. pairs) of L<Bio::Search::Hit::HitI>
 Args    : Two L<Bio::PrimarySeqI>


=cut
sub search {
    my ($self, $seq1, $seq2, %ops) = @_;

    # List of Blast Hits, indexed by PDB ID
    my $hits1 = $self->_blast1($seq1, %ops);
    my $hits2 = $self->_blast1($seq2, %ops);

    my @pairs;
    my @common_pdbids = intersection($hits1->keys,$hits2->keys);

    # Get the PDB IDs that are present at least once in each of two hit lists
    foreach my $id (@common_pdbids) {
        # Generate all 2-tuples between elements of one list and elements of the
        # other. I.e. all pairs of one hit in 1AD5 for the first sequence and
        # any hits from the second sequence that are also on 1AD5
        my @hitpairs = SBG::U::List::pairs2($hits1->{$id}, $hits2->{$id});
        push @pairs, @hitpairs;
    }
    log()->debug(scalar(@pairs), ' Blast hit pairs');
    return @pairs;
}


# Blast a sequence and index hits by PDB ID (4-char)
sub _blast1 {
    my ($self, $seq, %ops) = @_;
    my $limit = $ops{limit};
    $ops{cache} = 1 unless defined $ops{cache};
    my $hits = $self->cache->at($seq);
    if ($ops{cache} && $hits) {
        log()->debug($seq->primary_id, ': ', $hits->length," hits (cached)");
    } else {
        my $res = $self->blastpgp($seq)->next_result;
        $res->sort_hits;
        $hits = [ $res->hits ];
        log()->debug($seq->primary_id, ': ', $hits->length," hits (raw)");
        $self->cache->put($seq, $hits) if $ops{cache};
    }
    if ($ops{maxid}) {
        $ops{maxid} /= 100.0 if $ops{maxid} > 1;
        log()->debug("Maxium sequence identity fraction:", $ops{maxid});
        $hits = $hits->grep(sub{$_->hsp->frac_identical<=$ops{maxid}});
    }
    if ($ops{minid}) {
        $ops{minid} /= 100.0 if $ops{minid} > 1;
        log()->debug("Minimum sequence identity fraction:", $ops{minid});
        $hits = $hits->grep(sub{$_->hsp->frac_identical>=$ops{minid}});
    }
    $hits = $hits->slice([0..$limit-1]) if $limit && $limit < @$hits;
    log()->debug($seq->primary_id, ': ', $hits->length," hits (filtered)");

    # Index by pdbid
    my $hitsbyid = _hitsbyid($hits);
    return $hitsbyid;
}


sub _hitsbyid {
    my ($hits) = @_;

    # Index by pdbid
    my $hitsbyid = {};
    foreach my $h (@$hits) {
        my $pdbid = _gi2pdbid($h->name);
        $hitsbyid->{$pdbid} ||= [];
        $hitsbyid->at($pdbid)->push($h);
    }
    return $hitsbyid;
}


# Extract PDB ID and chain
sub _gi2pdbid {
    my ($gi) = @_;
    my ($pdbid, $chain) = $gi =~ /pdb\|(.{4})\|(.*)/;
    return unless $pdbid;
    return $pdbid unless $chain && wantarray;
    return $pdbid, $chain;

}


################################################################################
__PACKAGE__->meta->make_immutable(inline_constructor=>0);
no Moose;
1;
