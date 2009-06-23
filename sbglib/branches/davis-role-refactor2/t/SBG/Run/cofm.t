#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Run::cofm qw/cofm/;
use SBG::U::Test qw/float_is/;
use Data::Dumper;
$, = ' ';


# Precision
my $prec = 4;

# Don't use a whole chain here, as those are cached in the DB
my $res;
$res = _test1('2nn6', "A 50 _ to A 120 _", 
              83.495, 17.452, 114.562, 15.246, 22.781);

$res = _test1('2frq', 'B 100 _ to B 131 A B 150 _ to B 155 B', 
              70.445, 30.823, 55.482, 17.395, 26.443);


TODO: {
    local $TODO;
    $TODO = "test on multi-chain or multi-segment domains";
    ok(1);
    $TODO = "test insertion codes";
    ok(1);
}

sub _test1 {
    my ($pdb, $descriptor, $tx, $ty, $tz, $trg, $trmax) = @_;
    my $res = cofm($pdb, $descriptor);
    float_is($res->{Cx},  $tx,   'Cx'  ,$prec);
    float_is($res->{Cy},  $ty,   'Cy'  ,$prec);
    float_is($res->{Cz},  $tz,   'Cz'  ,$prec);
    float_is($res->{Rg},  $trg,  'Rg'  ,$prec);
    float_is($res->{Rmax},$trmax,'Rmax',$prec);
    return $res;
}


__END__


