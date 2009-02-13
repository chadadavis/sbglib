#!/usr/bin/env perl

use Test::More 'no_plan';
use feature 'say';
use SBG::Run::cofm qw/cofm/;
use SBG::Test qw/float_is/;
$, = ' ';


my $prec = 4;

$res = cofm('2nn6', "A 50 _ to A 120 _");
($tx, $ty, $tz, $trg, $trmax) = (83.495, 17.452, 114.562, 15.246, 22.781);

float_is($res->{Cx}, $tx, $prec);
float_is($res->{Cy}, $ty, $prec);
float_is($res->{Cz}, $tz, $prec);
float_is($res->{Rg}, $trg, $prec);
float_is($res->{Rmax}, $trmax, $prec);
is($res->{descriptor}, 'A 50 _ to A 120 _', 'descriptor');
ok($res->{file}, "File: $file");

say Dumper $res;
__END__

$res = cofm('2nn6', 'CHAIN A');
($tx, $ty, $tz, $trg, $trmax) = (80.860, 12.450, 122.080, 26.738, 63.826);

float_is($res->{Cx}, $tx, $prec);
float_is($res->{Cy}, $ty, $prec);
float_is($res->{Cz}, $tz, $prec);
float_is($res->{Rg}, $trg, $prec);
float_is($res->{Rmax}, $trmax, $prec);
is($res->{descriptor}, 'CHAIN A', 'descriptor');
ok($res->{file}, "File: $file");

# TODO test on multi-chain or multi-segment domains


__END__


