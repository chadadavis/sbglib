#!/usr/bin/env perl

=head1 NAME

SBG::Domain::Sphere - Represents L<SBG::DomainI> as a sphere

=head1 SYNOPSIS

 use SBG::Domain::Sphere;


=head1 DESCRIPTION

The Sphere has a B<center> (a 4x1 L<PDL>) and a B<radius>. Its B<coords> (a 4x7
L<PDL>) contain 7 points: 1 centroid, followed by one additional point in each
direction of each dimension. I.e. +X, -X, +Y, -Y, +Z, -Z, each of which is
B<radius> away from the B<center>.


=head1 SEE ALSO

L<SBG::DomainI> , L<SBG::U::RMSD>

=cut

################################################################################

package SBG::Domain::Sphere;
use Moose;

with (
    'SBG::DomainI',
    );


# NB methods provided by DomainI
use overload (
    '""' => 'stringify',
    '==' => 'equal',
    fallback => 1,
    );


use PDL::Core qw/pdl zeroes/;
use Math::Trig qw/:pi acos_real/;
use List::Util; # qw/min/; # min() clashes with PDL::min
use Log::Any qw/$log/;


################################################################################
=head2 center

 Function: 
 Example : 
 Returns : 
 Args    : A L<PDL> of dimension 4 (row vector) or 4x1 (matrix of one row)

Initial center point

Can subsequently be accessed via L<centroid>

Read-only (can be set from constructor)

NB not possible to set a trigger on 'coords' because it's an attribute from a
Role and therefore composed, not inherited.

=cut
has 'center' => (
    is => 'rw',
    isa => 'PDL',
    required => 1,
    default => sub { pdl [[0,0,0,1]] },
    );


################################################################################
=head2 radius

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has 'radius' => (
    is => 'rw',
    isa => 'Num',
    default => 0,
    );


################################################################################
=head2 _hair_len

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has '_hair_len' => (
    is => 'ro',
    isa => 'Num',
    default => 5,
    );


sub _build_coords {
    my ($self) = @_;

    my $c;
    my $coords;
    my $dims; 
    if ($self->has_coords) {
        # Use curent center
        $c = $self->centroid;
        $dims = $c->dim(0);
        $coords = $self->coords;
    } else {
        # Use center that was passed as argument
        $c = $self->center->squeeze;
        $dims = $c->dim(0);
        $coords = zeroes($dims, 7);
    }

    my $x = zeroes $dims;
    my $y = zeroes $dims;
    my $z = zeroes $dims;

    my $r = $self->_hair_len;
    # Fill in just X coord
    $x->slice('0') .= $r;
    # Fill in just Y coord
    $y->slice('1') .= $r;
    # Fill in just Z coord
    $z->slice('2') .= $r;

    # Center, followed by X +/- offset, Y +/- offset, Z +/- offset
    $coords .= pdl [ $c, $c+$x, $c-$x, $c+$y, $c-$y, $c+$z, $c-$z ];

    return $coords;
}


################################################################################
=head2 centroid

 Function: 
 Example : 
 Returns : 
 Args    : 

requied by L<DomainI>

=cut
sub centroid {
    my ($self,) = @_;
    # NB 'center' is only the starting center, not kept up to date
    # NB this is column major indexing, i.e. 0th row of coords
    return $self->coords->slice(',0')->squeeze;

} # centroid


################################################################################
=head2 overlap

 Function: 
 Example : 
 Returns : 
 Args    : 

B<'required'> by L<SBG::DomainI>

Just aliases L<overlap_lin> for now

=cut
sub overlap {
    overlap_lin_frac(@_);
}


################################################################################
=head2 overlap_lin

 Function: Linear overlap between two spheres, considering the radius 
 Example : my $linear_overlap = $s1->overlap_lin($s2);
 Returns : Positive: linear overlap along line connecting centres of spheres
           Negative: linear distance between surfaces of spheres
 Args    : Another L<SBG::Domain::Sphere>

Unlike L<SBG::Sphere::dist>, this function considers the B<radius> of the
spheres.

E.g. if two spheres centres are 5 units apart and their radii are 3 and 4,
respectively, then the overlap will be 3+4-5=2 and this is the length along the
line connecting the centres that is within both spheres.

The maximum possible overlap is twice the radius of the smaller sphere.

=cut
sub overlap_lin { 
    my ($self, $other) = @_;
    # Distance between centres
    my $dist = SBG::U::RMSD::rmsd($self->centroid, $other->centroid);
    # Radii of two spheres
    my $sum_radii = ($self->radius + $other->radius);
    # Overlaps when distance between centres < sum of two radi
    my $diff = $sum_radii - $dist;
    # Max possible overlap: twice the smaller radius
    my $max = 2 * List::Util::min($self->radius, $other->radius);
    $diff = $max if $diff > $max;
    $log->debug(
        "overlap: $diff dist: $dist radii: $sum_radii on ($self) vs ($other)");
    return $diff;
} # overlap_lin


################################################################################
=head2 overlap_lin_max

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub overlap_lin_max {
    my ($self, $other) = @_;
    # Max possible overlap: twice the smaller radius
    my $max = 2 * List::Util::min($self->radius, $other->radius);
    return $max;

} # overlap_lin_max


################################################################################
=head2 overlap_lin_frac

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub overlap_lin_frac {
    my ($self, $other) = @_;
    my $max = 2 * List::Util::min($self->radius, $other->radius);
    my $overlap = $self->overlap_lin($other);
    my $frac = 1.0 * $overlap / $max;
    $log->debug(sprintf "%0.3f ($self) and ($other)", $frac);
    return $frac;

} # overlap_lin_frac



################################################################################
=head2 volume

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

 Function:
 Example :
 Returns : 
 Args    : depth: how deep the slicing plane sits within the sphere

Volume of a cap of the Sphere. Calculates integral to get volume of sphere's
cap. The cap is the shape created by slicing off the top of a sphere using a
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
=head2 overlap_vol

 Function: volume-based overlap measure
 Example :
 Returns : Positive: volume of overlap between spheres
           Negative: distance between surfaces of non-overlapping spheres
 Args    :

If two spheres overlap, this is the volume of the overlapping portions.

If two spheres do not overlap, the absolute value of the negative number
returned is the length of the shortest line between the surfaces of the two
spheres.


=cut
sub overlap_vol {
    my ($self, $obj) = @_;

    # Special cases: no overlap, or completely enclosed:
    my $lin = overlap_lin($self, $obj);
    if ($lin < 0 ) {
        # If distance is negative, there is no overlapping volume
        return $lin;
    } elsif ($lin == 2 * $self->radius) {
        # $self is completely within $obj
        return $self->volume();
    } elsif ($lin == 2 * $obj->radius) {
        # $obj is completely within $self
        return $obj->volume();
    }

    my ($a, $b) = ($self->radius, $obj->radius);
    # Need to find the plane (a circle) of intersection between spheres
    # Law of cosines to get one angle of triangle created by intersection
    my $alpha = acos_real( ($b**2 + $lin**2 - $a**2) / (2 * $b * $lin) );
    my $beta  = acos_real( ($a**2 + $lin**2 - $b**2) / (2 * $a * $lin) );

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
    my $overbvol = $obj->capvolume($overb);
    # Volume of sa inside of sb;
    my $overavol = $self->capvolume($overa);
    # Total overlap volume
    my $sum = $overbvol + $overavol;
    $log->debug("$sum overlap between ($self) and ($obj)");
    return $sum;

} # overlap_vol


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

