#!/usr/bin/env perl

# use strict;
use warnings;

use Test::More 'no_plan';
use Data::Dump qw/dump/;
use Moose::Autobox;

use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";

use SBG::Domain;
use SBG::Types;


my $dom = new_ok('SBG::Domain');

# NB You need to split off ChainID, cannot be in PDB ID
ok(! eval { $dom->pdbid('3didA') }, "Catching invalid PDB ID");
ok(! eval { $dom->pdbid('didi') }, "Catching invalid PDB ID");

# No longer used, since we now allow uppercase as well
# $dom = SBG::Domain->new(pdbid=>'2NN6');
# is($dom->pdbid, '2nn6', "PDBID to lowercase");


# Default descriptor ALL
$dom = new_ok 'SBG::Domain';
is($dom->descriptor, 'ALL', "Default descriptor 'ALL'");


# Setting descriptor cleans it up, even from constructor
my $desc = 'CHAIN     A';
#$dom = new SBG::Domain(descriptor=>$desc);
#is($dom->descriptor, 'CHAIN A', 'Constructor cleans up descriptor');


# Convert double chain ID to lcase
$dom = SBG::Domain->new(pdbid=>'317d', descriptor=>'CHAIN AA');
is($dom->descriptor, 'CHAIN a', 'Double-char chain IDs coverted to lcase');
$dom = SBG::Domain->new(pdbid=>'317d', descriptor=>'AA 3 _ to AA 154 _');
is($dom->id, '317da3_a154_', 'Double-char chain IDs coverted to lcase');


# Find file when given PDB without an assembly
ok($dom->file && -f $dom->file, 'Finding file:' . $dom->file);

# Find obsolete PDB entry
$dom = SBG::Domain->new(pdbid=>'2z8t');
ok($dom->file && -f $dom->file, 'Finding file for obsolete:' . $dom->file);

# Find file when given PDB with an assembly
$dom = SBG::Domain->new(pdbid=>'1tim', assembly=>1, model=>1);
ok($dom->file && -f $dom->file, 'Finding file for assembly+model:' . $dom->file);


# Basic checks
$dom = SBG::Domain->new(pdbid=>'2nn6', descriptor=>'CHAIN A');
is($dom->pdbid, '2nn6', 'pdbid');
is($dom->descriptor, 'CHAIN A', 'descriptor()');
is($dom->wholechain, 'A', 'wholechain()');
$dom->descriptor('A 10 _ to A 233 _');
ok(! $dom->wholechain, '! wholechain()');
# Equality
my $equiv = SBG::Domain->new(pdbid=>'2nn6', descriptor=>'A 10 _ to A 233 _');
ok($equiv == $dom, 'equals');


# Assemblies from Biounit
$dom = SBG::Domain->new(pdbid=>'317d', assembly=>1, model=>1);
is($dom->id, '317d-1-1-ALL', 'Assembly/model in id()');
# File is set, and exists
ok($dom->file && -f $dom->file, "Autofind PDB assembly: " . $dom->file); 


# Inequality of different assemblies/models
my $ass2_1_a = SBG::Domain->new(pdbid=>'3bct', assembly=>2, model=>1);
my $ass2_2_a = SBG::Domain->new(pdbid=>'3bct', assembly=>2, model=>2);
isnt($ass2_1_a, $ass2_2_a, 'inequality of biounit models');

# Multi-segment descriptor
$dom = SBG::Domain->new(pdbid=>'1xyz', 
                       descriptor=>'A 3 _ to A 189 _ A 353 _ to A 432 _');
$TODO = "Test multi-segment descriptor";
ok(0);

$TODO = "Test lenght()";
ok(0);


$TODO = "test cumulative transform";
# Validate that the raw cofm times the cumulative transform is the cum. cofm
# But still, should maintain current cofm, for sake of overlap detection
ok 0;


