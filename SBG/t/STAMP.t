#!/usr/bin/env perl

use Test::More 'no_plan';
use strict;
use warnings;

use SBG::STAMP;
use SBG::Domain;
use SBG::DomainIO;
use SBG::CofM;
use SBG::Complex;

# Tolerate rounding differences between clib (STAMP) and PDL (SBG)
use PDL::Ufunc;
my $toler = 0.25;

# TODO test do_stamp alone (i.e. on a family of domains)

# Test pdbc
my $dom = pdbc('2nn6', 'A')->read();
is($dom->label, '2nn6a', 'pdbc');

# Get domains for two chains of interest
my $doma = SBG::CofM::cofm('2br2', 'CHAIN A');
my $domd = SBG::CofM::cofm('2br2', 'CHAIN D');

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
my $dtoa_ans = new SBG::Transform(-string=>$dtoa_transstr)->matrix;
my $atod_ans = new SBG::Transform(-string=>$atod_transstr)->matrix;


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

my $d2br2d = new SBG::Domain(-label=>'2br2d');
my $d2br2b = new SBG::Domain(-label=>'2br2b');
my $transf = superpose($d2br2d, $d2br2b);

# Now get the dimer:
my $d2br2d0 = new SBG::Domain(-label=>'2br2d-d0');
my $d2br2a0 = new SBG::Domain(-label=>'2br2a-a0');
# Dont' do transforms there, those are already in the frame of reference

my $d2br2d1 = new SBG::Domain(-label=>'2br2d-d1');
my $d2br2a1 = new SBG::Domain(-label=>'2br2a-a1');
# Apply
$d2br2d1->transform($transf);
$d2br2a1->transform($transf);

# Apply product
my $double = $transf * $transf;
my $d2br2d2 = new SBG::Domain(-label=>'2br2d-d2');
my $d2br2a2 = new SBG::Domain(-label=>'2br2a-a2');
$d2br2d2->transform($double);
$d2br2a2->transform($double);

my $complex = new SBG::Complex();
$complex->add($d2br2d0,$d2br2a0,$d2br2d1,$d2br2a1,$d2br2d2,$d2br2a2);
my @doms = $complex->asarray;
is(@doms, 6, "Complex contains all 6: @doms");


use SBG::List qw(whichfield);

# Finally, transform() the whole thing into a coordinate file, a la STAMP
my $file = transform(-doms=>\@doms);
if (ok(-r $file, "transform() created PDB file: $file")) {
#     `rasmol $file 2>/dev/null`;
#     ok(ask("You saw a hexameric ring"), "Confirmed hexamer");
    
    # Convert to IMG
    # And highlight clashes from domain $d2br2d1
    # Which index in the array is occupied by 2br2d1 ?
    # NB the actual label is just 'd1' not '2br2d-d1'
    my $chi = whichfield('label', 'd1', @doms);
    # This is the chain that will display the domain 2br2d1 in the complex
    my $chain = chr(ord('A') + $chi);

    my $optstr = "select (!*$chain and within(10.0, *$chain))\ncolor white";
    my $img = pdb2img(-pdb=>$file, -script=>$optstr);
    if (ok($img && -r $img, "pdb2img() created image from PDB file")) {
        print 
            "Now showing an image of the same\n",
            "(with clashes from the red chain highlighted in white)\n";
#         `display $img`;
#         ok(ask("You saw the same hexamer"), "Confirmed image conversion");
    }
}


# Test querying transformations from database
# Get domains for two chains of interest
my $domb5 = SBG::CofM::cofm('2br2', 'CHAIN B');
my $domd5 = SBG::CofM::cofm('2br2', 'CHAIN D');
my $trans5 = SBG::STAMP::superpose_query($domb5, $domd5);
ok($trans5, "Got transform from database cache");
my $btod_transstr = <<STOP;
   0.11085    0.04257    0.99292         9.31432  
   0.99240   -0.05858   -0.10828       -10.07972  
   0.05357    0.99738   -0.04873        -0.08447
STOP
# Convert this into PDL matrixes
my $btod_ans = new SBG::Transform(-string=>$btod_transstr)->matrix;
# Get the underlying PDL
$trans5 = $trans5->matrix;
unless(
    ok(all($trans5 >= $btod_ans - $toler) && all($trans5 <= $btod_ans + $toler),
       "Database transformation verified, to within $toler A")
    ) {
    print STDERR "Expected:\n$btod_ans\nGot:\n$trans5\n";
}


# TODO  Test sub-segments of chains
# Get domains for two chains of interest
my $dombseg = SBG::CofM::cofm('2br2', 'B 8 _ to B 248 _');
my $domdseg = SBG::CofM::cofm('2br2', 'D 8 _ to D 248 _');
my $trans = superpose($dombseg, $domdseg);
print "Superposing segments:\n$trans\n";


################################################################################

sub ask {
    my $question = shift;
    my $answer;
    print STDERR "$question ? [Y/n] ";
    read \*STDIN, $answer, 1;
    return $answer !~ /^\s*n/i;
}

__END__
