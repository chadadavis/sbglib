#!/usr/bin/env perl


use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
my $dir = $FindBin::RealBin;
$, = ' ';

use SBG::Domain;
use SBG::Domain::Crosshairs;

################################################################################
# Sanity check

$x = new_ok('SBG::Domain::Crosshairs' => [ pdbid=>'2nn6', descriptor=>'CHAIN A' ]);

TODO: {
    local $TODO = "Test 7-point RMSD";
    ok(1);

}

__END__

