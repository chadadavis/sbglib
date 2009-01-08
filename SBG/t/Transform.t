#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::Domain;
use SBG::DomainIO;
use SBG::Transform;
use SBG::CofM;

my $trans = new SBG::Transform();

# Test PDL::IO::Storable :
use Storable;
use PDL::IO::Storable;
use File::Temp qw(tempfile);
my (undef, $tempfile) = tempfile;
store $trans, $tempfile;
my $fresh = retrieve $tempfile;
is ($fresh->matrix, $trans->matrix, "PDL::Matrix is Storable");


# TODO Test fetching from DB cache


