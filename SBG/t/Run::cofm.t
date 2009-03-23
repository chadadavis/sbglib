#!/usr/bin/env perl

use Test::More 'no_plan';
use feature 'say';
use SBG::Run::cofm qw/cofm/;
use SBG::Test qw/float_is/;
$, = ' ';

# Precision
my $prec = 4;

# Don't use a whole chain here, as those are cached in the DB
my $res;
$res = _test1('2nn6', "A 50 _ to A 120 _", 
              83.495, 17.452, 114.562, 15.246, 22.781);

$res = _test1('2frq', 'B 100 _ to B 131 A B 150 _ to B 155 B', 
              70.445, 30.823, 55.482, 17.395, 26.443);

my $m = SBG::Run::cofm::_atom2pdl($res->{'description'});

print $m;

TODO: {
    local $TODO;
    $TODO = "test on multi-chain or multi-segment domains";
    ok(0);
    $TODO = "test insertion codes";
    ok(0);
}

sub _test1 {
    my ($pdb, $descriptor, $tx, $ty, $tz, $trg, $trmax) = @_;
    my $res = cofm($pdb, $descriptor);
    float_is($res->{Cx}, $tx, $prec);
    float_is($res->{Cy}, $ty, $prec);
    float_is($res->{Cz}, $tz, $prec);
    float_is($res->{Rg}, $trg, $prec);
    float_is($res->{Rmax}, $trmax, $prec);
    is($res->{descriptor}, $descriptor, 'descriptor');
    ok($res->{file}, "File defined: $file");
    my @atomlines = $res->{'description'} =~ /^ATOM/gm;
    is(scalar(@atomlines), 7, "7 Points: CofM,X+/-5,Y+/-5,Z+/-5");
    return $res;
}


__END__


