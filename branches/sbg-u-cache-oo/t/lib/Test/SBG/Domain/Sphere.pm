#!/usr/bin/env perl

package Test::SBG::Domain::Sphere;

# Inheritance
use base qw/Test::SBG/;
# Just 'use' it to import all the testing functions and symbols 
use Test::SBG; 

use SBG::Domain::Sphere;

sub sphere : Test(1) {
    local $TODO = "Not yet implemented";
}

1;