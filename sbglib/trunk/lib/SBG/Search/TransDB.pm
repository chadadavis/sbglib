#!/usr/bin/env perl

=head1 NAME

SBG::Search::TransDB - 

=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::SearchI> , L<SBG::Interaction> 

=cut

################################################################################

package SBG::Search::TransDB;
use Moose;
with 'SBG::SearchI';

use Moose::Autobox;
use Algorithm::Cluster qw/treecluster/;
use List::Util qw/min max sum/;

use SBG::Run::PairedBlast;
use SBG::Model;
use SBG::Domain;
use SBG::Interaction;
use SBG::U::Log qw/log/;

# TransDB lookups
use SBG::DB::entity;
use SBG::DB::contact;
use SBG::DB::irmsd;
use SBG::DB::res_mapping;


has 'blast' => (
    is => 'ro',
    isa => 'SBG::Run::PairedBlast',
    default => sub { SBG::Run::PairedBlast->new() },
    );


################################################################################
=head2 search

 Function: 
 Example : 
 Returns : Array of <SBG::Interaction>
 Args    : Two L<Bio::Seq>s
           
TODO options to exclude (list of) PDBIDs

=cut
sub search {
    my ($self, $seq1, $seq2, %ops) = @_;

    my @hitpairs = $self->blast->search($seq1, $seq2, %ops);
    $ops{overlap} ||= 0.50;
    my $entityops = {%ops}->hslice([qw/overlap/]);
    # Foreach hit pair, lookup matching structures in entity table, 1-to-many
    my %allentitypairs;
    my %entity2hit;
    foreach my $hitpair (@hitpairs) {
        my ($hit1, $hit2) = @$hitpair;

        my @entities1 = SBG::DB::entity::query_hit($hit1,%$entityops);
        my @entities2 = SBG::DB::entity::query_hit($hit2,%$entityops);
        my @entitypairs = SBG::U::List::pairs2(\@entities1, \@entities2);
        # Make unique (s.t. no entity interacting with itself)
        @entitypairs = grep {my($a,$b)=@$_;$a->{id}!=$b->{id}} @entitypairs;
        # Maintain a reverse map, entitypair back to hitpair
        foreach my $epair (@entitypairs) {
            my ($e1, $e2) = @$epair;
            my $epairid = $e1->{id} . '--' . $e2->{id};
            $entity2hit{$epairid} ||= $hitpair;
            # There will be duplicates, hash them to get unique keys
            $allentitypairs{$epairid} ||= $epair;
        }
    }
    log()->trace(scalar keys %allentitypairs, ' entity pairs');

    # Each pair of entities may find multiple contacts, again 1-to-many
    my @contacts = map { SBG::DB::contact::query(@$_) } values %allentitypairs;
    log()->trace(scalar(@contacts), ' contacts');
    return unless @contacts;

    # Cluster contacts, based on iRMSD distance matrix
    my ($distmat, $unique) = _distmat(\@contacts);
    # If clustering doesn't work, use all contacts
    my @repcontacts = @contacts;
    # Cluster if a distance matrix produced
    if ($distmat) {
        # Cluster the distance matrix. ArrayRef contains cluster ID membership
        my $clusters = _cluster($distmat, $unique);
        # Representative contact for each cluster of contacts, arbitrary
        @repcontacts = _representative($clusters, \@contacts);

    }

    # Convert contact to SBG::Interaction, including original Blast hits
    my @interactions = map {_contact2interaction($_,\%entity2hit)} @repcontacts;

    if (my $topn = $ops{'top'}) {
        # Take top N interactions
        # avg_frac_convserved * avg_n_res : measures total conservation at iface
        @interactions = sort {
            $b->scores->at('interface_conserved') <=> 
                $a->scores->at('interface_conserved')
        } @interactions;
        # Delete rest
        delete $interactions[$_] for $topn..$#interactions;
    }
    log()->trace(scalar(@interactions), " interactions ($seq1,$seq2)");
    return @interactions;

} # search


# Given an array of memberships, choose a (the first) member for each cluster
sub _representative {
    my ($clusters, $contacts) = @_;
    my %reps;
    for (my $i = 0; $i < @$clusters; $i++) {
        my $cluster = $clusters->[$i];
        $reps{$cluster} = $contacts->[$i] unless defined $reps{$cluster};
    }
    return values %reps;
}


