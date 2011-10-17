#!/usr/bin/env perl

=head1 NAME

SBG::Search::PairedBlast - 

=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::SearchI> , L<SBG::Interaction> 

=cut

package SBG::Search::PairedBlast;
use Moose;
with 'SBG::SearchI';

use Moose::Autobox;
use Algorithm::Cluster qw/treecluster/;
use List::Util qw/min max sum/;
use Log::Any qw/$log/;

use SBG::Run::PairedBlast;
use SBG::Model;
use SBG::Domain;
use SBG::Interaction;

# TransDB lookups
use SBG::DB::entity;
use SBG::DB::contact;
use SBG::DB::irmsd;
use SBG::DB::res_mapping;

has 'blast' => (
    is      => 'ro',
    isa     => 'SBG::Run::PairedBlast',
    default => sub { SBG::Run::PairedBlast->new() },
);

=head2 search

 Function: 
 Example : 
 Returns : Array of <SBG::Interaction>
 Args    : Two L<Bio::Seq>s
           
TODO options to exclude PDBID(s)

=cut

sub search {
    my ($self, $seq1, $seq2, %ops) = @_;

    my @hitpairs = $self->blast->search($seq1, $seq2, %ops);

    my @interactions;
    foreach my $hitpair (@hitpairs) {
        my ($hit1, $hit2) = @$hitpair;
        my $iaction = _contact2interaction($hit1, $hit2);
        push @interactions, $iaction if defined $iaction;
    }

    return @interactions;

}    # search

sub cluster {
    my ($self, $net) = @_;

    # Interaction hahed by PDBID
    my $interactions = {};
    foreach my $iaction ($net->interactions) {
        my $pdbid = $iaction->domains->head->pdbid;
        $interactions->{$pdbid} ||= [];
        $interactions->{$pdbid}->push($iaction);
    }

    my $sublen = sub { $interactions->{shift}->length };

    # Sort by number of interactions for a given PDB
    my $keys =
        $interactions->keys->sort(sub { $sublen->($b) <=> $sublen->($a) });
    foreach my $key ($keys->flatten) {
        $log->debug("$key: ", $sublen->($key));
    }
    return $net;

}

sub build {
    my ($self, $net) = @_;
    return $net;
}

# Create an interaction from Blast Hits
sub _contact2interaction {
    my ($hit1, $hit2) = @_;

    my $model1 = _model($hit1);
    my $model2 = _model($hit2);
    return unless defined $model1 && defined $model2;

    # TODO Add length of interface to each model
    # TODO determine this from Qcons
    #     $model1->scores->put('n_res', $n_res1);
    #     $model2->scores->put('n_res', $n_res2);

    # Save interaction-specific scores in the interaction template
    my $ia_scores = _avgscores($model1->scores, $model2->scores);

    my $iaction = SBG::Interaction->new();
    $iaction->set($model1->query => $model1);
    $iaction->set($model2->query => $model2);

    # Measure conservation along interface
    # TODO This is 0, as long as n_res is missing from Interaction
    #     $ia_scores->put(
    #         'interface_conserved',
    #         $ia_scores->at('avg_frac_conserved') * $ia_scores->at('avg_n_res'));

    $iaction->scores($ia_scores);

    #     $iaction->weight($ia_scores->at('interface_conserved');

    return unless $iaction;
    return $iaction;

}    # _contact2interaction

sub _model {
    my ($hit)  = @_;
    my $hsp    = $hit->hsp;
    my $seq    = $hsp->seq;
    my $scores = _hspscores($hsp);

    $log->debug("hitname ", $hit->name);
    my ($pdb, $chain) = SBG::Run::PairedBlast::gi2pdbid($hit->name);
    unless (defined $pdb && defined $chain) {
        $log->error("Could not extract PDB ID/Chain ID from: ", $hit->name);
        return;
    }

    # TODO map blast coords to residue IDs, for descriptor,
    # these coords only approx, completely wrong in some cases
    my ($start, $end) = ($hsp->subject->start, $hsp->subject->end);

    my $dom = SBG::Domain->new(
        pdbid      => $pdb,
        descriptor => "$chain $start _ to $chain $end _",
    );

    my $model =
        SBG::Model->new(query => $seq, subject => $dom, scores => $scores);
    return $model;
}

sub _avgscores {
    my ($s1, $s2) = @_;
    my $avg = {};

    # TODO add n_res in once interface determined
    #     foreach (qw/evalue frac_identical frac_conserved seqid gaps length n_res/) {
    foreach (qw/evalue frac_identical frac_conserved seqid gaps length/) {
        $avg->put("avg_$_", ($s1->at($_) + $s2->at($_)) / 2.0);
    }

    return $avg;
}

sub _hspscores {
    my ($hsp) = @_;
    my $scores = {
        evalue         => $hsp->evalue,
        frac_identical => $hsp->frac_identical,
        frac_conserved => $hsp->frac_conserved,
        seqid          => 100.0 * $hsp->frac_identical,
        gaps           => $hsp->gaps,
        length         => $hsp->length,
    };
    return $scores;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

