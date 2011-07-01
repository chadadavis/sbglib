#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test 'float_is';
use Carp;
use Data::Dumper;
$, = ' ';

use SBG::Transform;

################################################################################
# Requires (outside functionality that I assume)



################################################################################
# Provides (promises made to users of my module)

$t = new SBG::Transform;
isa_ok($t->matrix, 'PDL::Matrix');



