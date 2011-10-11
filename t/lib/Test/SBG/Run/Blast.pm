#!/usr/bin/env perl
package Test::SBG::Run::Blast;
use base qw(Test::SBG);
use Test::SBG::Tools;

use Bio::SeqIO;
use Devel::Comments;

sub setup : Tests(setup) {
    my ($self) = @_;
    my $blast = SBG::Run::Blast->new;
    $self->{blast} = $blast;
}

sub basic : Tests {
    my ($self) = @_;

    my $io = Bio::SeqIO->new(-file => $self->{test_data} . '/P25359.fa');
    my $seq = $io->next_seq;

    my $blast = SBG::Run::Blast->new(
        method   => 'standaloneblast',
        e        => 0.01,
        database => 'pdbaa'
    );
    my $test_id = '2NN6';
    my $hits    = $blast->search([$seq]);

    my $nhits   = @$hits;
    ok($nhits > 0, "Blast -e bug workaround: RRP43 hits on $test_id: $nhits");

}


