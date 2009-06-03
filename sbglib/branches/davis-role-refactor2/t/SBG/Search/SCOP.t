#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
my $dir = $FindBin::RealBin;
$, = ' ';

################################################################################

use SBG::Search::SCOP;
use SBG::Interaction;
use SBG::Complex;
use Moose::Autobox;
use SBG::STAMP qw/gtransform/;

my @accnos = SBG::Search::SCOP::domains('2os7');

my @seqs = (new SBG::Seq(-accession_number=>'1ir2B.c.1.14.1-1'),
            new SBG::Seq(-accession_number=>'1ir2B.d.58.9.1-1'));
my $searcher = new SBG::Search::SCOP;
$searcher->type('SBG::Domain::CofM');
my @iactions = $searcher->search(@seqs);

is(scalar(@iactions), 5, "Found 5 expected interactions");

my $complex = SBG::Search::SCOP::complex('2os7');
my $file = "transformed.pdb";
gtransform(doms=>$complex->models->values,out=>$file);
ok(-r $file, "gtransformed: $file");
unlink $file;


