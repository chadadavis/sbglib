#!/usr/bin/env perl

=head1 NAME

SBG::Domain::Crosshairs - Represents 7-points around a centre of mass

=head1 SYNOPSIS

 use SBG::Domain::Crosshairs;

=head1 DESCRIPTION

7-point Centre-of-mass

The C-alphas of Alanine residues,
1: X+5 , X-5
2: Y+5 , Y-5
3: Z+5 , Z-5

Using affine transforms, it's straight-forward to transform all 7 CA atoms from
the seven Alanine residues in one matrix multiplication. 

=head1 SEE ALSO

L<SBG::DomainI> , L<SBG::Domain>

=cut

################################################################################

package SBG::Domain::Crosshairs;
use Moose;
use MooseX::StrictConstructor;

extends qw/SBG::Domain::CofM/;

with qw/
SBG::Role::Storable
SBG::Role::Dumpable
SBG::DomainI
/;

use overload (
    fallback => 1,
    );


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
use SBG::U::Log; # imports $logger
use SBG::Run::cofm qw/cofm/;


################################################################################
# Fields and accessors


=head2 matrix

For saving cross-hair atoms: additionaly six atoms around centre-of-mass

=cut
has 'matrix' => (
    is => 'rw',
    isa => 'PDL::Matrix',
    );


################################################################################
# Public methods


################################################################################
=head2 crosshairs

 Function: Resets crosshair atoms around current centre of mass
 Example : 
 Returns : 
 Args    : $relativeto Another domain to which crosshairs are relative



=cut
sub crosshairs {
    my ($self,$relativeto) = @_;
    $self->matrix(_crosshairs($self->centre));
    return $self->matrix;

} # crosshairs


################################################################################
=head2 rmsd

 Function: 
 Example : 
 Returns : 
 Args    : 

Each column of matrix is a point in 3D
=cut
override 'rmsd' => sub {
    my ($self, $other) = @_;

    # Vector of (squared) distances between the corresponding 7 points
    my $sqdistances = $self->sqdist($other);
    return sqrt(average($sqdistances));
}; # rmsd


################################################################################
=head2 sqdist

 Function: Squared deviation(s) between points of one object vs those of another
 Example : 
 Returns : L<PDL::Matrix> vector of length N, if each object has N points
 Args    : 

NB if you want this as regular Perl array, do ->list() on the result:

 my $sq_deviations = $dom->sqdist($otherdom);
 my @array = $sq_deviations->list();

=cut
override 'sqdist' => sub {
    my ($self, $other) = @_;

    # Vector of (squared) distances between the corresponding points
    return sumover(($self->matrix - $other->matrix)**2);

}; # sqdist


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

    # Transform cross-hairs, if any
    $self->matrix($newtrans->transform($self->matrix)) if defined $self->matrix;

    # Update cumulative transformation. Managed by parent 'transform()' function
    # Also updates 'centre'
    super();

    return $self;
};


################################################################################
# Private



sub _crosshairs {
    my ($centre) = @_;
    # TODO DES consider making this the radius
    # Should partners of a homologous interface also be the same radius?
    my $size = 5;

    # The fourth dimension is because we use homogenous coordinates
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

