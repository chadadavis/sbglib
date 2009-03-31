#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::Test 'float_is';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
$File::Temp::KEEP_ALL = 1;
my $dir = $FindBin::RealBin;
# Space-separated outputs
$, = ' ';
# Auto-Flush STDOUT
$| = 1;

################################################################################

use SBG::Run::rasmol qw/pdb2img/;

my $file = "/g/data/pdb/pdb2nn6.ent";

# Convert to IMG
# And highlight close residues
my $chain = 'A';
my $optstr = "select (!*$chain and within(10.0, *$chain))\ncolor white";
my (undef, $img) = tempfile(SUFFIX=>'.ppm');
pdb2img(pdb=>$file, script=>$optstr, img=>$img);
if (ok($img && -r $img, "pdb2img() $file => $img")) {
    `display $img`;
#         ok(ask("You saw the same hexamer"), "Confirmed image conversion");
}


