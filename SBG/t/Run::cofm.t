#!/usr/bin/env perl

use Test::More 'no_plan';
use feature 'say';
use SBG::Run::cofm qw/cofm/;
use SBG::Test qw/float_is/;
$, = ' ';

# Precision
my $prec = 4;

# Don't use a whole chain here, as those are cached in the DB
$res = cofm('2nn6', "A 50 _ to A 120 _");

($tx, $ty, $tz, $trg, $trmax) = (83.495, 17.452, 114.562, 15.246, 22.781);
float_is($res->{Cx}, $tx, $prec);
float_is($res->{Cy}, $ty, $prec);
float_is($res->{Cz}, $tz, $prec);
float_is($res->{Rg}, $trg, $prec);
float_is($res->{Rmax}, $trmax, $prec);
is($res->{descriptor}, 'A 50 _ to A 120 _', 'descriptor');
ok($res->{file}, "File: $file");

my @atomlines = $res->{'description'} =~ /^ATOM/gm;
is(scalar(@atomlines), 7, "7 Points: CofM,X+/-5,Y+/-5,Z+/-5");

my $m = SBG::Run::cofm::_atom2pdl($res->{'description'});

print $m;

TODO: {
    local $TODO;
    $TODO = "test on multi-chain or multi-segment domains";
    ok(0);
}


__END__


