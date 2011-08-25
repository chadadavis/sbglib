#!/usr/bin/env perl

package Test::SBG::DomainIO::cofm;
use base 'Test::SBG';
use Test::SBG::Tools;

use Moose::Autobox;

sub multi_domain : Tests {
    my ($self) = @_;
    my $file = 'cofm-verbose.cofm';
    my $path = file $self->{test_data}, $file;
    ok -e $path or die "Can't read $path";
    my $io = SBG::DomainIO::cofm->new(file => "$path");
    my $doms = [];
    while (my $dom = $io->read) { $doms->push($dom) }
    is($doms->length, 2) or die "No domains in $file";
    is $doms->[0]->length, 492;
    is $doms->[1]->length, 293;
}

sub multi_fragment : Tests {
    my ($self) = @_;
    my $file = 'cofm-multi.cofm';
    my $path = file $self->{test_data}, $file;
    ok -e $path or die "Can't read $path";
    my $io = SBG::DomainIO::cofm->new(file => "$path");
    my $doms = [];
    while (my $dom = $io->read) { $doms->push($dom) }
    is($doms->length, 1) or die "No domains in $file";
    my $dom = $doms->[0];
    is $dom->length, 251;
    ok !$dom->transformation->has_matrix;
    ok -e $dom->file;
    my $rad = $dom->radius;
    is_approx 39.1, $rad, "radius (39.1 ~(1%) $rad)", '1%';
}

sub all_single : Test {
    local $TODO = "TODO test 'ALL' residues in a structure with single chain";
}

sub all_multi : Test {
    local $TODO =
        "TODO test 'ALL' residues in a structure with multiple chains";
}

sub classification : Test {
    local $TODO = "TODO test reading / writing the 'Classifiation'";
}

sub renumber_chains : Test() {
    local $TODO = "TODO test renumber_chains";
}

1;
