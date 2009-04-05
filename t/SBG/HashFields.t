#!/usr/bin/env perl

package SBG::HashFieldsTest;

use Test::More 'no_plan';
use SBG::Test 'float_is';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
my $dir = $FindBin::RealBin;
$, = ' ';

################################################################################

use Moose;
use SBG::HashFields;
use Moose::Autobox;
use autobox;

hashfield('myfield', 'myfields');
# sub myfields { (shift)->{'myfield'} }

my $obj = new SBG::HashFieldsTest;
$obj->myfield('key', 33);
is($obj->myfield('key'), 33);
my $hf = $obj->myfields;
ok($hf);

