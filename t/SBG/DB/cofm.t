#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test;
$, = ' ';
use Data::Dumper;
use SBG::DB::cofm;
use SBG::Test qw/float_is/;

use PDL;
use PDL::Matrix;

my $prec = 4;

# query()
my $res = SBG::DB::cofm::query('2nn6', 'A');

ok($res, "query('2nn6', 'A')");
my ($tx, $ty, $tz, $trg, $trmax) = (80.860, 12.450, 122.080, 26.738, 63.826);

float_is($res->{'Cx'}, $tx, $prec, 'Cx');
float_is($res->{'Cy'}, $ty, $prec, 'Cy');
float_is($res->{'Cz'}, $tz, $prec, 'Cz');
float_is($res->{'Rg'}, $trg, $prec, 'Rg');
float_is($res->{'Rmax'}, $trmax, $prec, 'Rmax');
is($res->{'descriptor'}, 'CHAIN A', 'descriptor');
ok($res->{'file'}, "File: " . $res->{'file'});



__END__


