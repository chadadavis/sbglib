#!/usr/bin/env perl

use Test::More;
use FindBin qw/$Bin/;

use PDL::Lite;
use PDL::Core qw/pdl/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::U::Test qw/pdl_approx/;

use SBG::Domain::Atoms;
use SBG::DomainIO::stamp;


# Check expected number of atoms in a chain
my $dom1 = new SBG::Domain::Atoms(
    pdbid=>'1tim',descriptor=>'CHAIN A', atom_type=>'....');
is($dom1->coords->dim(1), 1870, "Loading all atoms of a chain");


# Check expected coords of a chain, (where there's no transform)
my $first_atom = pdl [[ 43.24, 11.99, -6.915 ]];
pdl_approx($dom1->coords->slice('0:2,0'), $first_atom, "Coords of first AA");


# Load a modelw with multiple domains, some with transformations
my $file = "$Bin/data/model.dom";
my $io = new SBG::DomainIO::stamp(
    file=>"<$file", objtype=>'SBG::Domain::Atoms');
# By default only CA coords
my @doms2 = $io->read;
is(@doms2, 6, "Read in " . scalar(@doms2) . " domains, array context");


# Verify untransformed domain
my $dom2_2 = $doms2[2];
is($dom2_2->coords->dim(1), 260, "Counting CA atoms in untransfromed domain");
my $first_ca_native = pdl [ [ -36.978 , -23.399 , -33.582 ] ];
pdl_approx($dom2_2->coords->slice('0:2,0'), $first_ca_native,
           "Verifying coords of untransformed CA");


# Verify a transformed domain
my $dom2_0 = $doms2[0];
is($dom2_0->coords->dim(1), 241, "Counting CA atoms in transfromed domain");
my $first_ca_trans = pdl [ [ -20.709 , -68.236 , -33.582 ] ];
pdl_approx($dom2_0->coords->slice('0:2,0'), $first_ca_trans,
           "Verifying coords of transformed CA");


$TODO = "Test provide specific 'residues'";
ok(0);

done_testing();
