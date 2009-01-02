#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::AssemblyIO;
use SBG::Assembly;
use SBG::DomainIO;

use File::Temp qw(tempfile);
use FindBin;
my $dir = $FindBin::RealBin;

my $file = "$dir/2nn6.dom";

# Read all domains from a dom file
open my $fh, "<$file";
my $iofh = new SBG::AssemblyIO(-fh=>$fh);
my $assem = $iofh->read;
is($assem->size, 9, "Read in " . $assem->size . " domains");

# Write domains
my $outfile = "${file}.copy";
my $ioout = new SBG::AssemblyIO(-file=>">$outfile");
ok($ioout && $ioout->fh, "new(-file=>\">$outfile\")");
ok($ioout->write($assem), "Writing: $outfile :");
system("cat $outfile");
ok(unlink($outfile), "Removing $outfile");

# Test pdbc
my $domio = pdbc('2nn6');
my $assemio = new SBG::AssemblyIO(-fh=>$domio->fh);
my $pdbcassem = $assemio->read;
is($assem->size, 9, "DomainIO::pdbc(2nn6): " . $assem->size . " domains");


__END__









