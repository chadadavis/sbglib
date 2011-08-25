#!/usr/bin/env perl

use strict;
use Test::More 'no_plan';

use Carp;
use FindBin qw/$Bin/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::ComplexIO::report;
use SBG::U::Object qw/load_object/;

my $file = "$Bin/../data/10.model";

my $complex = load_object($file);
my $ndoms   = 12;
is($complex->count, $ndoms, "Complex has $ndoms domains");

my $str;
my $out = SBG::ComplexIO::report->new(string => \$str);
$out->write($complex);

# Need to flush to re-read it
$out->flush;

my @chains = $str =~ /^CHAIN \S+/gm;
is(scalar(@chains), $ndoms, 'report::write() to string');

__END__
