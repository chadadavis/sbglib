#!/usr/bin/env perl

=head1 NAME

SBG::Search::TransDBc - 

=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::SearchI> , L<SBG::Interaction> 

=cut



package SBG::Search::TransDBc;
use Moose;
with 'SBG::SearchI';

use Moose::Autobox;
use List::Util qw/min max sum/;
use List::MoreUtils qw/uniq/;
use Log::Any qw/$log/;
use Sort::Key::Top qw/rnkeytop rnkeyhead/;
use Sort::Key qw/rnkeysort/;
use Scalar::Util qw/refaddr/;

# Must load SBG::Seq to get string overload on Bio::PrimarySeqI
use SBG::Seq;

use SBG::Run::PairedBlast;
use SBG::Model;
use SBG::Domain;
use SBG::Interaction;

# TransDB lookups
use SBG::DB::entity;
use SBG::DB::contact;


has 'blast' => (
    is => 'ro',
    isa => 'SBG::Run::PairedBlast',
    default => sub { SBG::Run::PairedBlast->new() },
    );



=head2 search

 Function: 
 Example : 
 Returns : Array of <SBG::Interaction>
 Args    : Two L<Bio::Seq> objects
           

=cut
sub search {
    my ($self, $seq0, $seq1, %ops) = @_;

    # Sequence overlap required to match a record of 'entity' with a Blast hit
    $ops{overlap} ||= 0.50;
    my $entityops = {%ops}->hslice([qw/overlap/]);

    # Not the same as two independent blast searches:
    # only PDB IDs occuring >= once in both lists are retained
    # And overlaps on the same chain are excluded
    my @hitpairs = $self->blast->search($seq0, $seq1, %ops);

    # Each resulting entity will also contain a backreference to ->{'hit'}     
    my @entitypairs = map { _hitp2entityp($_,$entityops,$seq0,$seq1) } @hitpairs;

    # Each pair of entities may find multiple contacts, again 1-to-many
    my @contacts = map { SBG::DB::contact::query(@$_) } @entitypairs;
    $log->debug(scalar(@contacts), ' (redundant) contacts');
    return unless @contacts;

    # Score the contacts first, without creating full Interaction objects yet
    _wtcontact($_) for @contacts;

    # Get top N contacts, without duplicating contacts from same cluster
    my @toprepcontacts = _top_by_cluster(\@contacts, $ops{'top'});

    # Convert contact to SBG::Interaction, including original Blast hits
    my @interactions = map { _contact2interaction($_) } @toprepcontacts;

    $log->debug(scalar(@interactions), " (clustered) interactions ($seq0,$seq1)");
    return @interactions;

} # search


# For a single hit pair [$hit0,$hit1], returns list of entity pairs:
# ([$entity0,$entity1],[$entity0,$entity1],...)
sub _hitp2entityp {
    my ($hitp, $ops, $seq0, $seq1) = @_;
    # Each hit may match multiple entities
    my @entities0 = SBG::DB::entity::query_hit($hitp->[0], %$ops);
    my @entities1 = SBG::DB::entity::query_hit($hitp->[1], %$ops);
    # Save original input sequence
    $_->{'input'} = $seq0 for @entities0;
    $_->{'input'} = $seq1 for @entities1;

    # Store backreference to source hit in resulting entity
    # Already done by DB::entity::query_hit
#     map { $_->{'hit'} = $hitp->[0] } @entities0;
#     map { $_->{'hit'} = $hitp->[1] } @entities1;

    # All combos of something from @entities0 with something from @entities1
    my @entitypairs = 
        SBG::U::List::pairs2(\@entities0, \@entities1, 'noself'=>1);

    return @entitypairs;
}


