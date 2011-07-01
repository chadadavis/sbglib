#!/usr/bin/env perl

package Test::SBG::DomainIO::cofm;
use strict;
# Inheritance
use base qw/Test::SBG/;
# Just 'use' it to import all the testing functions and symbols 
use Test::SBG; 

use SBG::DomainIO::cofm;
use Moose::Autobox;

sub multi_domain : Tests {
    my ($self) = @_;
    my $file = 'cofm-verbose.cofm';
    my $path = catfile $self->{test_data}, $file;
    ok -e $path or die "Can't read $path";
    my $io = SBG::DomainIO::cofm->new(file=>$path);
    my $doms = [];
    while (my $dom=$io->read) { $doms->push($dom) };
    is($doms->length, 2) or die "No domains in $file";
    is $doms->[0]->length, 492;
    is $doms->[1]->length, 293;
}


sub multi_fragment : Tests {
    my ($self) = @_;
    my $file = 'cofm-multi.cofm';
    my $path = catfile $self->{test_data}, $file;
    ok -e $path or die "Can't read $path";
    my $io = SBG::DomainIO::cofm->new(file=>$path);
    my $doms = [];
    while (my $dom=$io->read) { $doms->push($dom) };
    is($doms->length, 1) or die "No domains in $file";
    my $dom = $doms->[0];
    is $dom->length, 251;
    ok ! $dom->transformation->has_matrix;
    ok -e $dom->file;
    my $rad = $dom->radius;
    is_approx 39.1, $rad, "radius (39.1 ~(1%) $rad)", '1%';
}


sub classification : Test {
    local $TODO = "TODO test reading / writing the 'Classifiation'";
}


sub renumber_chains : Test() {
    local $TODO = "TODO test renumber_chains";
}


1;
