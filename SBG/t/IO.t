#!/usr/bin/env perl

use Test::More 'no_plan';

use File::Temp qw(tempfile);

use SBG::IO;

my $io = new SBG::IO;
ok(defined $io, "new()");
isa_ok($io, "SBG::IO");

my $file = "$installdir/t/2nn6.dom";

# Open a not-yet-opened file
my $iofile = new SBG::IO(-file=>"<$file");
ok($iofile && $iofile->fh, "new(-file=>\"<$file\")");
ok($iofile->close, "close()");

# Open an already-opened filehandle
open my $fh, "<$file";
ok($fh, "Opening <$file first");
my $iofh = new SBG::IO(-fh=>$fh);
is($iofh->fh, $fh, "Filehandle reused");
ok($iofh && $iofh->fh, "new(-fh=>\$fh)");


# Test writing temp file, using file handle
my ($tfh1, $tpath1) = tempfile();
my $io1 = new SBG::IO(-fh=>$tfh1);
$io1->write("Writing to temp file handle ( $tpath1 )");
$io1->flush;
ok(-s $tpath1, "Writing to temp file handle ( $tpath1 )");

# Test writing temp file, using file handle
my ($tfh2, $tpath2) = tempfile();
my $io2 = new SBG::IO(-file=>">$tpath2");
$io2->write("Writing to temp file handle ( $tpath2 )");
$io2->flush;
ok(-s $tpath2, "Writing to temp file handle ( $tpath2 )");


__END__
