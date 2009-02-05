#!/usr/bin/env perl

=head1 NAME

SBG::Sphere - Represents a structure as sphere, around a centre point

=head1 SYNOPSIS

 use SBG::Sphere;

=head1 DESCRIPTION

Uses affine coordinates, to simplifiy application of transformations down to a
single matrix multiplication.

All coordinates and lengths are unitless.

=head1 SEE ALSO

L<SBG::RepresentationI> , L<SBG::Domain> , L<SBG::CofM>

=cut

################################################################################

package SBG::Sphere;
use Moose;
use Moose::Util::TypeConstraints;

with qw(SBG::Storable);
with qw(SBG::Dumpable);
with qw(SBG::RepresentationI);

use overload (
    '""' => '_asstring',
    '==' => '_equal',
    fallback => 1,
    );

use PDL::Lite;
use PDL::Ufunc;
use PDL::Math;
use PDL::Matrix;
use Math::Trig qw(:pi);
use Scalar::Util qw(refaddr);
# List::Util::min conflicts with PDL::min Must be fully qualified to use
use List::Util; # qw(min); 

use SBG::Transform;


################################################################################
# Fields and accessors


# Define own subtype to enable type coersion. 
subtype 'PDL3' => as "PDL::Matrix";

coerce 'PDL3'
    => from 'ArrayRef' => via { mpdl [@$_,1] }
    => from 'Str' => via { mpdl ((split)[0..2], 1) };


=head2 centre

 Title   : centre
 Usage   : $sphere->centre([12.2343, 66.122, 233.122]); # set XYZ
 Function: Accessor for 'centre' field, which is an L<PDL::Matrix>
 Example : 
 Returns : New value of 'centre' field.
 Args    : L<PDL::Matrix> - optional, new centre point to be assigned

Always defined. Default: (0,0,0).

The L<PDL::Matrix> is a 1x4 affine matrix (i.e. the last cell is always
1.0). This is maintained internally.

=cut
has 'centre' => (
    is => 'rw',
    isa => 'PDL3',
    coerce => 1,
    required => 1,
    default => sub { [0,0,0] },
    );


=head2 radius

Radius of sphere (e.g. radius of gyration (an avg) or maximum radius)
=cut
has 'radius' => (
    is => 'rw',
    isa => 'Num',
    );


=head2 transformation

The cumulative transformation, resulting from all applied L<SBG::Transform>s. To
apply an L<SBG::Transform>, call L<transform>.

=cut
has 'transformation' => (
    is => 'rw',
    isa => 'SBG::Transform',
    coerce => 1,
    required => 1,
    default => sub { new SBG::Transform },
    );


################################################################################
# Public methods


################################################################################
=head2 asarray

 Title   : asarray
 Usage   : my @xyz = $s->asarray();
 Function: Converts internal centre ('centre' field) to a 3-tuple
 Example : print "X,Y,Z: " . $s->asarray() . "\n";
 Returns : 3-Tuple (X,Y,Z)
 Args    : NA

=cut
sub asarray {
    my ($self) = @_;
    return unless defined $self->centre;
    my @a = 
        ($self->centre->at(0,0), 
         $self->centre->at(0,1), 
         $self->centre->at(0,2),
        ); 
    return @a;
}


################################################################################
=head2 dist

 Title   : dist
 Usage   : my $linear_distance = $s1->dist($s2);
 Function: Positive distance between centres of two L<SBG::Sphere>s
 Example : 
 Returns : Euclidean distance between $s1->centre and $s2->centre
 Args    : L<SBG::Sphere> - Other sphere to measure distance to.

Distance between this Sphere and some other, measured from their centres

=cut
sub dist { 
    my ($self, $other) = @_;
    my $sqdist = $self->sqdist($other);
    return unless $sqdist;
    return sqrt($sqdist);
} # dist


################################################################################
=head2 sqdist

 Title   : sqdist
 Usage   :
 Function:
 Example :
 Returns : 
 Args    : L<SBG::Sphere> - Other sphere to measure distance to.

Squared distance between two spheres.

