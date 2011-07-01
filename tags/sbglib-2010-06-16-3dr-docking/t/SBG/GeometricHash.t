#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';

use Data::Dumper;
use Data::Dump qw/dump/;
use File::Temp qw/tempfile/;
use Carp;
$SIG{__DIE__} = \&confess;

use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";

use SBG::U::Log;

my $DEBUG;
# $DEBUG = 1;
SBG::U::Log::init(undef, loglevel=>'DEBUG') if $DEBUG;




use PDL::Lite;
use PDL::Core;
use PDL::Basic qw/sequence/;
use PDL::Primitive qw/random/;
use PDL::Ufunc;
use PDL::Transform;
use PDL::NiceSlice;

use SBG::GeometricHash;

my $gh;
my $points;
my $labels;

# Test points along axes
$gh = new SBG::GeometricHash(binsize=>1);
# Some 3D Points
my $origin = pdl([ 0,0,0, 1]);
my $ox = pdl([ 5,0,0, 1]);
my $oy = pdl([ 0,5,0, 1]);
my $oz = pdl([ 0,0,5, 1]);
# NB testing single points in axis is problematic if X==Y==0
$points = [ $origin, $ox, $oy];

$gh->put("newmodel0", $points);

$points = [ $oy, $ox, $origin];
is ($gh->class($points), 'newmodel0', 'permuted order');
$points = _perm($points);
is ($gh->class($points), 'newmodel0', 'permutated order and rotated');


# Test points not on axes
$gh = new SBG::GeometricHash(binsize=>1);
my $a = pdl([ 1.11,2.22,4.44, 1 ]);
my $b = pdl([ 2.22,3.33,5.55, 1 ]);
my $c = pdl([ 5.55,3.33,9.99, 1 ]);
my $d = pdl([ 6.66,7.77,4.44, 1 ]);
$points = [$origin, $a, $b, $c];
# Associate simple labels to the points
$gh->put("newmodel1", $points, [qw/o a b c/]);
# Anonymous points
$points = [$b, $c, $d, $a];
$gh->put("newmodel2", $points);


# Test exact() must match full size of hashed model
isnt ($gh->exact([$a,$b,$c]), 'newmodel2', "A subset won't match exactly");
is ($gh->exact([$d,$b,$c,$a]), 'newmodel2', "Full set will match exactly");


# No transformation, no labels
is ($gh->class([$origin, $a, $b, $c]), 'newmodel1', "No trans, w/o labels");


# No transformation, but labels must match
is ($gh->class([$b, $origin, $a], [qw/b o a/]), 'newmodel1', "No trans w/ labels");


# Match a model not at origin
is ($gh->class([$d, $a, $b]), 'newmodel2', "No trans, non-centered");


# Test transformaing objects in space and still retrieving
$points = [ $c, $b, $origin]; # Should hit "newmodel1 3 2 0"
$points = _perm($points);
is ($gh->class($points), 'newmodel1', 
    "Non-axis points, rotated");

is ($gh->class($points, [qw/c b o/]), 'newmodel1', 
    "Non-axis points, rotated, w/ labels");

# print "Full covers: ", $gh->exists([$c, $a, $b]), "\n";


# Test with multiple points per 'object' in a model
$gh = new SBG::GeometricHash(binsize=>1);

my $obj1 = _rand_obj(2,3);
my $obj2 = _rand_obj(2,3);
my $obj3 = _rand_obj(2,3);

# Put it in, with labels for each point taken from label for each object
$points = [ $obj1, $obj2, $obj3 ];
$labels = [ qw/thing1 thing2 thing3/ ];
my ($objpoints, $objlabels);
# Break down into single points, expand to apply object labels to each point
($objpoints, $objlabels) = _put_objs($points, $labels);
$gh->put("Multi-point", $objpoints, $objlabels);

# Jumble it up
$points = _perm($points);
($objpoints, $objlabels) = _put_objs($points, $labels);

# Take it back out
is ($gh->class($objpoints), 'Multi-point', 
    "Model with multi-point objects, unlabelled");


# Test that label applies to each point in an object
is ($gh->class($objpoints, $objlabels), 'Multi-point', 
    "Model with multi-point objects, labelled");




# A matrix of random points (row-major, i.e. one row = one point
# Will add a final column of 1's if homogenous, default
sub _rand_obj {
    my ($rows, $cols, $limit, $homog) = @_;
    $limit ||= 100;
    $homog = 1 unless defined $homog;
    my $x = $limit * random($cols+$homog, $rows);
    $x->slice('3,') .= 1 if $homog;
    return $x;
}


# Assumes a PDL, not PDL::Matrix
sub _put_objs {
    my ($objs, $labels) = @_;

    my @points;
    my @pointlabels;
    for (my $i = 0; $i < @$objs; $i++) {
        my $o = $objs->[$i];
        my $dim;
        if ($o->isa('PDL::Matrix')) {
            # Row-major indexing
            $dim = $o->dim(0);
            push(@points, $o->slice("$_,")->squeeze) for (0..$dim-1);
        } else {
            # Column-major indexing
            $dim = $o->dim(1);
            push(@points, $o->slice(",$_")->squeeze) for (0..$dim-1);
        }
        push @pointlabels, (($labels->[$i]) x $dim);
    }
    return [ @points ], [ @pointlabels ]; 
}


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


    # Don't use list, might be a matrix coming in, not just single point
#     $points = [ map { $t->apply(pdl($_->list)) } @$points ];
    # Seems to be no difference with or without squeeze
#     $points = [ map { $t->apply(pdl [$_])->squeeze } @$points ];
    $points = [ map { $t->apply(pdl [$_]) } @$points ];

#     print STDERR "after transf:\n", join(',',@$points), "\n";

    # These are now regular piddles and not matrix piddles, but OK for testing
    return $points;
}


