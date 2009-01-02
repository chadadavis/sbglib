#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::Domain;
use SBG::DomainIO;
use SBG::Transform;
use SBG::CofM;

# Locally computed transform

my $d2uzeA = pdbc('2uze', 'A')->next_domain();
my $d2okrA = pdbc('2okr', 'A')->next_domain();

# Get transform to superimpose 2uzeA onto 2okrA
my $transtxt = `../bin/transform.sh 2uzeA 2okrA`;
my $trans = new SBG::Transform(-file=>$transtxt);

# Transform 2uzeC using transformation from 2uzeA => 2okrA
# i.e. Put 2uzeC into 2okrA's frame of reference
my $d2uzeC = pdbc('2uze', 'C')->next_domain();
get_cofm($d2uzeC);

print "d2uzeC:$d2uzeC:\n";
$d2uzeC->transform($trans);
print "d2uzeC:$d2uzeC:\n";

# Test PDL::IO::Storable :
use Storable;
use PDL::IO::Storable;
use File::Temp qw(tempfile);
my (undef, $tempfile) = tempfile;
store $trans, $tempfile;
my $fresh = retrieve $tempfile;
is ($fresh->matrix, $trans->matrix, "PDL::Matrix is Storable");


# Fetching a transform from DB/cache/compute
TODO: { 

#     ok(0, "Test fetching from DB cache");

    # Test invert()

}
