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
           limit number of Blast hit pairs to consder (default: 0 => no limit)


=cut
sub search {
    my ($self, $seq1, $seq2, $limit, $nocache) = @_;

    my @hitpairs = $self->blast->search($seq1, $seq2, $limit, $nocache);

    # Foreach hit pair, lookup matching structures in entity table, 1-to-many
    my @allentitypairs;
    my %entity2hit;
    foreach my $hitpair (@hitpairs) {
        my ($hit1, $hit2) = @$hitpair;
        my @entities1 = SBG::DB::entity::query_hit($hit1,overlap=>0,);
        my @entities2 = SBG::DB::entity::query_hit($hit2,overlap=>0,);
        my @entitypairs = SBG::U::List::pairs2(\@entities1, \@entities2);
        # Make unique (s.t. no entity interacting with itself)
        @entitypairs = grep {my($a,$b)=@$_;$a->{id}!=$b->{id}} @entitypairs;
        # Maintain a reverse map, entitypair back to hitpair
        foreach my $epair (@entitypairs) {
            my ($e1, $e2) = @$epair;
            my $epairid = $e1->{id} . '--' . $e2->{id};
            $entity2hit{$epairid} = $hitpair;
        }
        push @allentitypairs, @entitypairs;
    }
    log()->trace(scalar(@allentitypairs), ' entity pairs');

    # Each pair of entities may find multiple contacts, again 1-to-many
    my @contacts = map { SBG::DB::contact::query(@$_) } @allentitypairs;
    log()->trace(scalar(@contacts), ' contacts');
    return unless @contacts;

    # Cluster contacts, based on iRMSD distance matrix
    my ($distmat, $unique) = _distmat(\@contacts);
    # Cluster the distance matrix. ArrayRef contains cluster ID membership
    my $clusters = _cluster($distmat, $unique);

    # Representative contact for each cluster of contacts, arbitrary
    my @repcontacts = _representative($clusters, \@contacts);

    # Convert contact to SBG::Interaction, including original Blast hits
    my @interactions = map {_contact2interaction($_,\%entity2hit)} @repcontacts;

    log()->trace(scalar(@interactions), " interactions ($seq1,$seq2)");
    return @interactions;

} # search


# Given an array of memberships, choose a (the first) member for each cluster
sub _representative {
    my ($clusters, $contacts) = @_;
    my %reps;
    for (my $i = 0; $i < @$clusters; $i++) {
        my $cluster = $clusters->[$i];
        $reps{$cluster} //= $contacts->[$i];
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

    my $nqueries = @$contacts * (@$contacts-1) / 2;
    log()->trace("$nqueries queries on irmsd table ...");
    my $distmat = [];
    # Count of measurable iRMSDs, by contact
    my @similarities = (0) x @$contacts; 

    for (my $i = 0; $i < @$contacts; $i++) {
        $distmat->[$i] ||= [];
        for (my $j = $i+1; $j < @$contacts; $j++) {
#             my $irmsd = SBG::DB::irmsd::query($contacts->[$i],$contacts->[$j]);
            my $irmsd = SBG::DB::irmsd::query($contacts->[$i],$contacts->[$j]);
            # Column-major order, to produce a lower-diagonal distance matrix
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
    my $hsp1 = $hit1->hsp;
    my $hsp2 = $hit2->hsp;
    my $seq1 = $hsp1->seq;
    my $seq2 = $hsp2->seq;

    my $scores1 = _hspscores($hsp1);
    my $scores2 = _hspscores($hsp2);

    my $dom1 = SBG::DB::entity::id2dom($id1);
    my $dom2 = SBG::DB::entity::id2dom($id2);

    my $model1 = new SBG::Model(query=>$seq1,subject=>$dom1,scores=>$scores1);
    my $model2 = new SBG::Model(query=>$seq2,subject=>$dom2,scores=>$scores2);

    # Save interaction-specific scores in the interaction template
    my $iaction = new SBG::Interaction(
        models=>{$seq1=>$model1, $seq2=>$model2},
        # Get these two scores from $contact HashRef as new HashRef
        scores=>$contact->hslice([qw/n_res1 n_res2/]),
        );
    return unless $iaction;
    return $iaction;

} # _contact2interaction


sub _hspscores {
    my ($hsp) = @_;
    my $scores = {
        evalue => $hsp->evalue,
        frac_identical => $hsp->frac_identical,
        frac_conserved => $hsp->frac_conserved,
        gaps => $hsp->gaps,
        length => $hsp->length,
    };
    return $scores;
}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


