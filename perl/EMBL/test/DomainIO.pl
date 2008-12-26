#!/usr/bin/env perl

use lib "../..";

use EMBL::DomIO;

my $file = shift or die;

open my $fh, "<$file" or die;

my $io = new EMBL::DomIO($fh);

while (my $dom = $io->next_dom) {
    print "DOM:\n", $dom->dom(), "\n";
}

