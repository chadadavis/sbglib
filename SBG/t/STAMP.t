#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test 'float_is';
use feature 'say';
use Carp;
use Data::Dumper;
$, = ' ';

use SBG::STAMP qw/pdbc superpose gtransform/;
use SBG::Domain;
use SBG::DomainIO;
use SBG::Domain::CofM;
use List::MoreUtils qw(first_index);


# Tolerate rounding differences between clib (STAMP) and PDL (SBG)
use PDL::Ufunc;
my $toler = 0.5;

# TODO test do_stamp alone (i.e. on a family of domains)

# Test pdbc
$io = pdbc('2nn6', 'A');
# Define the type of Domain object we want back
$io->type('SBG::Domain::CofM');
$dom = $io->read;
is($dom->pdbid, '2nn6', 'pdbid');
is($dom->descriptor, 'CHAIN A', 'descriptor');


# get domains for two chains of interest
my $doma = SBG::Domain::CofM->new(pdbid=>'2br2', descriptor=>'CHAIN A');
my $domb = SBG::Domain::CofM->new(pdbid=>'2br2', descriptor=>'CHAIN B');
my $domd = SBG::Domain::CofM->new(pdbid=>'2br2', descriptor=>'CHAIN D');

# Get superposition, in both directions
my $tt;
$tt = superpose($doma, $domd);
ok($tt, "superpose'd A onto D");

my $aontod = $tt && $tt->matrix;
ok($tt, "superpose'd D onto A");
$tt = superpose($domd, $doma);
my $dontoa = $tt && $tt->matrix;

# The value computed externally by STAMP, the reference values
my $atod_transstr = <<STOP;
   -0.54889    0.24755   -0.79839       -52.19956  
    0.42532   -0.73955   -0.52171       -56.01334  
   -0.71960   -0.62594    0.30063       -55.90146
STOP
my $dtoa_transstr = <<STOP;
   -0.54889    0.42532   -0.71960       -45.05492  
    0.24756   -0.73954   -0.62593       -63.49199  
   -0.79840   -0.52171    0.30064       -54.09263
STOP

# Convert this into PDL matrixes
my $dtoa_ans = new SBG::Transform(string=>$dtoa_transstr)->matrix;
my $atod_ans = new SBG::Transform(string=>$atod_transstr)->matrix;


unless(
    ok(all($aontod >= $atod_ans - $toler) && all($aontod <= $atod_ans + $toler),
       "superpose 2br2A onto 2br2D: agrees w/ STAMP to w/in $toler A")
    ) {
    print STDERR "Expected:\n$atod_ans\nGot:\n$aontod\n";
}

unless(
    ok(all($dontoa >= $dtoa_ans - $toler) && all($dontoa <= $dtoa_ans + $toler),
       "superpose 2br2D onto 2br2A: agrees w/ STAMP to w/in $toler A")
    ) {
    print STDERR "Expected:\n$dtoa_ans\nGot:\n$dontoa\n";    
}


# Test transform()
# Based on archael exosome (2br2: one ring: Chains DABEFC )
# 2 unique chains: A (and every 2nd), B (and every 2nd)
# Get the superposition for "like" onto "like" (e.g. D onto B)
# Then take a copy of A and apply that transformation to it:
#   Given: DAB
# 1xApply:   DA
# 2xApply:     DA
# Finally: DADADA = Homohexamer homologous to DABEFC

my $d2br2d = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'CHAIN D');
my $d2br2b = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'CHAIN B');
# The basic transformation
my $transf = superpose($d2br2d, $d2br2b);

# Now get the dimer:
my $d2br2d0 = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'CHAIN D');
my $d2br2a0 = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'CHAIN A');
# Dont' do transforms there, those are already in the frame of reference

my $d2br2d1 = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'CHAIN D');
my $d2br2a1 = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'CHAIN A');

# Apply
$d2br2d1->transform($transf);
$d2br2a1->transform($transf);

# Apply product
my $double = $transf x $transf;
my $d2br2d2 = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'CHAIN D');
my $d2br2a2 = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'CHAIN A');

$d2br2d2->transform($double);
$d2br2a2->transform($double);


my @doms = ($d2br2d0,$d2br2a0,$d2br2d1,$d2br2a1,$d2br2d2,$d2br2a2);

use SBG::Run::rasmol qw/pdb2img/;

# Finally, transform() the whole thing into a coordinate file, a la STAMP
my $file = gtransform(doms=>\@doms);
if (ok(-r $file, "transform() created PDB file: $file")) {
    `rasmol $file 2>/dev/null`;
#     ok(ask("You saw a hexameric ring"), "Confirmed hexamer");
    
    # Convert to IMG
    # And highlight clashes from domain $d2br2d1
    # Which index in the array is occupied by 2br2d1 ?
    my $chi = first_index { $_ == $d2br2d1 } @doms; 
    # This is the chain that will display the domain 2br2d1 in the complex
    my $chain = chr(ord('A') + $chi);

    my $optstr = "select (!*$chain and within(10.0, *$chain))\ncolor white";
    my $img = pdb2img(pdb=>$file, script=>$optstr);
    if (ok($img && -r $img, "pdb2img() created image from PDB file")) {
        print 
            "Now showing an image of the same\n",
            "(with clashes from the red chain highlighted in white)\n";
        `display $img`;
#         ok(ask("You saw the same hexamer"), "Confirmed image conversion");
    }
}



# Test querying transformations from database
# Get domains for two chains of interest
my $domb5 = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'CHAIN B');
my $domd5 = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'CHAIN D');
my $trans5 = SBG::STAMP::superpose_query($domb5, $domd5);
ok($trans5, "Got transform from database cache");
my $btod_transstr = <<STOP;
   0.11085    0.04257    0.99292         9.31432  
   0.99240   -0.05858   -0.10828       -10.07972  
   0.05357    0.99738   -0.04873        -0.08447
STOP
# Convert this into PDL matrixes
my $btod_ans = new SBG::Transform(string=>$btod_transstr)->matrix;
# Get the underlying PDL
$trans5 = $trans5->matrix;
unless(
    ok(all($trans5 >= $btod_ans - $toler) && all($trans5 <= $btod_ans + $toler),
       "Database transformation verified, to within $toler A")
    ) {
    print STDERR "Expected:\n$btod_ans\nGot:\n$trans5\n";
}


# Test sub-segments of chains
# Get domains for two chains of interest
my $dombseg = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'B 8 _ to B 248 _');
my $domdseg = new SBG::Domain::CofM(pdbid=>'2br2', descriptor=>'D 8 _ to D 248 _');
# TODO verify the transformation values
my $trans = superpose($dombseg, $domdseg);
ok($trans, "superpose($dombseg onto $domdseg)");

TODO: {
    local $TODO = "Test pickframe";
    ok(0);
}


################################################################################

sub ask {
    my $question = shift;
    my $answer;
    print STDERR "$question ? [Y/n] ";
    read \*STDIN, $answer, 1;
    return $answer !~ /^\s*n/i;
}

__END__
