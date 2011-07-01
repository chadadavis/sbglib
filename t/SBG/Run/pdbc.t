#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test qw/float_is pdl_approx/;
use Data::Dumper;
use Data::Dump qw/dump/;

use SBG::Run::pdbc qw/pdbc/;
use SBG::Domain;

my $fields = pdbc('2nn6');

is($fields->{'header'}, 'HYDROLASE/TRANSFERASE', "pdbc 'header' field");
is(scalar keys %$fields, 10, 'pdbc 9 chains + header');

$fields = pdbc('2nn6A');



