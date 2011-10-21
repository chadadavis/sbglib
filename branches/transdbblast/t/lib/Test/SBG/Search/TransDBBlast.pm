#!/usr/bin/env perl
package Test::SBG::Search::TransDBBlast;
use base qw(Test::SBG);
use Test::SBG::Tools;


use SBG::Node;
use SBG::Network;
use SBG::Run::PairedBlast;
use SBG::Search::TransDBc;
use Bio::SeqIO;

1;
__END__

sub setup : Test(setup) {
    my ($self) = @_;
    $self->{net} = $net;
    $self->{searcher} = 
}

sub pair : Tests {
    local $TODO = '';
    ok 0;
}

sub list : Tests {
    local $TODO = '';
    ok 0;
}

sub net : Tests {
    my ($self) = @_;

    my $net = SBG::Network->new;
    my $fasta_file = $self->{test_data} . '/1g3n.fa';
    my $seqio = Bio::SeqIO->new(-file => $fasta_file);
    while (my $seq = $seqio->next_seq) {
        $net->add_node(SBG::Node->new($seq));
    }
    $net = $net->build(SBG::Search::TransDBBlast->new);

    # Potential interactions, between pairs of proteins
    cmp_ok scalar($net->edges), '>', 0;

    # Potential *types* of interactions, between all interacting pairs
    # An edge may have multiple interactions
    cmp_ok scalar($net->interactions), '>', 0;

}

