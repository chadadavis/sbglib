#!/usr/bin/env perl
use SBG::Domain;
my $dom = SBG::Domain->new(pdbid => '1g3n');
print $dom->file;
