#!/usr/bin/env perl

use Test::More 'no_plan';
# use SBG::Test 'float_is';
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

# Some 3D Points
my $origin = mpdl([ 0,0,0, 1])->transpose;
my $a = mpdl([ 1.11,2.22,4.44, 1 ])->transpose;
my $b = mpdl([ 2.22,3.33,5.55, 1 ])->transpose;
my $c = mpdl([ 5.55,3.33,9.99, 1 ])->transpose;

my $gh = new SBG::GeometricHash(binsize=>.1);
$gh->put("newmodel1", $origin, $a, $b, $c);
$gh->put("newmodel2", $b, $c, $a);

say Dumper $gh;

my %h;
%h = $gh->at($origin, $a, $b, $c);
say Dumper \%h;

%h = $gh->at($origin, $a, $b);
say Dumper \%h;

%h = $gh->at($origin, $a, $c);
say Dumper \%h;

%h = $gh->at($c, $b, $origin, $a);
say Dumper \%h;

say $gh->exists($b, $c);

say "done";

__END__

my ($d0, $d1) = $m->dims;
$d0--;
$m->dims() = ($d0, $d1);
# $m->reshape($d0, $d1);
say "m", $m;

__END__

check($m);



# Basis points define a vector to be transformed
my $b0 = $m(,0);
my $b1 = $m(,1);


# Vector from $b0 to $b1
my $diff = $b1 - $b0;
my $dist = dist($diff)
say "scale from dist:$dist";

# Angles of rotation from coordinates axes, in degrees

my $ryz = 60; # about x axis
my $rzx = 45; # about y axis
my $rxy = 0; # about z axis

# A Linear transformation, including translation, scaling, rotation
my $t = t_linear(dims=>3,
                 pre=>zeroes(3)-$b0,   # translation, s.t. b0 moves to origin
                 scale=>1/$dist, # scale, s.t. vector $b0 -> $b1 is length 1
                 rot=>[$ryz, $rzx, $rxy], # rotation about 3 axes
    );
                 
# Transform by the basis transformation
my $n = $t->apply($m);
say "n", $n;
check($n);

say "Done";


################################################################################

sub check {
    my ($mat) = @_;
    my $a = $mat(,0);
    my $b = $mat(,1);
    my $c = $mat(,2);

    say "length: ", dist($a,$b);
    say "a=>b:", ($b-$a)->norm;
    say "a=>c:", ($c-$a)->norm;
    say "b=>c:", ($c-$b)->norm;
 
}

# Vector length, Euclidean
sub vlen {
    # Square root of the sum of the squared coords
    return sqrt sumover($_[0]**2)->sclr;
}

# If $other not given, the origin (0,0,0) is assumed
sub sqdist {
    my ($selfc, $otherc) = @_;
    $otherc = zeroes(3) unless defined($otherc);
    # Vector diff
    my $diff = $selfc - $otherc;
    my $squared = $diff ** 2;
    # Squeezing allows this to work either on column or row vectors
    my $sum = sumover($squared->squeeze);
    # Convert to scalar
    return $sum->sclr;
}

sub dist {
    return sqrt(sqdist(@_));
}
