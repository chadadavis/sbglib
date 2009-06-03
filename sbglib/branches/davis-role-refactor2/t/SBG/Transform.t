#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::U::Test qw/float_is pdl_approx/;
use Carp;
use Data::Dumper;
$, = ' ';

use SBG::Transform::Homog;
use PDL;


my $mat = pdl
 [ -0.54889 ,  0.42532 , -0.7196  , -52.19956 ],
 [  0.24755 , -0.73955 , -0.62594 , -56.01334 ],
 [ -0.79839 , -0.52171 ,  0.30063 , -55.90146 ], 
 [        0 ,        0 ,        0 ,         1 ];
my $t = new SBG::Transform::Homog(matrix=>$mat);


# Test inverse
my $inv = $t->inverse;
my $inv_ans = pdl 
    [-0.54888900 ,  0.247558082 , -0.79840342  , -59.417126 ],
    [0.425322451 , -0.739532804 , -0.521708170 , -48.386305 ],
    [-0.71959723 , -0.625931417 ,  0.300643047 , -55.816782 ], 
    [ 0.         ,  0.          ,  0.          ,   1.       ];
pdl_approx($inv->matrix, $inv_ans);


# Test identity
my $inv_prod = $t x $inv;
my $id = new SBG::Transform::Homog;
pdl_approx($inv_prod->matrix, $id->matrix);


# Test transforming a vector
my $v = pdl [ 1.1,2.2,3.3,1];
my $prod = ($t x $v->transpose)->transpose;
my $prod_ans = pdl [ -54.2423,-59.4336,-56.9354,1.];
pdl_approx($prod, $prod_ans);


# Testing matrix composition
my $squared = $t x $t;
my $squared_ans = pdl 
    [  0.98108 , -0.17257 , -0.08757 , -7.14464],
    [  0.18079 ,  0.97878 ,  0.09660 ,  7.48028],
    [  0.06905 , -0.11058 ,  0.99145 , -1.80878],
    [  0       ,  0       ,  0       ,  1      ];
pdl_approx($squared, $squared_ans);


# Test inverting a composition
my $sq_inv = $squared->inverse;
my $sq_inv_prod = $sq_inv x $squared;
pdl_approx($sq_inv_prod->matrix, $id->matrix);


