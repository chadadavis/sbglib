#!/usr/bin/env perl

use lib "../..";

use EMBL::AssemblyIO;
use EMBL::Assembly;

my $file = shift or die;

open my $fh, "<$file" or die;

my $io = new EMBL::AssemblyIO($fh);

# TODO BUG while doesn't work because $assem is not true. DEL stringify()
# while (my $assem = $io->next_assembly) {
my $assem = $io->next_assembly;

open my $out, ">copy.dom";

$io->write($assem, $out);


