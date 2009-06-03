#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Domain;
use SBG::Types;

$x = SBG::Domain::create("SBG::Domain");
print "ref:", ref($x), "\n";
$y = SBG::Domain::create("SBG::Domain::CofM");
print "ref:", ref($y), "\n";

__END__

$d = new_ok(SBG::Domain);


# NB You need to split off ChainID, cannot be in PDB ID
ok(! eval { $d->pdbid('3didA') }, "Catching invalid PDB ID");
ok(! eval { $d->pdbid('didi') }, "Catching invalid PDB ID");

# Default descriptor ALL
$d = new_ok 'SBG::Domain';
is($d->descriptor, 'ALL', "Default descriptor 'ALL'");

# Setting descriptor cleans it up, even from constructor
$desc = 'CHAIN     A';
$d = new SBG::Domain(descriptor=>$desc);
is($d->descriptor, 'CHAIN A', 'Constructor cleans up descriptor');

# Basic checks
$dom = new SBG::Domain(pdbid=>'2nn6', descriptor=>'CHAIN A');
is($dom->pdbid, '2nn6', 'pdbid');
is($dom->descriptor, 'CHAIN A', 'descriptor');
is($dom->wholechain, 'A', 'wholechain');
ok($dom->continuous);

$dom->descriptor('A 10 _ to A 233 _');
ok($dom->continuous);
ok(! $dom->wholechain);

$equiv = new SBG::Domain(pdbid=>'2nn6', descriptor=>'A 10 _ to A 233 _');
ok($equiv == $dom);

# Multi-segment descriptor

$dom = new SBG::Domain(pdbid=>'1xyz', 
                       descriptor=>'A 3 _ to A 189 _ A 353 _ to A 432 _');

__END__



