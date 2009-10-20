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
use Bio::Tools::Run::StandAloneNCBIBlast;
extends qw/Bio::Tools::Run::StandAloneNCBIBlast Moose::Object/;

use SBG::U::List qw/intersection pairs2/;
use SBG::U::Log qw/log/;



################################################################################
=head2 new

 Function: 
 Example : 
 Returns : 
 Args    : 


NB Need to override new() as Bio::Network::ProteinNet is not of Moose

=cut
override 'new' => sub {
    my ($class, %ops) = @_;

    $ops{'-database'} = 'pdbaa' unless defined $ops{'-database'};
    $ops{'-j'} = 2 unless defined $ops{'-j'};
    $ops{'-e'} = 0.01 unless defined $ops{'-e'};

    # Create instance of parent class
    my $obj = $class->SUPER::new(%ops);

    # Moosify it
    $obj = $class->meta->new_object(__INSTANCE__ => $obj);

    # bless'ing should be automatic!
    bless $obj, $class;
    return $obj;
};


################################################################################
=head2 search

 Function: 
 Example : 
 Returns : Array of 2-tuples (i.e. pairs) of L<Bio::Search::Hit::HitI>
 Args    : Two L<Bio::PrimarySeqI>


=cut
sub search {
    my ($self, $seq1, $seq2) = @_;

    # List of Blast Hits, indexed by PDB ID
    my %hits1 = $self->_blast1($seq1);
    my %hits2 = $self->_blast1($seq2);

    my @pairs;
    # Get the PDB IDs that are present at least once in each of two hit lists
    foreach my $id (SBG::U::List::intersection([keys %hits1],[keys %hits2])) {
        # Generate all 2-tuples between elements of one list and elements of the
        # other. I.e. all pairs of one hit in 1AD5 for the first sequence and
        # any hits from the second sequence that are also on 1AD5
        push @pairs, SBG::U::List::pairs2($hits1{$id}, $hits2{$id});
    }

    return @pairs;
}


# Blast a sequence and index hits by PDB ID (4-char)
sub _blast1 {
    my ($factory, $seq) = @_;
    my @hits = $factory->blastpgp($seq)->next_result->hits;
    log()->trace($seq->display_id(), ":", scalar(@hits), " hits");
    # Index by pdbid
    my %hitsbyid;
    foreach my $h (@hits) {
        my $pdbid = _gi2pdbid($h->name);
        $hitsbyid{$pdbid} ||= [];
        push @{$hitsbyid{$pdbid}}, $h;
    }
    return %hitsbyid;

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
