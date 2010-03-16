#!/usr/bin/env perl

use Test::More 'no_plan';
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp;

use FindBin qw/$Bin/;
use lib "$Bin/../../../../lib/";
use SBG::U::Test qw/float_is pdl_approx/;

# $File::Temp::KEEP_ALL = 1;

################################################################################

use SBG::STAMP;
use SBG::Domain;
use SBG::DB::trans qw/superposition/;
use PDL;

# Tolerate rounding differences between stamp (using clib) and PDL
my $toler = 0.5;

# get domains for chains of interest
my $doma = SBG::Domain->new(pdbid=>'2br2', descriptor=>'CHAIN A');
my $domb = SBG::Domain->new(pdbid=>'2br2', descriptor=>'CHAIN B');
my $domd = SBG::Domain->new(pdbid=>'2br2', descriptor=>'CHAIN D');


# Test querying transformations from database
# Get domains for two chains of interest
my $domb5 = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN B');
my $domd5 = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN D');
my $trans5bd = SBG::DB::trans::superposition($domb5, $domd5);
my $trans5db = SBG::DB::trans::superposition($domd5, $domb5);
ok($trans5bd, "Got transform from database") or die;
ok($trans5db, "Got transform from database") or die;
# Get the underlying PDL of the computed transform to be tested
$trans5bd = $trans5bd->matrix;
$trans5db = $trans5db->matrix;

my $btod_transstr = <<STOP;
   0.11085    0.04257    0.99292         9.31432  
   0.99240   -0.05858   -0.10828       -10.07972  
   0.05357    0.99738   -0.04873        -0.08447
STOP

my $dtob_transstr = <<STOP;
   0.10738532   0.99286529  0.051780912    8.8568476
   0.04345857  -0.05672928   0.99744707  -0.78669765
   0.99327385  -0.10486514 -0.049241691   -10.168513
            0            0            0            1
STOP

# Convert this into PDL matrixes
my $btod_ans = new SBG::Transform(string=>$btod_transstr)->matrix;
my $dtob_ans = new SBG::Transform(string=>$dtob_transstr)->matrix;

pdl_approx($trans5bd, $btod_ans, $toler, 
           "Database transformation verified B=>D, to within $toler A");
pdl_approx($trans5db, $dtob_ans, $toler, 
           "Database transformation verified D=>B, to within $toler A");





