#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use PDL;
use PDL::Matrix;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use Test::Approx;

use SBG::U::DB;

unless (SBG::U::DB::ping) {
    plan skip_all => "No database";
}

use SBG::DB::cofm;

$, = ' ';

# query()
my $res = SBG::DB::cofm::query('2nn6', 'A');
# Run it twice to test database statement handle caching
$res = SBG::DB::cofm::query('2nn6', 'A');

ok($res, "query('2nn6', 'A')");
my ($tx, $ty, $tz, $trg, $trmax) = (80.860, 12.450, 122.080, 26.738, 63.826);

my $prec = '1%';
is_approx($res->{Cx},   $tx,    'Cx',   $prec);
is_approx($res->{Cy},   $ty,    'Cy',   $prec);
is_approx($res->{Cz},   $tz,    'Cz',   $prec);
is_approx($res->{Rg},   $trg,   'Rg',   $prec);
is_approx($res->{Rmax}, $trmax, 'Rmax', $prec);

done_testing;


