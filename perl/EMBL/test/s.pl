#!/usr/bin/env perl

use strict;
use warnings;

use lib "..";
use EMBL::CofM;

# my @junk = EMBL::CofM::lookup("100d", "A");
my @junk = EMBL::CofM::lookup("101m", "A");

print ":@junk:\n";

