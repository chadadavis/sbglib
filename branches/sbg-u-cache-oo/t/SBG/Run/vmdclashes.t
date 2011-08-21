#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;



use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use Test::Approx;
use SBG::Debug;
use SBG::U::Object qw/load_object/;
use SBG::Run::vmdclashes qw/vmdclashes/;

# Precision (or error tolerance)
my $prec = '2%';

my $res = vmdclashes("$Bin/../data/086-00002.pdb");
is_approx($res->{'pcclashes'}, 0.33969166, "vmdclashes", $prec);

my $complex = load_object("$Bin/../data/3kfi.target");
$res = vmdclashes($complex);
is_approx($res->{'pcclashes'}, 2.747, "vmdclashes", $prec);


done_testing();
