#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
use Data::Dumper;
use FindBin;

use File::Temp qw/tempfile/;
use SBG::U::Log qw/log/;
my $DEBUG;
$DEBUG = 1;
log()->init('TRACE') if $DEBUG;
$File::Temp::KEEP_ALL = $DEBUG;


################################################################################

use SBG::Run::rasmol qw/pdb2img/;

my $file = "/g/data/pdb/pdb2nn6.ent";

# Convert to IMG
# And highlight close residues
my $chain = 'A';
my $optstr = "select (!*$chain and within(10.0, *$chain))\ncolor white";
my (undef, $img) = tempfile('sbg_XXXXX', TMPDIR=>1, SUFFIX=>'.ppm');
pdb2img(pdb=>$file, script=>$optstr, img=>$img);
if (ok($img && -r $img, "pdb2img() $file => $img")) {
#    `display $img`;
#         ok(ask("You saw the same hexamer"), "Confirmed image conversion");
}


