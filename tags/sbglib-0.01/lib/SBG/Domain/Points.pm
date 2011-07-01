#!/usr/bin/env perl

=head1 NAME

SBG::Domain::Points - Represents L<SBG::Domain> as N 3D-points

=head1 SYNOPSIS

 use SBG::Domain::Points;

=head1 DESCRIPTION

Using affine transforms, it's straight-forward to transform all points in one
matrix multiplication.

=head1 SEE ALSO

L<SBG::DomainI> , L<SBG::Domain>

=cut

################################################################################

package SBG::Domain::Points;
use Moose;
use MooseX::StrictConstructor;

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


################################################################################
# Fields and accessors


=head2 matrix

For saving atom coordinates

=cut
has 'matrix' => (
    is => 'rw',
    isa => 'PDL::Matrix',
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

    # TODO find PDB file and load coordinates, based on descriptor given

} # load


################################################################################
=head2 rmsd

 Function: Alias to L<dist>
 Example : 
 Returns : 
 Args    : 

Each column of matrix is a point in 3D

TODO BUG assumes both objects have same number of points

=cut
sub rmsd {
    my ($self, $other) = @_;

    # Vector of (squared) distances between the corresponding points
    my $sqdistances = $self->sqdev($other);
    return sqrt(average($sqdistances));

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

    $self->matrix($newtrans->transform($self->matrix)) if defined $self->matrix;

    # Update cumulative transformation. Managed by parent 'transform()' function
    super();

    return $self;
};


################################################################################
# Private



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


################################################################################
__PACKAGE__->meta->make_immutable;
1;

