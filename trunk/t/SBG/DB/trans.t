#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use Carp;
$SIG{__DIE__} = \&confess;

use Moose::Autobox;
use PDL;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use Test::Approx;
use SBG::U::Test qw/pdl_approx/;

use SBG::DB::trans qw/superposition/;
use SBG::DB::entity qw/id2dom/;

use SBG::Domain;
use SBG::DomainIO::pdb;
use SBG::DomainIO::stamp;

use SBG::STAMP;
use SBG::U::iRMSD;
use SBG::Run::cofm qw/cofm/;
use SBG::Run::rasmol;
use SBG::Debug qw(debug);

use SBG::U::DB;

unless (SBG::U::DB::ping) {
    ok warn "skip : no database\n";
    exit;
}

# Tolerate rounding differences between stamp (using clib) and PDL
my $toler = '15%';

# One hexameric ring of 2br2: CHAINS ADCFEB
# (only unique interfaces: A/B and A/D) (B/D homologs, A/C homologs, etc)

my $doma = id2dom(125751);
my $domb = id2dom(125752);
my $domc = id2dom(125753);
my $domd = id2dom(125754);

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
    $atod_sup->transformation->matrix->slice(',0:2'),
    $atod_expect->slice(',0:2'),
    "superposition($doma, $domd)", $toler
);

# The opposite superposition should have the inverse transformation matrix
my $dtoa_sup = superposition($domd, $doma);
my $dtoa_expect = $atod_expect->inv;
pdl_approx(
    $dtoa_sup->transformation->matrix->slice(',0:2'),
    $dtoa_expect->slice(',0:2'),
    "superposition($domd, $doma)", $toler
);

# Also achievable by using inverse() from the Transformation
pdl_approx(
    $atod_sup->transformation->inverse->matrix->slice(',0:2'),
    $dtoa_expect->slice(',0:2'),
    "superposition($doma, $domd)->transformation->inverse",
    $toler
);

# Test chaining of superpositions
# get domains for whole chains
my $ca = id2dom(125751);
my $cb = id2dom(125752);
my $cc = id2dom(125753);
my $cd = id2dom(125754);
my $ce = id2dom(125755);
my $cf = id2dom(125756);

my $supcacc = superposition($ca, $cc);
my $supcccd = superposition($cc, $cd);
$supcacc->apply($ca);
$supcccd->apply($ca);

# How to verify non-visually?
rasmol [ $ca, $cd ] if debug();

# Now change up the order
$ca = id2dom(125751);
$cb = id2dom(125752);
$cc = id2dom(125753);
$cd = id2dom(125754);

$supcacc = superposition($ca, $cc);
$supcacc->apply($ca);

# Now we're doing the superposition of a domain that already has a transform
$supcccd = superposition($ca, $cd);
$supcccd->apply($ca);

# How to verify non-visually?
rasmol [ $ca, $cd ] if debug();

# Finally, do it on both sides, parallel superpositions
$ca = id2dom(125751);
$cb = id2dom(125752);
$cc = id2dom(125753);
$cd = id2dom(125754);

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

# Test transform()
# Based on archael exosome (2br2: one ring: Chains DABEFC )
# 2 unique chains: A (and every 2nd), B (and every 2nd)
# Get the superposition for "like" onto "like" (e.g. D onto B)
# Then take a copy of A and apply that transformation to it:
#   Given: DAB
# 1xApply:   DA
# 2xApply:     DA
# Finally: DADADA = Homohexamer homologous to DABEFC

my $d2br2d = id2dom(125754);
my $d2br2b = id2dom(125752);

# The basic transformation
my $superp = superposition($d2br2d, $d2br2b);
my $transf = $superp->transformation;

# Now get the native dimer: (round 0)
my $d2br2d0 = id2dom(125754);
my $d2br2a0 = id2dom(125751);

# Dont do transforms in 1st round, those are already in the frame of reference

# 2nd round (round 1)
my $d2br2d1 = id2dom(125754);
my $d2br2a1 = id2dom(125751);

# Apply
$transf->apply($d2br2d1);
$transf->apply($d2br2a1);

# Apply product (round 2)
my $double  = $transf x $transf;
my $d2br2d2 = id2dom(125754);
my $d2br2a2 = id2dom(125751);
$double->apply($d2br2d2);
$double->apply($d2br2a2);

# Collect all 6 domains, 2 native, 2 transformed once, 2 transformed twice
my @doms = ($d2br2d0, $d2br2a0, $d2br2d1, $d2br2a1, $d2br2d2, $d2br2a2);
rasmol \@doms if debug();

my $movingb = id2dom(125752);
my $staticd = id2dom(125754);
my $staticf = id2dom(125756);

my $sup1 = superposition($movingb, $staticd);
$sup1->apply($movingb);
my $sup2 = superposition($movingb, $staticf);
$sup2->apply($movingb);

# Now check RMSD between b and f
my $rmsd = $movingb->rmsd($staticf);
is_approx($rmsd, 6.55, "RMSD after transformation", $toler);

# Test iRMSD

# 1VOR K/R 153203 153210
my $doms1 = [ id2dom(153203), id2dom(153210) ];

# 1VP0 K/R 174395 174402
my $doms2 = [ id2dom(174395), id2dom(174402) ];

my $irmsd;
$irmsd = SBG::U::iRMSD::irmsd($doms1, $doms2);
is_approx($irmsd, 5.11, "iRMSD", $toler);
$irmsd = SBG::U::iRMSD::irmsd($doms2, $doms1);
is_approx($irmsd, 5.11, "iRMSD reverse", $toler);

