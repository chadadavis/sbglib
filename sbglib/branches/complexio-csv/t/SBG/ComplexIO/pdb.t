#!/usr/bin/env perl

use Test::More 'no_plan';

use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;
use FindBin qw/$Bin/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test 'float_is';
use SBG::ComplexIO::pdb;
use SBG::U::Object qw/load_object/;

my $DEBUG;
$DEBUG = $DB::sub;
$File::Temp::KEEP_ALL = $DEBUG;

my $file = "$Bin/../data/10.model";

my $complex = load_object($file);
my $mndoms = 12;
is($complex->count, $mndoms, "Complex loaded");

# Write out
my $out = SBG::ComplexIO::pdb->new(tempfile=>1);
$out->write($complex);

# Need to flush to re-read it
$out->flush;

ok(-s $out->file, "ComplexIO::pdb::write() : " . $out->file);



__END__