=cut
sub sqdist {
    my ($self, $other) = @_;
    my $selfc = $self->centre;
    my $otherc = $other->centre;
    return unless $selfc->dims == $otherc->dims;
    $logger->trace("$self - $other");
    # Vector diff
    my $diff = $selfc - $otherc;
    # Remove dimension 0 of 2D-matrix, producing a 1-D vector
    # And remove the last field (just a 1, for affine multiplication)
    $diff = $diff->slice('(0),0:2');
    my $squared = $diff ** 2;
    my $sum = sumover($squared);
    return $sum;
}


################################################################################
=head2 transform

 Title   : transform
 Usage   : $s->transform($some_transformation);
 Function: Applyies given transformation to the centre, transforming it
 Example : $s->transform($some_transformation);
 Returns : $self
 Args    : L<SBG::Transform>

Apply a new transformation to this spheres centre.

If you simply want to access the current cumulative transformation saved in this
object, use L<transformation>.

=cut
sub transform {
    my ($self, $newtrans) = @_;
    return $self unless defined($newtrans) && defined($self->centre);
    # Need to transpose row vector to a column vector first. 
    # Then let Transform do the work.
    my $newcentre = $newtrans->transform($self->centre->transpose);
    # Transpose back
    $self->centre($newcentre->transpose);

    # Update the cumulative transformation
    my $prod = $newtrans * $self->transformation;
    $self->transformation($prod);

    return $self;
}


################################################################################
=head2 volume

 Title   : volume
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
sub volume {
    my ($self) = @_;
    return (4.0/3.0) * pi * $self->radius ** 3;
}



################################################################################
=head2 capvolume

 Title   : capvolume
 Usage   :
 Function:
 Example :
 Returns : 
 Args    : depth: how deep the slicing plane sits within the sphere

Volume of a cap of the Sphere. Calculates integral to get volume of sphere's
cap. Thee cap is the shape created by slicing off the top of a sphere using a
plane.

The depth is the length of a line, perpendicular to the slicing plane, to the
surface of the sphere.

http://www.russell.embl.de/wiki/index.php/Collision_Detection

http://www.ugrad.math.ubc.ca/coursedoc/math101/notes/applications/volume.html

=cut
sub capvolume {
    my ($self, $depth) = @_;
    return pi * ($depth**2 * $self->radius - $depth**3 / 3.0);
}


################################################################################
=head2 overlap

 Title   : overlap
 Usage   : my $linear_overlap = $s1->overlap($s2);
 Function: Similar to L<dist>, but considers the radius also
 Example : my $linear_overlap = $s1->overlap($s2);
 Returns : Positive: linear overlap along line connecting centres of spheres
           Negative: linear distance between surfaces of spheres
 Args    : Another L<SBG::Sphere>

Unlike L<SBG::Sphere::dist>, this function considers the B<radius> of the
spheres.

E.g. if two spheres centres are 5 units apart and their radii are 3 and 4,
respectively, then the overlap will be 3+4-5=2 and this is the length along the
line connecting the centres that is within both spheres.

=cut 
sub overlap { 
    my ($self, $other) = @_;
    # Distance between centres
    my $dist = $self->dist($other);
    # Radii of two spheres
    my $sum_radii = ($self->radius + $other->radius);
    # Overlaps when distance between centres < sum of two radii
    my $diff = $sum_radii - $dist;
    $logger->debug("$diff overlap on ($self) and ($other)");
    return $diff;
}


################################################################################
=head2 overlaps

 Title   : overlaps
 Usage   : $s1->overlaps($s2, 20.5);
 Function: Whether two spheres overlap, beyond an allowed threshold [0:1]
 Example : if($s1->overlaps($s2,.55)) { print "Overlaps by at least 55\%\n"; }
 Returns : true if L<overlap> exceeds given threshold
 Args    : L<SBG::Sphere> 
           thresh - default 0

Threshold is a fraction of the maximum possible overlap, which is the diameter of
the smaller sphere.

