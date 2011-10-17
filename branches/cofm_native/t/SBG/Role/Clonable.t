#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Carp;
$SIG{__DIE__} = \&confess;

use PDL;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Transform::Affine;

# All tests use this transformation matrix
my $mat = pdl
    [ -0.54889, +0.42532, -0.7196,  -52.19956 ],
    [ +0.24755, -0.73955, -0.62594, -56.01334 ],
    [ -0.79839, -0.52171, +0.30063, -55.90146 ],
    [ 0,        0,        0,        1 ];
my $t = new SBG::Transform::Affine(matrix => $mat);

# NB Not sufficient to use Scalar::Util::refaddr, as the PDL is deep in memory
# Requies using PDL-specific operators
my $clone = $t->clone;
isnt($clone->matrix->get_dataref,
    $t->matrix->get_dataref, "Role::Clonable: PDLs also copy'ed");

# And dclone also magically hooks in and does the write thing without explicitly
# delegating to the Role
use Storable qw/dclone/;
my $dclone = dclone($t);
isnt($dclone->matrix->get_dataref,
    $t->matrix->get_dataref, "dclone: PDLs also copy'ed");

done_testing;
