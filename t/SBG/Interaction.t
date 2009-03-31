#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test 'float_is';
use feature 'say';
use Carp;
use Data::Dumper;
$, = ' ';

use SBG::Interaction;


# new()
my $label1 = "component1-component2(template1-template2)";
my $i1 = new SBG::Interaction(-id=>$label1, -weight => 33.3);
isa_ok($i1, "Bio::Network::Interaction");
isa_ok($i1, "SBG::Interaction");

my $label2 = "component3-component4(template3-template4)";
my $i2 = new SBG::Interaction(-id=>$label2, -weight => 66.6);

is("$i2", $label2, "Stringification from 'primary_id'");
ok($i1 le $i2, "String comparison: le");
ok($i2 ge $i1, "String comparison: ge");

my $i3 = new SBG::Interaction(-id=>$label2, -weight => 99.9);
is($i2, $i3, "String equality, between unique objects");

TODO: {
    local $TODO = "Test Interaction->template('key') = $domain";
    ok(1);
}

TODO: {
    local $TODO = "test creating an interation using SBG::Node and SBG::Domain";
    ok(1);
}



