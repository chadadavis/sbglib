#!/usr/bin/env perl

=head1 NAME

SBG::Domain::CofMVol - A L<SBG::Domain::CofM> that does volume-based overlap

=head1 SYNOPSIS

 use SBG::Domain::CofMVol;

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::RepresentationI> , L<SBG::Domain::CofM> , L<SBG::Domain>

=cut

################################################################################

package SBG::Domain::CofMVol;
use Moose;
use MooseX::StrictConstructor;

extends 'SBG::Domain::CofM';

with qw(SBG::Storable);
with qw(SBG::Dumpable);
with qw(SBG::RepresentationI);

# TODO not all necessary in child class

# TODO test if overload inherited
# use overload (
#     '""' => '_asstring',
#     '==' => '_equal',
#     fallback => 1,
#     );

use Math::Trig qw(:pi);
# List::Util::min conflicts with PDL::min Must be fully qualified to use
use List::Util; # qw(min); 

use SBG::Log; # imports $logger


################################################################################
# Public methods


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

 Function: volume-based overlap measure
 Example :
 Returns : Positive: volume of overlap between spheres
           Negative: distance between surfaces of non-overlapping spheres
 Args    :

If two spheres overlap, this is the volume of the overlapping portions.

If two spheres do not overlap, the absolute value of the negative number
returned is how far apart the surfaces of the two spheres are.

=cut
override 'overlap' => sub {
    my ($self, $obj) = @_;
    # Linear overlap (sum of radii vs dist. between centres)
    # (What parent class would have measured)
    my $c = super();

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

}; # overlap


################################################################################
=head2 overlaps

 Function:
 Example :
 Returns : 
 Args    : fraction: fraction of max possible overlap tolerated, default 0

Does the volume of the overlap exceed given fraction of the max possible volume
overlap. The max possible volume overlap is simply the volume of the smaller
sphere (this occurs when the smaller sphere is completely contained within the
larger sphere).

=cut
override 'overlaps' => sub {
    my ($self, $obj, $fracthresh) = @_;
    $fracthresh ||= 0;
    if ($self == $obj) {
        $logger->info("Identical domain, overlaps");
        return 1;
    }
    my $overlapfrac = 
        $self->overlap($obj) / List::Util::min($self->volume(),$obj->volume());
    return $overlapfrac > $fracthresh;
};


################################################################################
=head2 evaluate

 Function:
 Example :
 Returns : 
 Args    :

To what extent is $self a good approximation/representation of $obj.
0 is worst, 1 is best

# TODO test voverlap()

=cut
sub evaluate {
    my ($self,$obj) = @_;

    my $overlapfrac = 
        $self->overlap($obj) / List::Util::min($self->volume(),$obj->volume());
    return $overlapfrac;

} # evaluate


################################################################################
__PACKAGE__->meta->make_immutable;
1;

