#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test 'float_is';
use feature 'say';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
my $dir = $FindBin::RealBin;
$, = ' ';

################################################################################

package SBG::HashFieldsTest;
use Moose;
use SBG::HashFields;
use Moose::Autobox;
use autobox;
use Data::Dumper;

hashfield('myfield', 'myfields');
# sub myfields { (shift)->{'myfield'} }

my $obj = new SBG::HashFieldsTest;
# $obj->myfield('key', 33);
say Dumper $obj;
my $hf = $obj->myfields;
say Dumper $hf;

