#!/usr/bin/env perl

use Test::More 'no_plan';

use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";

use SBG::Seq;

# new()
my $s1 = new SBG::Seq(-display_id => 'Q86Y41');
isa_ok($s1, "Bio::Seq");
isa_ok($s1, "SBG::Seq");

my $s2 = new SBG::Seq(-display_id => 'Q9NPD3');
is("$s2", 'Q9NPD3', "Stringification from 'display_id'");
ok($s1 le $s2, "String comparison: le");
ok($s2 ge $s1, "String comparison: ge");

my $s3 = new SBG::Seq(-display_id => 'Q9NPD3');
is($s2, $s3, "String equality, between unique objects");