# Add a 'weight' field to a contact
sub _wtcontact {
    my ($contact) = @_;

    my $hsp1 = $contact->{'entity1'}{'hit'}->hsp;
    my $hsp2 = $contact->{'entity2'}{'hit'}->hsp;

    my ($wtnres, $wtcons) = (.1, .9);
    # Scale to 100 (assuming max interface size of 1000
    my $avg_nres = ($contact->{'n_res1'} + $contact->{'n_res2'}) / 2.0 / 10.0;
    my $avg_seqid = 100 * ($hsp1->frac_identical+$hsp2->frac_identical) / 2.0;
    my $avg_seqcons = 100 * ($hsp1->frac_conserved+$hsp2->frac_conserved) / 2.0;

    # TODO use SBG::U::List::wtavg
    my $score = 100 * 
        ($wtnres*$avg_nres+$wtcons*$avg_seqcons) / 
        ($wtnres*100 + $wtcons*100);

    $contact->{'weight'} = $score;
    return $contact;
}


# Get top contacts, per cluster,
# Take only the top N, when specified
sub _top_by_cluster {
    my ($contacts, $topn) = @_;


    # Group by cluster membership
    my %by_cluster;
    foreach my $contact (@$contacts) {
        # Singletons have no cluster, just stringify the object's address
        # NB cannot use the entity IDs to make this unique as two entities may
        # have multiple contacts
        my $cluster = $contact->{'cluster'} || refaddr $contact;
        $by_cluster{$cluster} ||= [];
        $by_cluster{$cluster}->push($contact);
    }


    # Get top 1 contact, per cluster
    my %top_of_cluster;
    foreach my $cluster (keys %by_cluster) {
        # Reverse key sort, by weight of all contacts in this cluster, top 1
        $top_of_cluster{$cluster} = 
            rnkeyhead { $_->{'weight'} } $by_cluster{$cluster}->flatten;
    }


    # The top N over all the best-per-cluster
    my @topn;
    if ($topn) {
        # This is the top N, but they are unsorted
        @topn = rnkeytop { $_->{'weight'} } $topn => values %top_of_cluster;
    } else {
        # Take the 1 best contact from every single cluster, unsorted
        @topn = values %top_of_cluster;
    }
    return @topn;

} # _top_by_cluster


# A contact contains the contacting entity IDs
# The entity2hit then maps back to the source blast hits
sub _contact2interaction {
    my ($contact) = @_;

    my ($entity1, $entity2) = ($contact->{'entity1'}, $contact->{'entity2'});
    # Add length of interface to each model: n_res
    my $model1 = _model($contact->{'entity1'}, $contact->{'n_res1'});
    my $model2 = _model($contact->{'entity2'}, $contact->{'n_res2'});

    my $iaction = SBG::Interaction->new;
    map { $iaction->set($_->query, $_) } ($model1, $model2);

    $iaction->avg_scores(
        qw/evalue frac_identical frac_conserved seqid gaps length n_res/);
    # Measure conservation along interface
    my $interface_conserved = 
        $iaction->scores->at('avg_frac_conserved') * 
        $iaction->scores->at('avg_n_res');
    $iaction->scores->put('interface_conserved', $interface_conserved);
    $iaction->weight($contact->{'weight'});

    return $iaction;

} # _contact2interaction


sub _model {
    my ($entity, $n_res) = @_;

    my $hsp = $entity->{'hit'}->hsp;
    my $scores = _hspscores($hsp);
    # Add length of interface to each model
    $scores->put('n_res', $n_res);

    my $dom = SBG::DB::entity::id2dom($entity->{'id'});
    my $model = SBG::Model->new(
        query=>$hsp->seq,
        subject=>$dom,
        scores=>$scores,
        input=>$entity->{'input'},
        );
    # Burry the HSP in the model too, to get the alignment back out
    $model->aln($hsp->get_aln());
    return $model;
}


sub _hspscores {
    my ($hsp) = @_;
    my $scores = {
        evalue => $hsp->evalue,
        frac_identical => $hsp->frac_identical,
        frac_conserved => $hsp->frac_conserved,
        seqid => 100.0 * $hsp->frac_identical,
        gaps => $hsp->gaps,
        length => $hsp->length,
    };
    return $scores;
}



__PACKAGE__->meta->make_immutable;
no Moose;
1;


