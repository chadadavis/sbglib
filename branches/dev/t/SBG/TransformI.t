#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Carp;
$SIG{__DIE__} = \&confess;

use PDL;

use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";
use Test::SBG::PDL qw/pdl_approx/;
use SBG::Transform::Affine;

my $toler = 0.01;

# All tests use this transformation matrix
my $mat = pdl
    [ -0.54889, +0.42532, -0.7196,  -52.19956 ],
    [ +0.24755, -0.73955, -0.62594, -56.01334 ],
    [ -0.79839, -0.52171, +0.30063, -55.90146 ],
    [ 0,        0,        0,        1 ];
my $t = new SBG::Transform::Affine(matrix => $mat);

# Text extraction of the rotational component
my $rot     = $t->rotation;
my $rot_exp = pdl
    [ -0.54889, +0.42532, -0.7196 ],
    [ +0.24755, -0.73955, -0.62594 ],
    [ -0.79839, -0.52171, +0.30063 ],
    ;
pdl_approx($rot, $rot_exp, 'rotation()', $toler);

my $transl = $t->translation;
my $transl_exp = pdl(-52.19956, -56.01334, -55.90146)->transpose();
pdl_approx($transl, $transl_exp, 'translation()', $toler);

# Test inverse
my $inv     = $t->inverse;
my $inv_ans = pdl
    [ -0.54888900,  +0.247558082, -0.79840342,  -59.417126 ],
    [ +0.425322451, -0.739532804, -0.521708170, -48.386305 ],
    [ -0.71959723,  -0.625931417, +0.300643047, -55.816782 ],
    [ 0.,           0.,           0.,           1. ];
pdl_approx($inv->matrix, $inv_ans, 'inverse()', $toler,);

# Test identity
my $inv_prod = $t x $inv;
my $id       = new SBG::Transform::Affine;
pdl_approx($inv_prod->matrix, $id->matrix, 'inverse() produces identity',
    $toler,);

# Test transforming a vector
my $v = pdl [ 1.1, 2.2, 3.3, 1 ];

# NB don't need to transpose $v here (does it for us)
my $prod = $t->apply($v);
my $prod_ans = pdl [ -54.2423, -59.4336, -56.9354, 1. ];
pdl_approx($prod, $prod_ans, 'Vector transformation', $toler,);

# Testing matrix composition
my $squared     = $t x $t;
my $squared_ans = pdl
    [ +0.98108, -0.17257, -0.08757, -7.14464 ],
    [ +0.18079, +0.97878, +0.09660, +7.48028 ],
    [ +0.06905, -0.11058, +0.99145, -1.80878 ],
    [ 0,        0,        0,        1 ];
pdl_approx($squared, $squared_ans, 'Matrix composition', $toler,);

# Test inverting a composition
my $sq_inv      = $squared->inverse;
my $sq_inv_prod = $sq_inv x $squared;
pdl_approx($sq_inv_prod->matrix, $id->matrix, 'inverse() on composition',
    $toler,);

done_testing;
