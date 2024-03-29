#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use lib "$Bin/../../../t/lib/";
use SBG::Debug;

use Test::More;
use File::Temp qw/tempfile/;

use Test::SBG::PDL qw/pdl_approx/;
use SBG::U::Log;

use PDL;
use SBG::TransformIO::stamp;
use SBG::Transform::Affine;

# Tolerate rounding differences between clib (STAMP) and PDL
use PDL::Ufunc;
use PDL::Core;
my $toler = 1.0;

my $mat = pdl
    [ 1.1, 2.2, 3.3, 1.1 ],
    [ 4.4, 5.5, 6.6, 2.2 ],
    [ 7.7, 8.8, 9.9, 3.3 ],
    [ 0.0, 0.0, 0.0, 1.0 ];
my $t = new SBG::Transform::Affine(matrix => $mat);
my $out = new SBG::TransformIO::stamp(tempfile => 1);
$out->write($t);
$out->close;

my $in = new SBG::TransformIO::stamp(file => $out->file);
my $t2 = $in->read;

pdl_approx($t2->matrix, $t->matrix);

done_testing;
