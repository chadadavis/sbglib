#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::U::Test qw/float_is pdl_approx pdl_percent/;
use Data::Dumper;
use Data::Dump qw/dump/;
use Carp;
$SIG{__DIE__} = \&confess;

use Moose::Autobox;
use PDL;

use SBG::DB::trans;
use SBG::DB::entity;

use SBG::Domain;
use SBG::DomainIO::pdb;
use SBG::DomainIO::stamp;

use SBG::STAMP;

use SBG::Run::cofm qw/cofm/;
use SBG::Run::rasmol;
use SBG::U::Log qw/log/;

my $DEBUG;
# $DEBUG = 1;
log()->init('TRACE') if $DEBUG;

# Tolerate rounding differences between stamp (using clib) and PDL
my $toler = '15%';


# One hexameric ring of 2br2: CHAINS ADCFEB 
# (only unique interfaces: A/B and A/D) (B/D homologs, A/C homologs, etc)

my $doma = SBG::DB::entity::id2dom(125751);
my $domb = SBG::DB::entity::id2dom(125752);
my $domc = SBG::DB::entity::id2dom(125753);
my $domd = SBG::DB::entity::id2dom(125754);

# A simple superposition, homologous whole chains
my $atod_sup = SBG::DB::trans::query($doma, $domd);
# The value computed externally by STAMP, the reference values
my $atod_expect = pdl
 [ -0.55482 ,  0.24558 , -0.79490 ,     -52.48704 ],
 [  0.42054 , -0.74162 , -0.52264 ,     -56.30138 ],
 [ -0.71786 , -0.62425 ,  0.30819 ,     -55.71054 ], 
 [        0 ,        0 ,        0 ,             1 ];
# Verify approximate equality
pdl_percent($atod_sup->transformation->matrix->slice(',0:2'),
           $atod_expect->slice(',0:2'),
           "SBG::DB::trans::query($doma, $domd)",
           $toler);


# The opposite superposition should have the inverse transformation matrix
my $dtoa_sup = SBG::DB::trans::query($domd, $doma);
my $dtoa_expect = $atod_expect->inv;
pdl_percent($dtoa_sup->transformation->matrix->slice(',0:2'),
           $dtoa_expect->slice(',0:2'),
           "SBG::DB::trans::query($domd, $doma)",
           $toler);

# Also achievable by using inverse() from the Transformation
pdl_percent($atod_sup->transformation->inverse->matrix->slice(',0:2'),
           $dtoa_expect->slice(',0:2'),
           "SBG::DB::trans::query($doma, $domd)->transformation->inverse",
           $toler);


# Test chaining of superpositions
# get domains for whole chains 
my $ca = SBG::DB::entity::id2dom(125751);
my $cb = SBG::DB::entity::id2dom(125752);
my $cc = SBG::DB::entity::id2dom(125753);
my $cd = SBG::DB::entity::id2dom(125754);
my $ce = SBG::DB::entity::id2dom(125755);
my $cf = SBG::DB::entity::id2dom(125756);

my $supcacc = SBG::DB::trans::query($ca, $cc);
my $supcccd = SBG::DB::trans::query($cc, $cd);
$supcacc->apply($ca);
$supcccd->apply($ca);
# How to verify non-visually?
rasmol [$ca, $cd] if $DEBUG;


# Now change up the order
$ca = SBG::DB::entity::id2dom(125751);
$cb = SBG::DB::entity::id2dom(125752);
$cc = SBG::DB::entity::id2dom(125753);
$cd = SBG::DB::entity::id2dom(125754);

$supcacc = SBG::DB::trans::query($ca, $cc);
$supcacc->apply($ca);
# Now we're doing the superposition of a domain that already has a transform
$supcccd = SBG::DB::trans::query($ca, $cd);
$supcccd->apply($ca);
# How to verify non-visually?
rasmol [$ca, $cd] if $DEBUG;


# Finally, do it on both sides, parallel superpositions
$ca = SBG::DB::entity::id2dom(125751);
$cb = SBG::DB::entity::id2dom(125752);
$cc = SBG::DB::entity::id2dom(125753);
$cd = SBG::DB::entity::id2dom(125754);


# Put A onto C
$supcacc = SBG::DB::trans::query($ca, $cc);
$supcacc->apply($ca);
# Put B onto D
my $supcbcd = SBG::DB::trans::query($cb, $cd);
$supcbcd->apply($cb);

# Put moved A onto moved B (ie C onto D)
my $supcacb = SBG::DB::trans::query($ca, $cb);
$supcacb->apply($ca);

# How to verify non-visually?
rasmol [$ca, $cd] if $DEBUG;



# Test transform()
# Based on archael exosome (2br2: one ring: Chains DABEFC )
# 2 unique chains: A (and every 2nd), B (and every 2nd)
# Get the superposition for "like" onto "like" (e.g. D onto B)
# Then take a copy of A and apply that transformation to it:
#   Given: DAB
# 1xApply:   DA
# 2xApply:     DA
# Finally: DADADA = Homohexamer homologous to DABEFC

my $d2br2d = SBG::DB::entity::id2dom(125754);
my $d2br2b = SBG::DB::entity::id2dom(125752);
# The basic transformation
my $superp = SBG::DB::trans::query($d2br2d, $d2br2b);
my $transf = $superp->transformation;

# Now get the native dimer: (round 0)
my $d2br2d0 = SBG::DB::entity::id2dom(125754);
my $d2br2a0 = SBG::DB::entity::id2dom(125751);
# Dont' do transforms in 1st round, those are already in the frame of reference

# 2nd round (round 1)
my $d2br2d1 = SBG::DB::entity::id2dom(125754);
my $d2br2a1 = SBG::DB::entity::id2dom(125751);
# Apply
$transf->apply($d2br2d1);
$transf->apply($d2br2a1);

# Apply product (round 2)
my $double = $transf x $transf;
my $d2br2d2 = SBG::DB::entity::id2dom(125754);
my $d2br2a2 = SBG::DB::entity::id2dom(125751);
$double->apply($d2br2d2);
$double->apply($d2br2a2);

# Collect all 6 domains, 2 native, 2 transformed once, 2 transformed twice
my @doms = ($d2br2d0,$d2br2a0,$d2br2d1,$d2br2a1,$d2br2d2,$d2br2a2);
rasmol \@doms if $DEBUG;


my $movingb = SBG::DB::entity::id2dom(125752);
my $staticd = SBG::DB::entity::id2dom(125754);
my $staticf = SBG::DB::entity::id2dom(125756);

my $sup1 = SBG::DB::trans::query($movingb, $staticd);
$sup1->apply($movingb);
my $sup2 = SBG::DB::trans::query($movingb, $staticf);
$sup2->apply($movingb);

# Now check RMSD between b and f
my $rmsd = $movingb->rmsd($staticf);
float_is($rmsd, 6.55, "RMSD after transformation", $toler);


# Test iRMSD

# 1VOR K/R 153203 153210
my $doms1 = [SBG::DB::entity::id2dom(153203),SBG::DB::entity::id2dom(153210)];
# 1VP0 K/R 174395 174402
my $doms2 = [SBG::DB::entity::id2dom(174395),SBG::DB::entity::id2dom(174402)];

my $irmsd;
$irmsd = SBG::STAMP::irmsd($doms1, $doms2);
float_is($irmsd, 5.11, "iRMSD", 0.01);
$irmsd = SBG::STAMP::irmsd($doms2, $doms1);
float_is($irmsd, 5.11, "iRMSD reverse", 0.01);

