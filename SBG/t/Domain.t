#!/usr/bin/env perl

use Test::More 'no_plan';
use feature 'say';

use SBG::Domain;
use SBG::Types;
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
is($dom->pdbid, '2nn6');
is($dom->descriptor, 'CHAIN A');
is($dom->fromchain, 'A');
ok($dom->wholechain);
ok($dom->continuous);

$dom->descriptor('A 10 _ to A 233 _');
is($dom->fromchain, 'A');
ok($dom->continuous);
ok(! $dom->wholechain);

$equiv = new SBG::Domain(pdbid=>'2nn6', descriptor=>'A 10 _ to A 233 _');
ok($equiv == $dom);


__END__



