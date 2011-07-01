#!/usr/bin/env perl

use Test::More 'no_plan';
use Data::Dumper;
use Data::Dump qw/dump/;

use Moose::Autobox;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test qw/float_is pdl_approx/;



use SBG::Seq; # for stringify
use SBG::Run::pdbseq qw/pdbseq/;
use SBG::Domain;

my $dom = SBG::Domain->new(pdbid=>'2br2',descriptor=>'CHAIN A');
my $seq = pdbseq($dom);

isa_ok($seq, 'Bio::Seq', 'pdbseq');
is($seq->length, 260, "$seq->length is ". $seq->length);

my $dom2 = SBG::Domain->new(pdbid=>'2br2',descriptor=>'CHAIN B');
my @seqs = pdbseq($dom, $dom2);
is(scalar(@seqs), 2, "pdbseq returns array");
is($seqs[1]->length, 241, '$seqs[1]->length is '. $seqs[1]->length);


# Test getting last residue
my $dom1rv8B = SBG::Domain->new(pdbid=>'1rv8',descriptor=>'B 7 _ to B 259 _');
$seq = pdbseq($dom1rv8B);
is($seq->length, 253, 'pdbseq gets last residue');


