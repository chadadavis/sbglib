#!/usr/bin/env perl

use PDL;

my $x = sequence(10);
print which($x>4b);