=cut
sub overlaps {
    my ($self, $obj, $thresh) = @_;
    if ($self->_equal($obj)) {
        $logger->info("Identical spheres overlap");
        return 1;
    }
    $thresh ||= 0;
    my $minradius = List::Util::min($self->radius(), $obj->radius());

    my $overlapfrac = 
        $self->overlap($obj) / (2 * $minradius);

    return $overlapfrac > $thresh;
}


################################################################################
=head2 voverlap

 Title   : voverlap
 Usage   :
 Function:
 Example :
 Returns : Positive: volume of overlap between spheres
           Negative: distance between surfaces of non-overlapping spheres
 Args    :

If two spheres overlap, this is the volume of the overlapping portions.

If two spheres do not overlap, the absolute value of the negative number
returned is how far apart the surfaces of the two spheres are.

=cut
sub voverlap {
    my ($self, $obj) = @_;
    # Linear overlap (sum of radii vs dist. between centres)
    my $c = $self->overlap($obj);

    # Special cases: no overlap, or completely enclosed:
    if ($c < 0 ) {
        # If distance is negative, there is no overlapping volume
        return $c;
    } elsif ($c + $self->radius < $obj->radius) {
        # $self is completely within $obj
        return $self->volume();
    } elsif ($c + $obj->radius < $self->radius) {
        # $obj is completely within $self
        return $obj->volume();
    }

    my ($a, $b) = ($self->radius, $obj->radius);
    # Need to find the plane (a circle) of intersection between spheres
    # Law of cosines to get one angle of triangle created by intersection
    my $alpha = acos( ($b**2 + $c**2 - $a**2) / (2 * $b * $c) );
    my $beta  = acos( ($a**2 + $c**2 - $b**2) / (2 * $a * $c) );

    # The *length* of $obj that is inside $self
    my $overb;
    # The *length* of $self that is inside $obj
    my $overa;
    # Check whether angles are acute to determine length of overlap
    if ($alpha < pi / 2) {
        $overb = $b - $b * cos($alpha);
    } else {
        $overb = $b + $b * cos(pi - $alpha);
    }
    if ($beta < pi / 2) {
        $overa = $a - $a * cos($beta);
    } else {
        $overa = $a + $a * cos(pi - $beta);
    }

    # These volumes only count what is beyond the intersection plane
    # (i.e. this is *not* double counting) 
    # Volume of sb inside of sa:
    my $overbvol = $obj->cap($overb);
    # Volume of sa inside of sb;
    my $overavol = $self->cap($overa);
    # Total overlap volume
    my $sum = $overbvol + $overavol;
    $logger->debug("$sum overlap on ($self) and ($obj)");
    return $sum;

} # voverlap


################################################################################
=head2 voverlaps

 Title   : voverlaps
 Usage   :
 Function:
 Example :
 Returns : 
 Args    : fraction: fraction of max possible overlap tolerated, default 0

Does the volume of the overlap exceed given fraction of the max possible volume
overlap. The max possible volume overlap is simply the volume of the smaller
sphere (this occurs when the smaller sphere is completely contained within the
larger sphere).

=cut
sub voverlaps {
    my ($self, $obj, $fracthresh) = @_;
    $fracthresh ||= 0;
    if ($self->_equal($obj)) {
        $logger->info("Identical domain, overlaps");
        return 1;
    }
    my $overlapfrac = 
        $self->voverlap($obj) / List::Util::min($self->volume(),$obj->volume());
    return $overlapfrac > $fracthresh;
}


################################################################################
# Private


################################################################################
=head2 _asstring

 Title   : _asstring
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
sub _asstring {
    my ($self) = @_;
    my @a = ($self->asarray, $self->radius);
    return sprintf("(%10.5f,%10.5f,%10.5f,%10.5f)", @a);
} # _asstring


# Are two spheres equal
# This includes centre and radius
sub _equal {
    my ($self, $other) = @_;
    return 0 unless defined $other;
    return 1 if refaddr($self) == refaddr($other);
    return 0 unless $self->radius == $other->radius;
    return 0 unless all($self->centre == $other->centre);

    return 1;
}


################################################################################
__PACKAGE__->meta->make_immutable;
1;

