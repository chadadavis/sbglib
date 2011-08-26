#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";

# Autoboxing native types
use Moose::Autobox;

# Also: Look for methods of ARRAY objects in SBG::U::List
use autobox ARRAY => 'SBG::U::List';

use SBG::U::CartesianPermutation;

my $classes = [ [ 1, 2, 3 ], [ 4, 5 ], [6] ];

# Assuming this model, i.e. 2 members of 1st class, 1 of 2nd, and 1 of 3rd
# my $model = [ 1, 2, 5, 6 ];

my $expect = [
    [ 1, 2, 4, 6 ],
    [ 1, 2, 5, 6 ],
    [ 1, 3, 4, 6 ],
    [ 1, 3, 5, 6 ],
    [ 2, 1, 4, 6 ],
    [ 2, 1, 5, 6 ],
    [ 2, 3, 4, 6 ],
    [ 2, 3, 5, 6 ],
    [ 3, 1, 4, 6 ],
    [ 3, 1, 5, 6 ],
    [ 3, 2, 4, 6 ],
    [ 3, 2, 5, 6 ],
];

my $pm = SBG::U::CartesianPermutation->new(
    classes => $classes,
    kclass  => [ 2, 1, 1 ]
);
my $got = [];
while (my $next = $pm->next) {
    $got->push($next->flatten_deep);
}
is_deeply($got, $expect, 'CartesianPermutation');

is($pm->cardinality, $expect->length, 'cardinality');

done_testing();
