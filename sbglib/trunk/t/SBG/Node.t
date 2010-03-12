#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::Node;
use SBG::Seq;

# new()
my $n1 = new SBG::Node(new SBG::Seq(-display_id=>'Q86Y41'));
isa_ok($n1, "Bio::Network::Node");
isa_ok($n1, "SBG::Node");

my $n2 = new SBG::Node(new SBG::Seq(-display_id=>'Q9NPD3'));
is("$n2", 'Q9NPD3', "Stringification from SBG::Seq->display_id");

ok($n1 le $n2, "String comparison: le");
ok($n2 ge $n1, "String comparison: ge");

my $n3 = new SBG::Node(new SBG::Seq(-display_id=>'Q9NPD3'));
is($n2, $n3, "String equality, between unique objects");


