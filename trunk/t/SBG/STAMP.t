#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";
use SBG::Debug qw(debug);

use Test::More;
use Test::SBG::PDL qw/pdl_approx/;

use File::Temp;
use Moose::Autobox;
use PDL;

use Test::Approx;
use SBG::STAMP qw/superposition/;
use SBG::Domain;
use SBG::DomainIO::pdb;
use SBG::DomainIO::stamp;

use SBG::Run::cofm qw/cofm/;
use SBG::Run::rasmol;


# Tolerate rounding differences between stamp (using clib) and PDL
my $toler = 0.5;

# One hexameric ring of 2br2: CHAINS ADCFEB
# (only unique interfaces: A/B and A/D) (B/D homologs, A/C homologs, etc)

# get domains for chains of interest
my $doma = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN A');
my $domb = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN B');
my $domd = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN D');

# A simple superposition, homologous whole chains
my $atod_sup = superposition($doma, $domd);

# The value computed externally by STAMP, the reference values
my $atod_expect = pdl
    [ -0.55482, +0.24558, -0.79490, -52.48704 ],
    [ +0.42054, -0.74162, -0.52264, -56.30138 ],
    [ -0.71786, -0.62425, +0.30819, -55.71054 ],
    [ 0,        0,        0,        1 ];

# Verify approximate equality
pdl_approx(
    $atod_sup->transformation->matrix, $atod_expect,
    "superposition($doma, $domd)",     $toler
);

# The opposite superposition should have the inverse transformation matrix
my $dtoa_sup = superposition($domd, $doma);

# No-longer using ->inv due to bug in PDL's identity() function
my $dtoa_expect = $atod_expect->inv;

#use PDL::Slatec;
#my $dtoa_expect = matinv($atod_expect);
pdl_approx(
    $dtoa_sup->transformation->matrix, $dtoa_expect,
    "superposition($domd, $doma)",     $toler
);

# Also achievable by using inverse() from the Transformation
pdl_approx(
    $atod_sup->transformation->inverse->matrix,             $dtoa_expect,
    "superposition($doma, $domd)->transformation->inverse", $toler
);

# Test chaining of superpositions
# get domains for whole chains
my $ca = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN A');
my $cb = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN B');
my $cc = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN C');
my $cd = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN D');

my $supcacc = superposition($ca, $cc);
my $supcccd = superposition($cc, $cd);
$supcacc->apply($ca);
$supcccd->apply($ca);

# How to verify non-visually?
rasmol [ $ca, $cd ] if debug();

# Now change up the order
$ca = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN A');
$cb = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN B');
$cc = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN C');
$cd = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN D');

$supcacc = superposition($ca, $cc);
$supcacc->apply($ca);

# Now we're doing the superposition of a domain that already has a transform
$supcccd = superposition($ca, $cd);
$supcccd->apply($ca);

# How to verify non-visually?
rasmol [ $ca, $cd ] if debug();

# Finally, do it on both sides, parallel superpositions
$ca = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN A');
$cb = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN B');
$cc = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN C');
$cd = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN D');

# Put A onto C
$supcacc = superposition($ca, $cc);
$supcacc->apply($ca);

# Put B onto D
my $supcbcd = superposition($cb, $cd);
$supcbcd->apply($cb);

# Put moved A onto moved B (ie C onto D)
my $supcacb = superposition($ca, $cb);
$supcacb->apply($ca);

# How to verify non-visually?
rasmol [ $ca, $cd ] if debug();

# Test sub-segments of chains
# Get domains for two chains of interest
my $dombseg =
    new SBG::Domain(pdbid => '2br2', descriptor => 'B 8 _ to B 248 _');
my $domdseg =
    new SBG::Domain(pdbid => '2br2', descriptor => 'D 8 _ to D 248 _');
my $seg_sup = superposition($dombseg, $domdseg);

