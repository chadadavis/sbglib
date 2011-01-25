#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;
use Data::Dump qw/dump/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test qw/float_is pdl_approx/;
use SBG::U::Log;

my $DEBUG;
#$DEBUG = 1;
SBG::U::Log::init( undef, loglevel => 'DEBUG' ) if $DEBUG;

use SBG::U::Object qw/load_object/;
use SBG::Run::vmdclashes;

# Precision (or error tolerance)
my $prec = '2%';

my $complex = load_object("$Bin/../data/086-00002.model");
my $res = SBG::Run::vmdclashes::vmdclashes($complex);

float_is($res->{'pcclashes'}, 0.33969166, "vmdclashes", $prec);

done_testing();
