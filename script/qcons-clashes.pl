#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp;
use Carp;
use Moose::Autobox;
use autobox::List::Util;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use SBG::Debug;

use Bio::Tools::Run::QCons;

my $file = shift or die;

my $q = Bio::Tools::Run::QCons->new(
    file   => "$Bin/SBG/data/docking1.pdb",
    chains => [ 'A', 'B' ],
);
my $contacts = $q->residue_contacts;
print Dumper $contacts;
my $contacts1 = {};
my $contacts2 = {};
foreach my $c (@$contacts) {
    my $c1 = $c->{res1}->slice([qw/name number/])->join('');
    my $c2 = $c->{res2}->slice([qw/name number/])->join('');
    $contacts1->{$c1} ||= [];
    $contacts2->{$c2} ||= [];
    $contacts1->{$c1}->push($c2);
    $contacts2->{$c2}->push($c1);
}

print Dumper $contacts1;

# How many contacts from an atom in 1st chain
my $n_atoms1 = $contacts1->values->map(sub { $_->length })->sum();

# How many residues of 1st chain have >= 1 contact
my $n_res1 = $contacts1->values->length;
my $n_res2 = $contacts2->values->length;

print "n_atoms1:$n_atoms1:\n";
print "n_res1:$n_res1:\n";
print "n_res2:$n_res2:\n";

#print Dumper $contacts2;

done_testing();
