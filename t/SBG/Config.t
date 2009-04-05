#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test qw/float_is/;

use SBG::Config qw/config/;

my $c = config();
$c->newval('somesection', 'someparam', .5);
is($c->val('somesection', 'someparam'), .5);

