#!/usr/bin/env perl

use Graph::UnionFind;

use Bio::Network::Node;
use Bio::Seq;

use lib "..";
use EMBL::Node;
use EMBL::Seq;

use Data::Dumper;

my $uf = new Graph::UnionFind();

my $seqa = new Bio::Seq(-accession_number=>"a");
my $seqb = new Bio::Seq(-accession_number=>"b");

print STDERR "seq equal: ", $seqa eq $seqb, "\n";

my $a = new Bio::Network::Node(-protein => $seqa);
my $b = new Bio::Network::Node(-protein => $seqb);

print STDERR "nodes equal $a $b: ", $a eq $b, "\n";

$uf->add($a);
$uf->add($b);
# print Dumper($uf), "\n";
print STDERR "uf->same $a $b: ", $uf->same($a, $b), "\n";
$uf->union($a,$b);
print STDERR "uf->union,same $a $b: ", $uf->same($a, $b), "\n";

# use Test::Deep::NoTest;

# print cmp_deeply($a->proteins, $b->proteins, "some name");


