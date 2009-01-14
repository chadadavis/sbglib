#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::Domain;
use SBG::Transform;
use SBG::CofM;

use PDL;
use PDL::Matrix;

# Label parsing
my $dom0;
my $id = '2br2A-RRP43_3'; 
$dom0 = new SBG::Domain(-label=>$id);
is('2br2', $dom0->pdbid, "Parsed pdbid");
is('A', $dom0->chainid, "Parsed chain");
is('RRP43', $dom0->label, "Parsed label");
is('2br2A-RRP43', $dom0->stampid, "Parsed stampid");
$dom0->label('2br2A');
is('2br2A', $dom0->stampid, "Parsed stampid without label");

# TODO Test parsing of double-char chain IDs


# new()
my $dom1 = new SBG::Domain();
$dom1->cofm(qw(-6.61  -32.62  -53.18));
isa_ok($dom1, "SBG::Domain");

# cofm()
# TODO update test based on new assumption: cofm not always defined
isa_ok($dom1->cofm, "PDL::Matrix");
is($dom1->cofm, mpdl (-6.61,-32.62,-53.18,1), 
   'Identity 3-tuple centre-of-mass, affine');
# transformation()
isa_ok($dom1->transformation, "SBG::Transform");
# Default transform is the identity transform
is_deeply($dom1->transformation, new SBG::Transform, 'Identity Tranform');

# _cofm2array()
my $dom2 = new SBG::Domain();
my @abc = qw(80.86   12.45  122.08);
my $p = mpdl (@abc,1);
$dom2->cofm($p);
my @a = $dom2->_cofm2array;
is_deeply(\@a, [@abc], 'cofm2array');

# rmsd()
my $toler = 0.1;
my $expectdiff = 200.99;
my $diff = $dom1-$dom2;
ok($diff < $expectdiff + $toler, "rmsd between centres");
ok($diff > $expectdiff - $toler, "rmsd between centres");

# overlap()
$dom1->rg(3);
$dom2->rg(5);
my $expectoverlap = 3+5-$expectdiff;
ok($dom1->overlap($dom2) < $expectoverlap + $toler, 'overlap between spheres');
ok($dom1->overlap($dom2) > $expectoverlap - $toler, 'overlap between spheres');

# overlaps()
my $delta = 0.01;
ok($dom1->overlaps($dom2, $expectoverlap-$delta), 
   'overlaps lower thresh');
ok(! $dom1->overlaps($dom2, $expectoverlap+$delta), 
   'overlaps not at upper thresh');

# label2pdbid()
my $dom3 = new SBG::Domain(-label=>'2nn6A');
is($dom3->pdbid, '2nn6', 'label2pdbid sets pdbid');
is($dom3->descriptor, 'CHAIN A', 'label2pdbid sets descriptor: CHAIN A');
$dom3->label('2nn6B');
isnt($dom3->descriptor, 'CHAIN B', 'label2pdbid doesnt reset descriptor');
$dom3->rg(3.3);

# Extracting PDB ID from file name
my $dom4 = new SBG::Domain(-file=>'./somewhere/pdb2nn6A.ent.gz');
is($dom4->pdbid, '2nn6', 'file2pdbid sets pdbid');
is($dom4->descriptor, 'CHAIN A', 'file2pdbid sets descriptor: CHAIN A');

# Test rmsd on real cofm's
my $dom5 = SBG::CofM::cofm('2br2', 'CHAIN A');
my $dom6 = SBG::CofM::cofm('2br2', 'CHAIN D');

my $rmsd = $dom5-$dom6;
my $o = $dom5->overlap($dom6);



# TODO test overlap result

# TODO test applying non-trivial transformation to CofM

# TODO test Storable


__END__


