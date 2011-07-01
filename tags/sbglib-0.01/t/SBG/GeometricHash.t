#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
# use SBG::Test 'float_is';
use SBG::Log;
use Carp;
use Data::Dumper;
use FindBin;
use File::Temp qw/tempfile/;
my $dir = $FindBin::RealBin;
$, = ' ';

################################################################################

use PDL::Lite;
use PDL::Core;
use PDL::Basic qw/sequence/;
use PDL::Primitive qw/random/;
use PDL::Matrix;
use PDL::MatrixOps;
use PDL::Ufunc;
use PDL::Transform;
use PDL::NiceSlice;

use SBG::GeometricHash;

my $gh = new SBG::GeometricHash(binsize=>1);

# Some 3D Points
my $origin = mpdl([ 0,0,0, 1])->transpose;
my $ox = mpdl([ 5,0,0, 1])->transpose;
my $oy = mpdl([ 0,5,0, 1])->transpose;
my $oz = mpdl([ 0,0,5, 1])->transpose;

my $points;
# NB testing single points in axis is problematic if X==Y==0
$points = [ $origin, $ox, $oy];
$gh->put("newmodel0", $points);
$points = [ $oy, $ox, $origin];
is ($gh->class($points), 'newmodel0', 'permuted order');
$points = _perm($points);
is ($gh->class($points), 'newmodel0', 'permutated order, rotated');


my $a = mpdl([ 1.11,2.22,4.44, 1 ])->transpose;
my $b = mpdl([ 2.22,3.33,5.55, 1 ])->transpose;
my $c = mpdl([ 5.55,3.33,9.99, 1 ])->transpose;
my $d = mpdl([ 6.66,7.77,4.44, 1 ])->transpose;
$points = [$origin, $a, $b, $c];
# Associate simple labels to the points
$gh->put("newmodel1", $points, [qw/o a b c/]);
# Anonymous points
$points = [$b, $c, $d, $a];
$gh->put("newmodel2", $points);

# exact() must match full size of hashed model
isnt ($gh->exact([$a,$b,$c]), 'newmodel2', "Subset doesn't match exactly");
is ($gh->exact([$d,$b,$c,$a]), 'newmodel2', "Full set does match exactly");

# No transformation, no labels
is ($gh->class([$origin, $a, $b, $c]), 'newmodel1', "No trans, w/o labels");

# No transformation, but labels must match
is ($gh->class([$b, $origin, $a], [qw/b o a/]), 'newmodel1', "No trans w/ labels");

# Match a model not at origin
is ($gh->class([$d, $a, $b]), 'newmodel2', "No trans, non-centered");


$points = [ $c, $b, $origin]; # Should hit "newmodel1 3 2 0"
$points = _perm($points);
is ($gh->class($points), 'newmodel1', 
    "Non-axis points, rotated");

is ($gh->class($points, [qw/c b o/]), 'newmodel1', 
    "Non-axis points, rotated, w/ labels");

# print "Full covers: ", $gh->exists([$c, $a, $b]), "\n";


################################################################################

sub _perm {
    my ($points) = @_;
    # A Linear transformation, including translation, scaling, rotation
#     my $t_o = t_offset(zeroes 3);
    my $t_o = t_offset(pdl(2,3,4));

    # Some arbitrary rotations
    # Don't rotate around all axes, as the basis only uses two to define a ref
#     my $roty2x = t_rot([0,0,90], dims=>3);
    my $roty2x = t_rot([0,0,45], dims=>3);

#     my $rotx2z = t_rot([0,90,0], dims=>3);
    my $rotx2z = t_rot([0,45,0], dims=>3);

#     my $rotz2y = t_rot([90,0,0], dims=>3);
    my $rotz2y = t_rot([45,0,0], dims=>3);

    # Compose some transforms
    my $t = $rotx2z x $rotx2z x $roty2x x $rotz2y x $t_o;

#     print STDERR "before tranf:@$points\n";
    $points = [ map { $t->apply(pdl($_->list)) } @$points ];
#     print STDERR "after transf:@$points\n";

    # These are now regular piddles and not matrix piddles, but OK for testing
    return $points;
}

__END__

