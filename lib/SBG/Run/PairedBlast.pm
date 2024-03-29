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
PDB ID, as given by the BLAST sequence database.

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


Note, due to a bug in Blast's processing of the -e (e-value) parameter for certain sequence, this module does not use that feature, but post-filters the hits which do not meet the threshold. This results in the same semantics, with a small performance penalty. 

=head1 SEE ALSO

L<SBG::SearchI>

=head1 TODO

Factor out C<_blast1()> into L<SBG::Run::Blast> 

=cut

package SBG::Run::PairedBlast;
use strict;
use warnings;
use Moose;
use Moose::Autobox;

use Bio::Tools::Run::StandAloneBlast;
use Bio::Tools::Run::RemoteBlast;
use Log::Any qw/$log/;
use Scalar::Util qw/refaddr/;

# For cloning alias hits (duplicate sequences)
# NB Cannot use the (preferred) Storable::dclone here, as Hit contains CODEREFs
use Clone qw/clone/;

use SBG::U::List qw/intersection pairs2 interval_overlap/;
use SBG::Run::Blast qw(expand_aliases hits_by_pdbid);

has 'cache' => (
    isa     => 'HashRef',
    is      => 'ro',
    lazy    => 1,
    default => sub { {} },
);

# PSI-Blast iterations
has 'j' => (
    is      => 'rw',
    isa     => 'Maybe[Int]',
    default => 2,
);

# Upper expectation value threshold
has 'e' => (
    is      => 'rw',
    isa     => 'Maybe[Num]',
    default => 0.01,
);

# Number of hits to keep, per iteration of PSI-BLAST
has 'b' => (
    is      => 'rw',
    isa     => 'Maybe[Int]',
    default => 500,
);

=head2 database

 Function: Blast database name (default: pdbaa)
 Example : 
 Returns : 
 Args    : 


pdbaa is the database from the NCBI which is based on the SEQRES field of the PDB entry.

pdbseq is the database created using the pdbseq tool from STAMP, whose sequences are based on the residues actually present in a given structure.

=cut

has 'database' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'pdbseq',
);

has 'verbose' => (
    is  => 'rw',
    isa => 'Bool',
);

=head2 method

 Function: Set local or remote blast
 Example : 
 Returns : 
 Args    : 'standaloneblast' or 'remoteblast'

The remoteblast will require that B<database> is set to something that the NCBI
recognizes, i.e. one of the standard databases.

For the StandAloneBlast, the chose database must either exist in your
B<$BLASTDB> directory, or it must be specified with a full path, e.g.

 $blast->database('/usr/local/blastdb/pdbaa');

See the list of remote databases:
 
 http://www.ncbi.nlm.nih.gov/staff/tao/URLAPI/remote_blastdblist.html


=cut

has 'method' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'standaloneblast',
);

# Handle to Bio::Tools::Run::StandAloneBlast
has 'standalonefactory' => (
    is         => 'ro',
    lazy_build => 1,
    handles    => [qw/blastpgp/],
);

# Handle to Bio::Tools::Run::RemoteBlast
has 'remotefactory' => (
    is         => 'ro',
    lazy_build => 1,
);

# Polling frequency (seconds) for remoteblast
has 'wait' => (
    is      => 'rw',
    isa     => 'Int',
    default => 5,
);

sub _build_standalonefactory {
    my ($self) = @_;
    my $factory = Bio::Tools::Run::StandAloneBlast->new();

    $factory->verbose($self->verbose);
    $factory->save_tempfiles($self->verbose);

    $factory->database($self->database);

    # Maximum  number of passes to use in multipass version (default =1)
    $factory->j($self->j) if $self->j;

    # Expectation value (E) (default = 10.0)
    # TODO BUG in Blast, do not set e-value threshold
    #    $factory->e($self->e) if $self->e;
    # Number of database sequences to show alignments for (B) (default is 250)
    $factory->b($self->b) if $self->b;
    return $factory;
}

# $factory->submit_blast($seqobj);

sub _build_remotefactory {
    my ($self) = @_;
    my $factory = Bio::Tools::Run::RemoteBlast->new(
        -readmethod => 'SearchIO',
        -database   => $self->database,
    );

    # TODO BUG in Blast, do not set e-value threshold
    #    $factory->expect($self->e) if $self->e;

    return $factory;
}

# Returns Bio::SearchIO
sub standaloneblast {
    my ($self, $seq) = @_;
    my $factory = $self->standalonefactory;
    return $factory->blastpgp($seq);
}

# Returns Bio::SearchIO
# Seems to be limited to 100 Hits
sub remoteblast {
    my ($self, $seq) = @_;

    my $factory = $self->remotefactory;
    $factory->submit_blast($seq);

    my ($rid) = $factory->each_rid;
    $log->info("RID: $rid");
    while (sleep $self->wait) {
        my $rc = $factory->retrieve_blast($rid);
        if (ref $rc) {
            $factory->remove_rid($rid);
            return $rc;
        }
        elsif ($rc < 0) {

            # Abort if error
            $factory->remove_rid($rid);
            $log->error("Failed on RID: $rid");
            return;
        }
    }

}    # remoteblast

