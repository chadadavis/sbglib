#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);

use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";

use SBG::IO;

# Open a not-yet-opened file
my $file = "$Bin/data/2nn6.dom";
my $iofile = new SBG::IO(file => $file);
ok($iofile && $iofile->fh, "new(file=>$file)");
ok($iofile->close, "close()");

# Open an already-opened filehandle
open my $fh, '<', $file;
ok($fh, "Opening $file first");
my $iofh = new SBG::IO(fh => $fh);
is($iofh->fh, $fh, "Filehandle reused");
ok($iofh && $iofh->fh, "new(fh=>\$fh)");

# Writing to tempfile using tempfile option
my $io = new SBG::IO(tempfile => 1);
$io->write("Writing via tempfile=>1 option");
$io->flush;
$file = $io->file;
ok(-s $file, "Tempfile ($file) not empty");

# Test writing temp file, using file handle
my ($tfh1, $tpath1) = tempfile();
my $io1 = new SBG::IO(fh => $tfh1);
$io1->write("Writing to temp file handle ( $tpath1 )");
$io1->flush;
$io1->close;

ok(-s $tpath1, "Writing to temp file handle ( $tpath1 )");

# Test writing temp file, using file path
my ($tfh2, $tpath2) = tempfile();
my $io2 = new SBG::IO(file => ">$tpath2");
$io2->write("Writing to temp file path ( $tpath2 )");
$io2->flush;
ok(-s $tpath2, "Writing to temp file path ( $tpath2 )");

# Test writing to a string
my $str;
my $iostring = SBG::IO->new(string => \$str);
$iostring->write("foo");
$iostring->flush;
is($str, 'foo', 'SBG::IO->new(string=>$str)');

# Test buffering a pipe
my $cmd = 'echo hello world';
open my $cmdfh, '-|', $cmd;
my $cmdio = SBG::IO->new(fh => $cmdfh);
ok(!$cmdio->reset, "pipe is not seek'able");

# Buffer it
$cmdio->buffer;
ok($cmdio->reset, "Buffered pipe => string is now seek'able");

# Test file indexing
my $texttoindex = "$Bin/data/texttoindex.txt";
my $ioindexed   = SBG::IO->new(file => $texttoindex);
my $index       = $ioindexed->index;
my $index3      = $ioindexed->index->[3];
$ioindexed->seek($index3);
my $thing = $ioindexed->read;
is($thing, '678', 'IOI::index');

done_testing;
