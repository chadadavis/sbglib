#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use Carp;

use File::Temp qw/tempfile/;
$File::Temp::KEEP_ALL = 1;


use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test qw/pdl_approx float_is/;

use SBG::U::iRMSD qw/irmsd/;
use SBG::Domain;

# Test iRMSD
# Make pairs of domains :
sub _d {
    my ($pdb, $chain) = @_;
    return new SBG::Domain(pdbid=>$pdb, descriptor=>"CHAIN $chain");
}

my $toler = '1%';
my $doms1 = [ _d(qw/1vor K/), _d(qw/1vor R/) ];
my $doms2 = [ _d(qw/1vp0 K/), _d(qw/1vp0 R/) ];
my $irmsd;
$irmsd = irmsd($doms1, $doms2);
float_is($irmsd, 5.11, "iRMSD", $toler);
$irmsd = irmsd($doms2, $doms1);
float_is($irmsd, 5.11, "iRMSD reverse", $toler);


$TODO = "Test STAMP::irmsd for domains with an existing transformation";
ok 0;


