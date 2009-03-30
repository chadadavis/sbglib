#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::Seq;

# new()
my $s1 = new SBG::Seq(-accession_number=>'Q86Y41');
isa_ok($s1, "Bio::Seq");
isa_ok($s1, "SBG::Seq");

my $s2 = new SBG::Seq(-accession_number=>'Q9NPD3');
is("$s2", 'Q9NPD3', "Stringification from 'accession_number'");
ok($s1 le $s2, "String comparison: le");
ok($s2 ge $s1, "String comparison: ge");

my $s3 = new SBG::Seq(-accession_number=>'Q9NPD3');
is($s2, $s3, "String equality, between unique objects");


