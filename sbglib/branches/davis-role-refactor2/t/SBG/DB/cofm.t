#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test;
$, = ' ';
use Data::Dumper;
use SBG::U::DB::cofm;
use SBG::U::Test qw/float_is/;

use PDL;
use PDL::Matrix;

my $prec = 4;

# query()
my $res = SBG::U::DB::cofm::query('2nn6', 'A');

ok($res, "query('2nn6', 'A')");
my ($tx, $ty, $tz, $trg, $trmax) = (80.860, 12.450, 122.080, 26.738, 63.826);

float_is($res->{'Cx'}, $tx, 'Cx', $prec);
float_is($res->{'Cy'}, $ty, 'Cy', $prec);
float_is($res->{'Cz'}, $tz, 'Cz', $prec);
float_is($res->{'Rg'}, $trg,'Rg', $prec);
float_is($res->{'Rmax'}, $trmax, 'Rmax',$prec);
is($res->{'descriptor'}, 'CHAIN A', 'descriptor');
ok($res->{'file'}, "File: " . $res->{'file'});



__END__


