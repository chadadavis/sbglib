#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Debug;

use Test::More;
use Carp;
use File::Temp qw/tempfile/;

use SBG::Domain;
use SBG::Role::Writable;
use SBG::DomainIO::stamp;

my $dom = SBG::Domain->new(pdbid => '1tim', descriptor => 'CHAIN A');

# $dom->write('stamp');

my $file = $dom->write('stamp', tempfile => 1);
my $copy = SBG::DomainIO::stamp->new(file => $file)->read;
is($copy, $dom, "Re-read Writable domain");

done_testing;
