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

use Algorithm::Cluster qw/treecluster/;

use SBG::Run::PairedBlast;

use SBG::Model;
use SBG::Domain;
use SBG::Interaction;

# TransDB lookups
use SBG::DB::entity;
use SBG::DB::contact;
use SBG::DB::irmsd;
use SBG::DB::res_mapping;

use SBG::U::Log qw/log/;


################################################################################
=head2 search

 Function: 
 Example : 
 Returns : Array of <SBG::Interaction>
 Args    : Two L<Bio::Seq>s


=cut
sub search {
    my ($self, $seq1, $seq2) = @_;

    my $blast = SBG::Run::PairedBlast->new();
    my @hitpairs = $blast->search($seq1, $seq2);

    # For each pair of hits, lookup matching structure entities, 1-to-many
    my @entitypairs = map { hitpair2entitypair(@$_) } @hitpairs;
    log()->trace(scalar(@entitypairs), ' entity pairs');

    # Each pair of entities may find multiple contacts
    my @contacts = map { SBG::DB::contact::query(@$_) } @entitypairs;

    log()->trace(scalar(@contacts), ' contacts for Blast pair');

    # Cluster contacts, based on iRMSD distance
    my $distmat = _distmat(\@contacts);
    # Cluster the distance matrix. Array contains cluster ID membership
    my $clusters = _cluster($distmat);

    # Representative contact for each cluster
    my @repcontacts = _representative($clusters, \@contacts);

    # Convert contact to SBG::Interaction
    my @interactions = map {_contact2interaction($_,$seq1,$seq2)} @repcontacts;

    return @interactions;

} # search


sub _representative {
    my ($clusters, $contacts) = @_;
    my %reps;
    for (my $i = 0; $i < @$clusters; $i++) {
        my $cluster = $clusters->[$i];
        $reps{$cluster} = $contacts->[$i] unless defined $reps{$cluster};
    }
    return values %reps;
}

# Returns ArrayRef of cluster membership of @contacts
sub _cluster {
    my ($distmat) = @_;

    # method=>
    # s: pairwise single-linkage clustering
    # m: pairwise maximum- (or complete-) linkage clustering
    # a: pairwise average-linkage clustering
    my ($tree) = treecluster(data=>$distmat, method=>'a');

    # http://en.wikipedia.org/wiki/Determining_the_number_of_clusters_in_a_data_set
    my $nclusters = int sqrt (@$distmat/2);
    $nclusters ||= 1; # if only one member
    log()->debug("contacts:", scalar(@$distmat), " nclusters:$nclusters");
    my ($clusters) = $tree->cut($nclusters);
    return $clusters;
}


# Lookup irmsd field of irmsd table to get lower-diagonal distance matrix
# between contacts
sub _distmat {
    my ($contacts) = @_;
    log()->trace(scalar(@$contacts), ' contacts');
    my $nqueries = @$contacts * (@$contacts-1) / 2;
    log()->trace("Querying irmsd table ($nqueries times) for similarities");
    my $distmat = [];
    my $records = 0;
    for (my $i = 0; $i < @$contacts; $i++) {
        $distmat->[$i] ||= [];
        for (my $j = $i+1; $j < @$contacts; $j++) {
            my $irmsd = SBG::DB::irmsd::query($contacts->[$i],$contacts->[$j]);
            # Column-major order, to produce a lower-diagonal distance matrix
            $distmat->[$j][$i] = $irmsd || 'Inf';
            $records++ if defined $irmsd;
        }
    }
    log()->debug("$records of $nqueries distances found");
    return $distmat;
}


# 1-to-many, depending on sequence overlap required
sub hitpair2entitypair {
    my ($hit1, $hit2) = @_;
    # For each hit, collect database entities overlaping significantly
    # First query entities (may be multiple)
    # Entity needs to overlap significantly with my domain, though
    my @entities1 = SBG::DB::entity::query_hit($hit1,overlap=>0,);
    my @entities2 = SBG::DB::entity::query_hit($hit2,overlap=>0,);
    my @entitypairs = SBG::U::List::pairs2(\@entities1, \@entities2);
    return @entitypairs;
}


# TODO DES 
# The Hit contains the scores, but we no longer have the mapping back to hits
sub _contact2interaction {
    my ($contact, $seq1, $seq2) = @_;

    my $dom1 = SBG::DB::entity::id2dom($contact->{id_entity1});
    my $dom2 = SBG::DB::entity::id2dom($contact->{id_entity2});

    my $model1 = new SBG::Model(query=>$seq1,subject=>$dom1,
                                scores=>{});
    my $model2 = new SBG::Model(query=>$seq2,subject=>$dom2,
                                scores=>{});

    # Save interaction-specific scores in the interaction template
    my $iaction = new SBG::Interaction(
        models=>{$seq1=>$model1, $seq2=>$model2},
        scores=>{},
        );

    return $iaction;

}



################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


__END__

# TODO BUG handle undefined chains
# TODO BUG handle residues before beginning, and after end, of structure
sub _hit2domain {
    my ($hit) = @_;
    my ($pdbid,$chain) = _gi2pdbid($hit->name);
    my ($pdbseq0, $pdbseqn) = $hit->range('hit');

    my ($dstart, $dend) = 
        SBG::DB::res_mapping::query($pdbid, $chain, $pdbseq0, $pdbseqn);

    unless ($dstart && $dend) {
        log()->warn("Couldn't find $pdbid $chain $pdbseq0-$pdbseqn");
        return;
    }

    my $descriptor = join(' ',
                          $chain, $dstart->{'resseq'}, $dstart->{'icode'}, 'to',
                          $chain, $dend->{'resseq'}, $dend->{'icode'});
    my $dom = new SBG::Domain(pdbid=>$pdbid, descriptor=>$descriptor);

    return $dom;

}


# Extract PDB ID and chain
sub _gi2pdbid {
    my ($gi) = @_;
    my ($pdbid, $chain) = $gi =~ /pdb\|(.{4})\|(.*)/;
    return unless $pdbid;
    return $pdbid unless $chain && wantarray;
    return $pdbid, $chain;

}
