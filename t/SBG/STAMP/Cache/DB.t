#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../../lib/";
use lib "$Bin/../../../../t/lib/";
use SBG::Debug;

use Test::More;
use File::Temp;
use Test::SBG::PDL qw/pdl_approx/;
use SBG::U::DB;

unless (SBG::U::DB::ping) {
    plan skip_all => 'No database';
}

use SBG::STAMP;
use SBG::Domain;
use SBG::DB::trans qw/superposition/;
use SBG::DB::entity;
use PDL;

# Tolerate rounding differences between stamp (using clib) and PDL
my $toler = 1.0;

# get domains for chains of interest
my $doma = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN A');
my $domb = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN B');
my $domd = SBG::Domain->new(pdbid => '2br2', descriptor => 'CHAIN D');

# Test querying transformations from database
# Get domains for two chains of interest
sub _query {
    my ($pdbid, $chain) = @_;
    my @hits = SBG::DB::entity::query($pdbid, $chain);
    my ($firsthit) = grep { $_->{dom} =~ /^CHAIN/ } @hits;
    my $dom = SBG::DB::entity::id2dom($firsthit->{entity});
    return $dom;
}

my $domb5 = _query('2br2', 'B');
my $domd5 = _query('2br2', 'D');

my $trans5bd = SBG::DB::trans::superposition($domb5, $domd5);
my $trans5db = SBG::DB::trans::superposition($domd5, $domb5);
ok($trans5bd, "Got transform from database") or die;
ok($trans5db, "Got transform from database") or die;

# Get the underlying PDL of the computed transform to be tested
$trans5bd = $trans5bd->transformation->matrix;
$trans5db = $trans5db->transformation->matrix;

# Convert this into PDL matrixes
my $btod_ans = pdl [
    [ +0.11085, +0.04257, +0.99292, +9.31432 ],
    [ +0.99240, -0.05858, -0.10828, -10.0797 ],
    [ +0.05357, +0.99738, -0.04873, -0.08447 ],
    [ 0,        0,        0,        1 ],
];

my $dtob_ans = pdl [
    [ +0.10738532, +0.99286529, +0.051780912, +8.8568476 ],
    [ +0.04345857, -0.05672928, +0.99744707,  -0.7866976 ],
    [ +0.99327385, -0.10486514, -0.049241691, -10.168513 ],
    [ 0,           0,           0,            1 ],
];

pdl_approx($trans5bd, $btod_ans,
    "Database transformation verified B=>D, to within $toler", $toler);
pdl_approx($trans5db, $dtob_ans,
    "Database transformation verified D=>B, to within $toler", $toler);

done_testing();


