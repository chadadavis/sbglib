#!/usr/bin/env perl

use Test::More 'no_plan';
use Data::Dumper;


use PDL;
use PDL::Matrix;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test qw/float_is/;

use SBG::DB::cofm;

$, = ' ';

my $prec = 4;

# query()
my $res = SBG::DB::cofm::query('2nn6', 'A');

ok($res, "query('2nn6', 'A')");
my ($tx, $ty, $tz, $trg, $trmax) = (80.860, 12.450, 122.080, 26.738, 63.826);

float_is($res->{'Cx'}, $tx, 'Cx', $prec);
float_is($res->{'Cy'}, $ty, 'Cy', $prec);
float_is($res->{'Cz'}, $tz, 'Cz', $prec);
float_is($res->{'Rg'}, $trg,'Rg', $prec);
float_is($res->{'Rmax'}, $trmax, 'Rmax',$prec);



__END__


