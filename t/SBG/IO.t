#!/usr/bin/env perl

use Test::More 'no_plan';
use feature 'say';

use File::Temp qw(tempfile);
use SBG::IO;
use FindBin qw/$Bin/;

my $io = new_ok "SBG::IO";

# Open a not-yet-opened file
my $file = "$Bin/2nn6.dom";

my $iofile = new SBG::IO(file=>"<$file");

ok($iofile && $iofile->fh, "new(file=>\"<$file\")");
ok($iofile->close, "close()");

# Open an already-opened filehandle
open my $fh, "<$file";
ok($fh, "Opening <$file first");
my $iofh = new SBG::IO(fh=>$fh);
is($iofh->fh, $fh, "Filehandle reused");
ok($iofh && $iofh->fh, "new(fh=>\$fh)");

# Writing to tempfile using tempfile option
$io = new SBG::IO(tempfile=>1);
$io->write("Writing via tempfile=>1 option");
$io->flush;
$file = $io->file;
ok(-s $file, "Tempfile ($file) not empty");

# Test writing temp file, using file handle
my ($tfh1, $tpath1) = tempfile();
my $io1 = new SBG::IO(fh=>$tfh1);
$io1->write("Writing to temp file handle ( $tpath1 )");
$io1->flush;
ok(-s $tpath1, "Writing to temp file handle ( $tpath1 )");

# Test writing temp file, using file path
my ($tfh2, $tpath2) = tempfile();
my $io2 = new SBG::IO(file=>">$tpath2");
$io2->write("Writing to temp file path ( $tpath2 )");
$io2->flush;
ok(-s $tpath2, "Writing to temp file path ( $tpath2 )");



__END__
