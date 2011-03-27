#!/usr/bin/env perl

use Test::More 'no_plan';


use FindBin qw/$Bin/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test 'float_is';

use SBG::Network;
use SBG::NetworkIO::csv;
use SBG::NetworkIO::png;

my $file = shift || "$Bin/../data/ex_small.csv";
my $in = new SBG::NetworkIO::csv(file=>$file);
my $net = $in->read;

my $out = SBG::NetworkIO::png->new(tempfile=>1);
$out->write($net);
$out->close;

# Validate the PNG format 
my $cmd = join ' ', 'file', $out->file, ' | grep -q -i "PNG"';
ok(system($cmd) == 0, "'file' identified PNG format");



