#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp qw/tempfile/;

my $DEBUG;
# $DEBUG = 1;
$File::Temp::KEEP_ALL = $DEBUG;

use SBG::Domain;
use SBG::Role::Writable;
use SBG::DomainIO::stamp;

my $dom = SBG::Domain->new(pdbid=>'1tim', descriptor=>'CHAIN A');

# $dom->write('stamp');

my $file = $dom->write('stamp', tempfile=>1);
my $copy = SBG::DomainIO::stamp->new(file=>$file)->read;
is($copy, $dom, "Re-read Writable domain");




