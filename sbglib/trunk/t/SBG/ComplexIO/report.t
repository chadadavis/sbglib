#!/usr/bin/env perl

use Test::More 'no_plan';

use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;
use FindBin qw/$Bin/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test 'float_is';
use SBG::ComplexIO::report;
use SBG::U::Object qw/load_object/;

my $DEBUG;
$DEBUG = $DB::sub;
$File::Temp::KEEP_ALL = $DEBUG;

my $file = "$Bin/../data/086-00002.model";

my $complex = load_object($file);

is($complex->count, 5, "Complex has 5 domains");

my $str;
my $out = SBG::ComplexIO::report->new(string=>\$str);
$out->write($complex);
# Need to flush to re-read it
$out->flush;

my @chains = $str =~ /^CHAIN \S+/gm;
is(scalar(@chains), 5, 'report::write() to string');


__END__
