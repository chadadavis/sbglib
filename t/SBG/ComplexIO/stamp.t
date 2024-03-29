#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Carp;
use FindBin qw/$Bin/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib";
use SBG::ComplexIO::stamp;

use SBG::Debug;

my $file = "$Bin/../data/2nn6.dom";

# Test reading all at once, array context
my $io = SBG::ComplexIO::stamp->new(file => $file);
my $complex = $io->read;
is($complex->count, 9, "Complex has 9 domains");

# Write out
my $out = SBG::ComplexIO::stamp->new(tempfile => 1);
$out->write($complex);

note $out->file if SBG::Debug->debug;

# Need to flush to re-read it
$out->flush;

# And read back in
my $io3 = SBG::ComplexIO::stamp->new(file => $out->file);
my $copy = $io3->read;
is($copy->count, $complex->count, "Same domain count");

done_testing;