# The value computed externally by STAMP, the reference values
my $seg_expect = pdl
    [ +0.11083, +0.04249, +0.99293, +9.308960 ],
    [ +0.99239, -0.05858, -0.10826, -10.08272 ],
    [ +0.05356, +0.99738, -0.04866, -0.083290 ],
    [ 0,        0,        0,        1 ];

# Verify approximate equality
pdl_approx(
    $seg_sup->transformation->matrix,    $seg_expect,
    "superposition($dombseg, $domdseg)", $toler
);

# Test transform()
# Based on archael exosome (2br2: one ring: Chains DABEFC )
# 2 unique chains: A (and every 2nd), B (and every 2nd)
# Get the superposition for "like" onto "like" (e.g. D onto B)
# Then take a copy of A and apply that transformation to it:
#   Given: DAB
# 1xApply:   DA
# 2xApply:     DA
# Finally: DADADA = Homohexamer homologous to DABEFC

my $d2br2d = new SBG::Domain(pdbid => '2br2', descriptor => 'CHAIN D');
my $d2br2b = new SBG::Domain(pdbid => '2br2', descriptor => 'CHAIN B');

# The basic transformation
my $superp = superposition($d2br2d, $d2br2b);
my $transf = $superp->transformation;

# Now get the native dimer: (round 0)
my $d2br2d0 = new SBG::Domain(pdbid => '2br2', descriptor => 'CHAIN D');
my $d2br2a0 = new SBG::Domain(pdbid => '2br2', descriptor => 'CHAIN A');

# Dont' do transforms in 1st round, those are already in the frame of reference

# 2nd round (round 1)
my $d2br2d1 = new SBG::Domain(pdbid => '2br2', descriptor => 'CHAIN D');
my $d2br2a1 = new SBG::Domain(pdbid => '2br2', descriptor => 'CHAIN A');

# Apply
$transf->apply($d2br2d1);
$transf->apply($d2br2a1);

# Apply product (round 2)
my $double  = $transf x $transf;
my $d2br2d2 = new SBG::Domain(pdbid => '2br2', descriptor => 'CHAIN D');
my $d2br2a2 = new SBG::Domain(pdbid => '2br2', descriptor => 'CHAIN A');
$double->apply($d2br2d2);
$double->apply($d2br2a2);

# Collect all 6 domains, 2 native, 2 transformed once, 2 transformed twice
my @doms = ($d2br2d0, $d2br2a0, $d2br2d1, $d2br2a1, $d2br2d2, $d2br2a2);
rasmol \@doms if debug();

# Test superposition for single domains with existing transformation
sub _mksphere {
    my ($pdbid, $chain) = @_;
    my $dom = new SBG::Domain(pdbid => $pdbid, descriptor => "CHAIN $chain");
    return cofm($dom);
}

my $movingb = _mksphere('2br2', 'B');
my $staticd = _mksphere('2br2', 'D');
my $staticf = _mksphere('2br2', 'F');

my $sup1 = superposition($movingb, $staticd);
$sup1->apply($movingb);
my $sup2 = superposition($movingb, $staticf);
$sup2->apply($movingb);

# Now check RMSD between b and f
my $rmsd = $movingb->rmsd($staticf);
is_approx($rmsd, 6.55, "RMSD after transformation", $toler);

my $ass2_1_a = SBG::Domain->new(pdbid => '3bct', assembly => 2, model => 1);
my $ass2_2_a = SBG::Domain->new(pdbid => '3bct', assembly => 2, model => 2);
my $ass_sup = superposition($ass2_1_a, $ass2_2_a);

# The value computed externally by STAMP, the reference values
my $ass_expect = pdl
    [ -1.00000, +0.00000, +0.00000, +128.19835 ],
    [ +0.00000, +1.00000, +0.00000, +0.0000000 ],
    [ +0.00000, +0.00000, -1.00000, +93.501820 ],
    [ 0,        0,        0,        1 ];

# Verify approximate equality
pdl_approx($ass_sup->matrix, $ass_expect,
    "assembly superposition($ass2_1_a, $ass2_2_a)", $toler);

done_testing;