=head2 search

 Function: 
 Example : 
 Returns : Array of 2-tuples (i.e. pairs) of L<Bio::Search::Hit::HitI>
 Args    : Two L<Bio::PrimarySeqI>

NB the B<limit> option does not imply that less than that many pairs are
returned, only that each of the two queries is limited to that many
hits. Pairing them generally results in more hits.


=cut

sub search {
    my ($self, $seq1, $seq2, %ops) = @_;

    # List of Blast Hits, indexed by PDB ID
    my $hits1 = $self->_blast1($seq1, %ops) or return;
    my $hits2 = $self->_blast1($seq2, %ops) or return;

    my @pairs;
    my @common_pdbids = intersection($hits1->keys, $hits2->keys);

    # Get the PDB IDs that are present at least once in each of two hit lists
    foreach my $id (@common_pdbids) {

        # Generate all 2-tuples between elements of one list and elements of the
        # other. I.e. all pairs of one hit in 1AD5 for the first sequence and
        # any hits from the second sequence that are also on 1AD5
        my @hitpairs = SBG::U::List::pairs2($hits1->{$id}, $hits2->{$id});

        # Kick out hits that overlap on the same chain
        for (my $i = 0; $i < @hitpairs; $i++) {
            my ($hit1, $hit2) = @{ $hitpairs[$i] };

            # Skip check if they're not on the same chain
            next unless $hit1->name eq $hit2->name;
            my ($subject1, $subject2) =
                ($hit1->hsp->subject, $hit2->hsp->subject);
            my $frac_overlap = interval_overlap(
                $subject1->start, $subject1->end,
                $subject2->start, $subject2->end
            );
            if ($frac_overlap > 0.10) {
                my $msg =
                      $hitpairs[$i]->[0] . "("
                    . $subject1->start . '-'
                    . $subject1->end . ") "
                    . $hitpairs[$i]->[1] . "("
                    . $subject2->start . '-'
                    . $subject2->end . ") ";

                #                 $log->debug("Deleting overlapping hit ($frac_overlap) : $msg");
                delete $hitpairs[$i];
            }
        }
        @hitpairs = grep { defined $_ } @hitpairs;
        push @pairs, @hitpairs;
    }
    $log->info($seq1->display_id, '--', $seq2->display_id,, ': ',
        scalar(@pairs), ' Blast hit pairs');
    return @pairs;
}    # search

# Blast a sequence and index hits by PDB ID (4-char)
sub _blast1 {
    my ($self, $seq, %ops) = @_;
    my $limit = $ops{limit};

    # Enable Hit caching when RemoteBlast
    $ops{cache} = 1 unless defined $ops{cache};
    $ops{cache} = 1 if $self->method eq 'remoteblast';

    my $hits = $self->cache->at($seq);
    if ($ops{cache} && $hits) {
        $log->debug($seq->primary_id, ': ', $hits->length, " Hits (cached)");
    }
    else {
        my $method = $self->method;
        my $res;
        eval { $res = $self->$method($seq)->next_result; };
        if ($@) {
            $log->error("Blast crashed on seq $seq");
            return;
        }
        $hits = [ $res->hits ];

        # Only take the Hits that have > 0 HSPs
        $hits = $hits->grep(sub { $_->hsps });

        # E-value filtering here, as it's broken when using the -e option
        $hits = $hits->grep(sub { $_->significance < $self->e() });

        $log->debug($seq->primary_id, ': ', $hits->length, " Hits (raw)");

        # Expand alias sequences
        $hits = expand_aliases($hits);
        $log->debug($seq->primary_id, ': ', $hits->length,
            " Hits (expanded)");

        # Sort them descending by the Blast bit score of the best HSP of the Hit
        $hits = [ sort { $b->hsp->score <=> $a->hsp->score } @$hits ];
        $self->cache->put($seq, $hits) if $ops{cache};
    }

    if ($ops{maxid}) {
        $ops{maxid} /= 100.0 if $ops{maxid} > 1;
        $log->debug("Maxium sequence identity fraction: ", $ops{maxid});
        $hits = $hits->grep(sub { $_->hsp->frac_identical <= $ops{maxid} });
    }

    if ($ops{minid}) {
        $ops{minid} /= 100.0 if $ops{minid} > 1;
        $log->debug("Minimum sequence identity fraction: ", $ops{minid});
        $hits = $hits->grep(sub { $_->hsp->frac_identical >= $ops{minid} });
    }

    if ($limit && $limit < @$hits) {
        $hits = $hits->slice([ 0 .. $limit - 1 ]);
        $log->debug($seq->primary_id, ': ', $hits->length,
            " Hits (filtered)");
    }

    # Index by pdbid
    my $hitsbyid = hits_by_pdbid($hits);
    return $hitsbyid;
}    # _blast1


__PACKAGE__->meta->make_immutable(inline_constructor => 0);
no Moose;
1;
