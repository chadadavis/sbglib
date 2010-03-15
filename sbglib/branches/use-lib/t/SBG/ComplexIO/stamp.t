#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;
use FindBin qw/$Bin/;

my $DEBUG;
# $DEBUG = 1;
$File::Temp::KEEP_ALL = $DEBUG;

use SBG::ComplexIO::stamp;
my $file = "$Bin/../data/2nn6.dom";

# Test reading all at once, array context
my $io = SBG::ComplexIO::stamp->new(file=>"<$file");
my $complex = $io->read;
is($complex->count, 9, "Complex has 9 domains");

# Write out
my $out = SBG::ComplexIO::stamp->new(tempfile=>1);
$out->write($complex);

# Need to flush to re-read it
$out->flush;

# And read back in
my $io3 = SBG::ComplexIO::stamp->new(file=>$out->file);
my $copy = $io3->read;
is($copy->count, $complex->count, "Same domain count");


__END__
