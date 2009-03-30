#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::Test 'float_is';
use feature 'say';
use Carp;
use Data::Dumper;
$, = ' ';

use SBG::ComplexIO;
use SBG::Complex;
use SBG::DomainIO;
use SBG::Domain::CofM;
use SBG::STAMP qw/pdbc/;

use File::Temp qw(tempfile);
use FindBin;
my $dir = $FindBin::RealBin;

my $file = "$dir/2nn6.dom";

# Read all domains from a dom file
open my $fh, "<$file";
my $iofh = new SBG::ComplexIO(fh=>$fh);
my $assem = $iofh->read;
is($assem->size, 9, "Read in " . $assem->size . " domains");

# Write domains
my $outfile = "${file}.copy";
my $ioout = new SBG::ComplexIO(file=>">$outfile");
ok($ioout && $ioout->fh, "new(file=>\">$outfile\")");
ok($ioout->write($assem), "Writing: $outfile :");
system("cat $outfile");
ok(unlink($outfile), "Removing $outfile");

# Test pdbc
my $domio = pdbc('2nn6');
my $assemio = new SBG::ComplexIO(fh=>$domio->fh);
my $pdbcassem = $assemio->read;
is($assem->size, 9, "DomainIO::pdbc(2nn6): " . $assem->size . " domains");

# Including transformations
my $io5 = new SBG::ComplexIO(file=>"$dir/model.dom");
my $comp = $io5->read;
my @transes;
foreach my $name ($comp->names) {
    my $dom = $comp->template($name);
    push(@transes, $dom->transformation) if $dom->transformation;
}
is(scalar(@transes), 4, "4/6 Domains have explicit transformation");

__END__









