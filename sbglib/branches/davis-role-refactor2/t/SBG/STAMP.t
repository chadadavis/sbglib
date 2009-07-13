#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test qw/float_is pdl_approx/;
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp;

use SBG::U::Log qw/log/;
log()->init('TRACE');
$File::Temp::KEEP_ALL = 1;

use SBG::STAMP qw/superposition/;
use SBG::Domain;
use SBG::DomainIO::pdb;
use PDL;

# Tolerate rounding differences between stamp (using clib) and PDL
my $toler = 0.25;

# get domains for chains of interest
my $doma = SBG::Domain->new(pdbid=>'2br2', descriptor=>'CHAIN A');
my $domb = SBG::Domain->new(pdbid=>'2br2', descriptor=>'CHAIN B');
my $domd = SBG::Domain->new(pdbid=>'2br2', descriptor=>'CHAIN D');

# A simple superposition, homologous whole chains
$atod_sup = superposition($doma, $domd);
# The value computed externally by STAMP, the reference values
my $atod_expect = pdl
 [ -0.55482 ,  0.24558 , -0.79490 ,     -52.48704 ],
 [  0.42054 , -0.74162 , -0.52264 ,     -56.30138 ],
 [ -0.71786 , -0.62425 ,  0.30819 ,     -55.71054 ], 
 [        0 ,        0 ,        0 ,             1 ];
# Verify approximate equality
pdl_approx($atod_sup->transformation->matrix,
           $atod_expect,
           "superposition($doma, $domd)",
           $toler);


# The opposite superposition should have the inverse transformation matrix
$dtoa_sup = superposition($domd, $doma);
my $dtoa_expect = $atod_expect->inv;
pdl_approx($dtoa_sup->transformation->matrix,
           $dtoa_expect,
           "superposition($domd, $doma)",
           $toler);


# Test sub-segments of chains
# Get domains for two chains of interest
my $dombseg = new SBG::Domain(pdbid=>'2br2', descriptor=>'B 8 _ to B 248 _');
my $domdseg = new SBG::Domain(pdbid=>'2br2', descriptor=>'D 8 _ to D 248 _');
my $seg_sup = superposition($dombseg, $domdseg);
# The value computed externally by STAMP, the reference values
my $seg_expect = pdl
 [ 0.11083 ,  0.04249 ,  0.99293 ,       9.30896 ],
 [ 0.99239 , -0.05858 , -0.10826 ,     -10.08272 ],
 [ 0.05356 ,  0.99738 , -0.04866 ,      -0.08329 ], 
 [       0 ,        0 ,        0 ,             1 ];
# Verify approximate equality
pdl_approx($seg_sup->transformation->matrix,
           $seg_expect,
           "superposition($dombseg, $domdseg)",
           $toler);


# Test transform()
# Based on archael exosome (2br2: one ring: Chains DABEFC )
# 2 unique chains: A (and every 2nd), B (and every 2nd)
# Get the superposition for "like" onto "like" (e.g. D onto B)
# Then take a copy of A and apply that transformation to it:
#   Given: DAB
# 1xApply:   DA
# 2xApply:     DA
# Finally: DADADA = Homohexamer homologous to DABEFC

my $d2br2d = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN D');
my $d2br2b = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN B');
# The basic transformation
my $superp = superposition($d2br2d, $d2br2b);
my $transf = $superp->transformation;

# Now get the native dimer: (round 0)
my $d2br2d0 = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN D');
my $d2br2a0 = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN A');
# Dont' do transforms in 1st round, those are already in the frame of reference

# 2nd round (round 1)
my $d2br2d1 = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN D');
my $d2br2a1 = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN A');
# Apply
$transf->apply($d2br2d1);
$transf->apply($d2br2a1);

# Apply product (round 2)
my $double = $transf x $transf;
my $d2br2d2 = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN D');
my $d2br2a2 = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN A');
$double->apply($d2br2d2);
$double->apply($d2br2a2);

# Collect all 6 domains, 2 native, 2 transformed once, 2 transformed twice
my @doms = ($d2br2d0,$d2br2a0,$d2br2d1,$d2br2a1,$d2br2d2,$d2br2a2);

# Finally, transform the whole thing into a coordinate file, a la STAMP
my $io = new SBG::DomainIO::pdb(tempfile=>1);
$io->write(@doms);
my $file = $io->file;
if (ok(-r $file, "Should find a hexamer in PDB file: $file")) {
#     `rasmol $file 2>/dev/null`;
}





