#!/usr/bin/env perl

=head1 NAME

SBG::Domain::CofM - Represents a structure as a sphere around a centre-of-mass

=head1 SYNOPSIS

 use SBG::Domain::CofM;

=head1 DESCRIPTION

7-point Centre-of-mass

The C-alphas of Alanine residues,
1: X+5 , X-5
2: Y+5 , Y-5
3: Z+5 , Z-5

Using affine transforms, it's straight-forward to transform all 7 CA atoms from
the seven Alanine residues in one matrix multiplication. 

=head1 SEE ALSO

L<SBG::RepresentationI> , L<SBG::Domain>

=cut

################################################################################

package SBG::Domain::CofM;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

extends qw/SBG::Domain/;

with qw(SBG::Storable);
with qw(SBG::Dumpable);
with qw(SBG::RepresentationI);

use overload (
    '""' => '_asstring',
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


=head2 matrix

For saving cross-hair atoms around centre-of-mass

=cut
has 'matrix' => (
    is => 'rw',
    isa => 'PDL::Matrix',
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

# TODO DES don't actually need this yet
#     $self->matrix(_crosshairs($self->centre));

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

    # Vector of (squared) distances between the corresponding 7 points
#     my $sqdistances = $self->sqdev($other);
#     return sqrt(average($sqdistances));

}

################################################################################
=head2 sqdev

 Function: Squared deviation(s) between points of one object vs those of another
 Example : 
 Returns : L<PDL::Matrix> vector of length N, if each object has N points
 Args    : 

NB if you want this as regular Perl array, do ->list() on the result:

 my $sq_deviations = $dom->sqdev($otherdom);
 my @array = $sq_deviations->list();

=cut
sub sqdev {
    my ($self, $other) = @_;

    # Vector of (squared) distances between the corresponding points
    return sumover(($self->matrix - $other->matrix)**2);

} # sqdev



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

# Don't need to maintain this, only relevant when relative to true structure
#     $self->matrix($newtrans->transform($self->matrix));

    # Update cumulative transformation. Managed by parent
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

Threshold is a fraction of the maximum possible overlap, which is the diameter of
the smaller sphere.

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
=head2 _asstring

 Function:
 Example :
 Returns : 
 Args    :


=cut
# override '_asstring' => sub {
#     my ($self) = @_;
#     my @a = ($self->asarray, $self->radius);
#     # Prepend stringification of parent first
#     return sprintf("%s(%10.5f,%10.5f,%10.5f,%10.5f)", super(), @a);
# };


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
=head2 _atom2pdl

 Function: 
 Example : 
 Returns : L<PDL::Matrix> of dim Nx4. Fourth is all '1' for homogenous coords
 Args    : 

Parses ATOM lines and converts to nx3-dimensional L<PDL::Matrix>

Any lines not beginning wth ATOM are skipped.

E.g.:

 ATOM      0  CA  ALA Z   0   80.861  12.451 122.080  1.00 10.00
 ATOM      1  CA  ALA Z   1   85.861  12.451 122.080  1.00 10.00
 ATOM      1  CA  ALA Z   1   75.861  12.451 122.080  1.00 10.00
 ATOM      2  CA  ALA Z   2   80.861  17.451 122.080  1.00 10.00
 ATOM      2  CA  ALA Z   2   80.861   7.451 122.080  1.00 10.00
 ATOM      3  CA  ALA Z   3   80.861  12.451 127.080  1.00 10.00
 ATOM      3  CA  ALA Z   3   80.861  12.451 117.080  1.00 10.00

31 - 38      Real(8.3)     x       Orthogonal coordinates for X in Angstroms.
39 - 46      Real(8.3)     y       Orthogonal coordinates for Y in Angstroms.
47 - 54      Real(8.3)     z       Orthogonal coordinates for Z in Angstroms.

=cut
sub _atom2pdl {
    my ($atomstr) = @_;
    my $io = new IO::String($atomstr);
    my @mat;
    for (my $i = 0; <$io>; $i++) {
        next unless /^ATOM/;
        my $str = $_;
        # Columns 31,39,47 tsore the 8-char coords (not necessarily separated)
        # substr() is 0-based
        my @xyz = map { substr($str,$_,8) } (30,38,46);
        # Append array with an arrayref of X,Y,Z fields (plus 1, homogenous)
        push @mat, [ @xyz, 1 ];
    }
    # Put points in columns
    return mpdl(@mat)->transpose;
}


sub _crosshairs {
    my ($centre) = @_;
    my $size = 5;
    # The fourth dimension is for homogenous coordinates
    # Since $centre is already homogenous, the resulting matrix will be too
    my $x = mpdl($size,0,0,0)->transpose;
    my $y = mpdl(0,$size,0,0)->transpose;
    my $z = mpdl(0,0,$size,0)->transpose;
    my $matrix = mpdl($centre, 
                      $centre+$x, $centre-$x,
                      $centre+$y, $centre-$y,
                      $centre+$z, $centre-$z,
        );
    # Don't need to transpose here, as these are already column vectors.
    # Just squeeze to remove extraneous dimensions
    return $matrix->squeeze;
}



################################################################################
__PACKAGE__->meta->make_immutable;
1;

