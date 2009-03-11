#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
# use SBG::Test 'float_is';
use SBG::Log;
use feature 'say';
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

my $gh = new SBG::GeometricHash(binsize=>2);

# Some 3D Points
my $origin = mpdl([ 0,0,0, 1])->transpose;
my $ox = mpdl([ 5,0,0, 1])->transpose;
my $oy = mpdl([ 0,5,0, 1])->transpose;
my $oz = mpdl([ 0,0,5, 1])->transpose;

my $points;
# NB testing single points in axis is problematic if either 
# X and Y are both 0, or
# if X and Z are both 0
# $gh->put("newmodel0", [$origin, $ox]);
$points = [ $origin, $ox];
# is ($gh->class($points), 'newmodel0', 'ox');
$points = _perm($points);
# is ($gh->class($points), 'newmodel0', 'ox _perm');


my $a = mpdl([ 1.11,2.22,4.44, 1 ])->transpose;
my $b = mpdl([ 2.22,3.33,5.55, 1 ])->transpose;
my $c = mpdl([ 5.55,3.33,9.99, 1 ])->transpose;
my $d = mpdl([ 6.66,7.77,4.44, 1 ])->transpose;
$gh->put("newmodel1", [$origin, $a, $b, $c], [qw/o a b c/]);
# $gh->put("newmodel2", [$b, $c, $d, $a]);

# No transformation, no labels
# is ($gh->class([$origin, $a, $b, $c]), 'newmodel1', "Match without labels");

# No transformation, but labels must match
# is ($gh->class([$b, $origin, $a], [qw/b o a/]), 'newmodel1', "Match with labels");

# Match a model not at origin
# is ($gh->class([$d, $a, $b]), 'newmodel2', "Match non-centered without labels");

$points = [ $c, $b, $origin]; # Should hit "newmodel1 3 2"
is ($gh->class($points), 'newmodel1', "Pre-transform");

my $base = mpdl([ 0,0,10, 1 ])->transpose;
my $other1 = mpdl([  2.8, -6, -10.4 , 1 ])->transpose;
my $other2 = mpdl([ -0.4, -2,  -2.8 , 1 ])->transpose;
$points = [ $origin, $base, $other1, $other2];
is ($gh->class($points), 'newmodel1', "Quasi-transform");

# Rotate, scale, translate, then query
$points = _perm($points);
is ($gh->class($points), 'newmodel1', 
    "Match with transform, without labels");

# is ($gh->class($points, [qw/c b o/]), 'newmodel1', 
#     "Match with transform, with labels");

# say "Full covers: ", $gh->exists([$c, $a, $b]);


################################################################################

sub _perm {
    my ($points) = @_;
    # A Linear transformation, including translation, scaling, rotation
#     my $t_o = t_offset(zeroes 3);
    my $t_o = t_offset(pdl(2,3,4));
#     my $t_s = t_scale(1, dims=>3);
    my $t_s = t_scale(2.5, dims=>3);
    # Some arbitrary rotation about two axes
    # Don't rotate around all axes, as the basis only uses two to define a ref
#     my $roty2x = t_rot([0,0,90], dims=>3);
    my $roty2x = t_rot([0,0,45], dims=>3);
#     my $rotx2z = t_rot([0,90,0], dims=>3);
    my $rotx2z = t_rot([0,45,0], dims=>3);

    # Compose transforms
    # TODO BUG 
    # Why does rot2 have to be applied before rot ?
    my $t = $roty2x x $rotx2z;

    print STDERR "points:@$points\n";
    $points = [ map { $t->apply(pdl($_->list)) } @$points ];
    print STDERR "points:@$points\n";

    # These are now regular piddles and not matrix piddles, but OK for testing
    return $points;
}

__END__

