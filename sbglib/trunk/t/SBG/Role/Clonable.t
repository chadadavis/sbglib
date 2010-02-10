#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::U::Test qw/float_is pdl_approx/;
use Carp;
$SIG{__DIE__} = \&confess;


use SBG::Transform::Affine;
use PDL;


# All tests use this transformation matrix
my $mat = pdl
 [ -0.54889 ,  0.42532 , -0.7196  , -52.19956 ],
 [  0.24755 , -0.73955 , -0.62594 , -56.01334 ],
 [ -0.79839 , -0.52171 ,  0.30063 , -55.90146 ], 
 [        0 ,        0 ,        0 ,         1 ];
my $t = new SBG::Transform::Affine(matrix=>$mat);


# NB Not sufficient to use Scalar::Util::refaddr, as the PDL is deep in memory
# Requies using PDL-specific operators
my $clone = $t->clone;
isnt($clone->matrix->get_dataref, $t->matrix->get_dataref, "Cloning: PDLs also copy'ed");




