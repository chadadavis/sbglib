#!/usr/bin/env perl

=head1 NAME

SBG::Domain::CofM - Represents a structure as a sphere around a centre-of-mass

=head1 SYNOPSIS

 use SBG::Domain::CofM;

=head1 DESCRIPTION

Centre-of-mass representation of a L<SBG::Domain>

=head1 SEE ALSO

L<SBG::DomainI> , L<SBG::Domain>

=cut

################################################################################

package SBG::Domain::CofM;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

extends qw/SBG::Domain/;

with qw(SBG::Storable);
with qw(SBG::Dumpable);
with qw(SBG::DomainI);

use overload (
    '==' => '_equal',
    fallback => 1,
    );

use IO::String;
use PDL::Lite;
use PDL::Core qw/list/;
use PDL::Ufunc; # for sumover()
use PDL::Math;
use PDL::Matrix;
use PDL::NiceSlice;

use Math::Trig qw(:pi);
# List::Util::min conflicts with PDL::min Must be fully qualified to use
use List::Util; # qw(min); 

use SBG::Transform;
use SBG::Log; # imports $logger
use SBG::Run::cofm qw/cofm/;


################################################################################
# Fields and accessors


# Define own subtype to enable type coersion. 
subtype 'PDL3' => as 'PDL::Matrix';


# In coercion, always append a 1 for affine matrix multiplication
# Transpose these row vector to column vectors, to allow transformation later
coerce 'PDL3'
    => from 'ArrayRef' => via { mpdl(@$_, 1)->transpose }
    => from 'Str' => via { mpdl((split)[0..2], 1)->transpose };



=head2 centre

 Function: Accessor for 'centre' field, which is an L<PDL::Matrix>
 Example : $sphere->centre([12.2343, 66.122, 233.122]); # set XYZ
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
Use L<radius_type> to determine whether maximum or radius of gyration is used

=cut
has 'radius' => (
    is => 'rw',
    isa => 'Num',
    required => 1,
    default => 0,
);


=head2 radius_type

Choose wither 'Rg' (radius of gyration) or 'Rmax' (maximum radius) is used by
the L<radius> method.

Default: 'Rg'

=cut
has 'radius_type' => (
    is => 'rw',
    isa => enum([qw/Rg Rmax/]),
    required => 1,
    default => 'Rg',
    );


################################################################################
# Public methods



################################################################################
=head2 BUILD

 Function: load centre-of-mass data into object, 
 Example :
 Returns : 
 Args    :


=cut
sub BUILD {
    my ($self,@args) = @_;
    return unless $self->pdbid && $self->descriptor;

    my $res = SBG::Run::cofm::cofm($self->pdbid, $self->descriptor) or return;

    # Fetch the radius according to the type chosen, then update radius attr
    $self->radius($res->{ $self->radius_type });
    $self->centre( [ $res->{Cx}, $res->{Cy}, $res->{Cz} ] );

} # load


################################################################################
=head2 rmsd

 Function: Alias to L<dist>
 Example : 
 Returns : 
 Args    : 

Each column of matrix is a point in 3D
=cut
sub rmsd {
    my ($self, $other) = @_;

    # Single-point (cofm) version
    return sqrt($self->sqdist($other));

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
    return unless defined($sqdist);
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
    # Element-wise diff
    my $diff = $selfc - $otherc;
    my $squared = $diff ** 2;
    # Squeezing allows this to work either on column or row vectors
    my $sum = sumover($squared->squeeze);
    # Convert to scalar
    return $sum->sclr;
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

NB This needs to be a column vector, to be transformed, otherwise, use transpose

=cut
override 'transform' => sub {
    my ($self, $newtrans) = @_;
    return $self unless 
        defined($newtrans) && defined($self->centre);

    $self->centre($newtrans->transform($self->centre));

    # Update cumulative transformation. Managed by parent 'transform()' function
    super();

    return $self;
};


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
    # Overlaps when distance between centres < sum of two radi

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

Threshold is a fraction of the maximum possible overlap, which is the diameter
of the smaller sphere.

=cut
sub overlaps {
    my ($self, $obj, $thresh) = @_;
    if ($self == $obj) {
        $logger->info("Identical domains overlap");
        return 1;
    }
    $thresh ||= 0;
    my $minradius = List::Util::min($self->radius(), $obj->radius());

    my $overlap = $self->overlap($obj);
    if ($overlap < -150) {
        $logger->warn(
            "$self is quite far ($overlap) from $obj. Still connected?");
    }
    my $overlapfrac = $overlap / (2 * $minradius);
    return $overlapfrac > $thresh;
}


################################################################################
=head2 evaluate

 Function:
 Example :
 Returns : 
 Args    :

To what extent is $self a good approximation/representation of $obj.
0 is worst, 1 is best

=cut
sub evaluate {
    my ($self,$obj) = @_;
    my $minradius = List::Util::min($self->radius(), $obj->radius());
    return unless $minradius;
    my $overlapfrac = 
        $self->overlap($obj) / (2 * $minradius);
    return $overlapfrac;

} # evaluate


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
    my @a = list $self->centre;
    # Remove the trailing '1' used for homogenous coords.
    pop @a;
    return @a;
}


################################################################################
# Private


################################################################################
=head2 _equal

 Function:
 Example :
 Returns : 
 Args    :

This includes centre and radius.

=cut
override '_equal' => sub {
    my ($self, $other) = @_;
    # Delegate to parent first
    return 0 unless super();
    return 0 unless $self->radius == $other->radius;
    return 0 unless all($self->centre == $other->centre);
    return 1;
};


################################################################################
__PACKAGE__->meta->make_immutable;
1;
