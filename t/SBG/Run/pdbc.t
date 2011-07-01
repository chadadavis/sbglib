#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use SBG::Test 'float_is';
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
$File::Temp::KEEP_ALL = 1;
my $dir = $FindBin::RealBin;
# Space-separated outputs
$, = ' ';
# Auto-Flush STDOUT
$| = 1;

################################################################################

use SBG::Run::pdbc qw/pdbc/;
use SBG::ComplexIO;

# Test pdbc
my $domio = pdbc('2nn6');
my $assemio = new SBG::ComplexIO(fh=>$domio->fh);
my $pdbcassem = $assemio->read;
is($pdbcassem->size, 9, "SBG::Run::pdbc(2nn6): " . $pdbcassem->size . " domains");