# Returns ArrayRef of cluster membership, given (lower-diagonal) distance matrix
# http://en.wikipedia.org/wiki/Determining_the_number_of_clusters_in_a_data_set
sub _cluster {
    my ($distmat, $unique) = @_;

    # method=>
    # s: pairwise single-linkage clustering
    # m: pairwise maximum- (or complete-) linkage clustering
    # a: pairwise average-linkage clustering
    my ($tree) = treecluster(data=>$distmat, method=>'a');

    # $unique elements cannot be clustered, determine the ideal N for the rest
    my $n = @$distmat;
    my $rest = $n - $unique;
    my $iclusters = int sqrt ($rest/2);
    my $nclusters = min($n, $iclusters + $unique);
    log()->debug("$nclusters (min($n,$iclusters+$unique)) clusters");
    # Add clusters back in for the unique objects, but dont't exceed $n

    my ($clusters) = $tree->cut($nclusters);
    return $clusters;
}


# Lookup in irmsd table to get (lower-diagonal) distance matrix between contacts
sub _distmat {
    my ($contacts) = @_;

    my $distmat = [];
    my $nqueries = @$contacts * (@$contacts-1) / 2;
    log()->trace("$nqueries queries on irmsd table ...");
    return unless $nqueries > 0;

    # Count of measurable iRMSDs, by contact
    my @similarities = (0) x @$contacts; 

    for (my $i = 0; $i < @$contacts; $i++) {
        $distmat->[$i] ||= [];

        for (my $j = $i+1; $j < @$contacts; $j++) {
            # Column-major order, to produce a lower-diagonal distance matrix
            my $irmsd = SBG::DB::irmsd::query($contacts->[$i],$contacts->[$j]);
            $distmat->[$j][$i] = $irmsd || 'Inf';

            if (defined $irmsd) {
                $similarities[$i]++;
                $similarities[$j]++;
            }
        }
    }
    my $similar = grep { $_ } @similarities;
    my $sum = sum @similarities;
    log()->debug("$similar (of ",scalar(@$contacts), 
                 ") contacts have $sum iRMSDs < Inf");
    # This many contacts have no measurable similarity
    my $unique = @$contacts - $similar;
    return wantarray ? ($distmat, $unique) : $distmat;
}


# A contact contains the contacting entity IDs
# The entity2hit then maps back to the source blast hits
sub _contact2interaction {
    my ($contact, $entity2hit) = @_;
    my $id1 = $contact->{id_entity1};
    my $id2 = $contact->{id_entity2};
    my $epairid = "$id1--$id2";
    my ($hit1, $hit2) = @{$entity2hit->{$epairid}};

    # Add length of interface to each model: n_res
    my $model1 = _model($id1, $hit1, $contact->at('n_res1'));
    my $model2 = _model($id2, $hit2, $contact->at('n_res2'));

    # Save interaction-specific scores in the interaction template
    my $ia_scores = _avgscores($model1->scores, $model2->scores);
    # Measure conservation along interface
    $ia_scores->put(
        'interface_conserved', 
        $ia_scores->at('avg_frac_conserved') * $ia_scores->at('avg_n_res'));

    my $iaction = SBG::Interaction->new(
        models=>{$model1->query => $model1, $model2->query => $model2},
        scores=>$ia_scores,
        # Preferred score for weighting interations
        -weight=>$ia_scores->at('interface_conserved'),
        );
    return unless $iaction;
    return $iaction;

} # _contact2interaction


sub _model {
    my ($id, $hit, $n_res) = @_;
    my $hsp = $hit->hsp;
    my $seq = $hsp->seq;
    my $scores = _hspscores($hsp);
    # Add length of interface to each model
    $scores->put('n_res', $n_res);
    my $dom = SBG::DB::entity::id2dom($id);
    my $model = SBG::Model->new(query=>$seq,subject=>$dom,scores=>$scores);
    return $model;
}


sub _avgscores {
    my ($s1, $s2) = @_;
    my $avg = {};
    foreach (qw/evalue frac_identical frac_conserved seqid gaps length n_res/) {
        $avg->put("avg_$_", ($s1->at($_) + $s2->at($_)) / 2.0);
    }

    return $avg;
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


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


