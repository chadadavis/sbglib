#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::NetworkIO;

use FindBin;
my $dir = $FindBin::RealBin;
my $file = "$dir/ex_templates_descriptors.csv";

my $io = new SBG::NetworkIO(-file=>$file);
my $net = $io->read;


__END__

