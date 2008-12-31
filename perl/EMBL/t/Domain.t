#!/usr/bin/env perl

use Test::More 'no_plan';

use EMBL::Domain;
use EMBL::Transform;

use PDL;
use PDL::Matrix;

# new()
my $dom1 = new EMBL::Domain();
isa_ok($dom1, "EMBL::Domain");
# cofm()
isa_ok($dom1->cofm, "PDL::Matrix");
is($dom1->cofm, mpdl (0,0,0,1), 'Identity 3-tuple centre-of-mass, affine');
# transformation()
isa_ok($dom1->transformation, "EMBL::Transform");
is_deeply($dom1->transformation, new EMBL::Transform, 'Identity Tranform');

# cofm2array()
my $dom2 = new EMBL::Domain();
my @abc = (1,2,3);
my $p = mpdl (@abc,1);
$dom2->cofm($p);
my @a = $dom2->cofm2array;
is_deeply(\@a, [@abc], 'cofm2array');
# rmsd()
is($dom1-$dom2, 4+2/3, "rmsd between centres");
# overlap()
$dom1->rg(3);
$dom2->rg(5);
is($dom1->overlap($dom2), 3+1/3, 'overlap between spheres: 3+1/3');
# overlaps()
ok($dom1->overlaps($dom2, 3.3), 'overlaps at thresh 3.3');
ok(! $dom1->overlaps($dom2, 3.4), 'overlaps not at thresh 3.4');

# stampid2pdbid()
my $dom3 = new EMBL::Domain(-stampid=>'2nn6A');
$dom3->stampid2pdbid;
is($dom3->pdbid, '2nn6', 'stampid2pdbid sets pdbid');
is($dom3->descriptor, 'CHAIN A', 'stampid2pdbid sets descriptor: CHAIN A');
$dom3->stampid('2nn6B');
$dom3->stampid2pdbid;
isnt($dom3->descriptor, 'CHAIN B', 'stampid2pdbid doesnt reset descriptor');
$dom3->rg(3.3);
is("$dom3", "2nn6B 2nn6 0 0 0 3.3", "asstring");


TODO:{
    # TODO test applying non-trivial transformation to CofM
    my $dom4 = new EMBL::Domain;
    my $t = new EMBL::Transform;
    ok($dom4->transform($t), "EMBL::Domain::transform()");
    my $p = mpdl (0,0,0,1);
    is($dom4->cofm, $p, 'Identity transformation');
}

# TODO test Storable

__END__


