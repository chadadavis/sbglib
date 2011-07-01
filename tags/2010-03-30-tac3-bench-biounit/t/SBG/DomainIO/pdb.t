#!/usr/bin/env perl

use Test::More 'no_plan';
use Carp;
use Data::Dumper;
use Data::Dump qw/dump/;
use FindBin qw/$Bin/;


use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test qw/float_is pdl_approx/;

use SBG::DomainIO::pdb;
my $file = "$Bin/../data/1timA.pdb";


# Read all atoms:
my $io = new SBG::DomainIO::pdb(file=>"<$file",atom_type=>'.');
my $dom = $io->read;
# Number of records (2nd dimension, i.e. number of rows in matrix)
is($dom->coords->dim(1), 1870, "Reading all atoms");


# Read CA atoms
$io->atom_type('CA');
my $dom2 = $io->read;
is($dom2->coords->dim(1), 247, "Reading all CA atoms");


# Read CG atoms (including CG1, CG2, etc)
$io->atom_type('CG');
my $dom3 = $io->read;
is($dom3->coords->dim(1), 216, "Reading all CG* atoms");


# Read only CG1 atoms
$io->atom_type('CG1');
my $dom4 = $io->read;
is($dom4->coords->dim(1), 40, "Reading all CG1 atoms");


# Write 
use SBG::Domain;
my $dom5 = new SBG::Domain(pdbid=>'1tim',descriptor=>'CHAIN A');
my $io5 = new SBG::DomainIO::pdb(tempfile=>1);
$io5->write($dom5);
my $cmd = "grep -c '^ATOM' " . $io5->file;
my $res = `$cmd`;
chomp $res;
is($res, 1870, "Written domain in PDB format contains all atoms");


