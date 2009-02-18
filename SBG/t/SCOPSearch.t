#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test 'float_is';
use feature 'say';
use Carp;
use Data::Dumper;
$, = ' ';

use SBG::SCOPSearch;
use SBG::Interaction;

my @accnos = SBG::SCOPSearch::domains('2os7');

my @seqs = (new SBG::Seq(-accession_number=>'1ir2B.c.1.14.1-1'),
            new SBG::Seq(-accession_number=>'1ir2B.d.58.9.1-1'));
my $searcher = new SBG::SCOPSearch;
$searcher->type('SBG::Domain::CofM');
my @iactions = $searcher->search(@seqs);

for (@iactions) {
    say $_;
}

