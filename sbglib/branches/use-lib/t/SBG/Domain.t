#!/usr/bin/env perl

# use strict;
use warnings;

use Test::More 'no_plan';
use SBG::Domain;
use SBG::Types;
use Data::Dump qw/dump/;

use Moose::Autobox;

my $d = new_ok('SBG::Domain');

# NB You need to split off ChainID, cannot be in PDB ID
ok(! eval { $d->pdbid('3didA') }, "Catching invalid PDB ID");
ok(! eval { $d->pdbid('didi') }, "Catching invalid PDB ID");

$d = new SBG::Domain(pdbid=>'2NN6');
is($d->pdbid, '2nn6', "PDBID to lowercase");


# Default descriptor ALL
$d = new_ok 'SBG::Domain';
is($d->descriptor, 'ALL', "Default descriptor 'ALL'");


# Setting descriptor cleans it up, even from constructor
my $desc = 'CHAIN     A';
$d = new SBG::Domain(descriptor=>$desc);
is($d->descriptor, 'CHAIN A', 'Constructor cleans up descriptor');


# Basic checks
my $dom = new SBG::Domain(pdbid=>'2nn6', descriptor=>'CHAIN A');
is($dom->pdbid, '2nn6', 'pdbid');
is($dom->descriptor, 'CHAIN A', 'descriptor()');
is($dom->wholechain, 'A', 'wholechain()');
$dom->descriptor('A 10 _ to A 233 _');
ok(! $dom->wholechain, '! wholechain()');


# Equality
my $equiv = new SBG::Domain(pdbid=>'2nn6', descriptor=>'A 10 _ to A 233 _');
ok($equiv == $dom, 'equals');


# Multi-segment descriptor
$dom = new SBG::Domain(pdbid=>'1xyz', 
                       descriptor=>'A 3 _ to A 189 _ A 353 _ to A 432 _');


$TODO = "test cumulative transform";
# Validate that the raw cofm times the cumulative transform is the cum. cofm
# But still, should maintain current cofm, for sake of overlap detection
ok 0;


$TODO = "test with residue insertion codes in descriptor";
ok 0;

