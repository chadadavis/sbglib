#!/usr/bin/env perl

=head1 NAME

SBG::Transform::Affine - An affine transformation matrix (4x4), using homogenous
coordinates.

=head1 SYNOPSIS

 use SBG::Transform::Affine

=head1 DESCRIPTION

Use simple matrix multiplication to combine transformations linearly.

=head1 SEE ALSO

L<SBG::TransformI>

=cut

################################################################################

package SBG::Transform::Affine;
use Moose;

with qw/
SBG::TransformI
/;


use overload (
    'x'  => 'apply', 
    '!'  => 'inverse', 
    '==' => 'equals',
    '""' => 'stringify',
    );

use PDL::MatrixOps qw/identity/;
use PDL::Ufunc qw/all/;
use PDL::Core qw/approx/;
use PDL::Basic qw/transpose/;

# To be Storable
use PDL::IO::Storable;



################################################################################
=head2 BUILD

 Function: 
 Example : 
 Returns : 
 Args    : 

Hook (hack) to make 'PDL' hash field alias the 'matrix' field. 

Allows objects to be used as native PDL types

=cut
sub BUILD {
    my ($self) = @_;
    $self->{PDL} = $self->{matrix};
}


################################################################################
=head2 _build_matrix

 Function: 
 Example : 
 Returns : 
 Args    : 

The 4x4 homogenous transformation matrix. Created only when needed.

The fourth row is simply [ 0,0,0,1 ] , as required by homogenous coordinates.

=cut
sub _build_matrix { 
    return identity(4);
}


################################################################################
=head2 inverse

 Function: Returns the inverse of the given L<SBG::Transform::Affine>
 Example : my $newtransf = $origtrans->inverse;
 Returns : Returns the inverse L<SBG::Transform::Affine> as a new instance
 Args    : NA

=cut
sub inverse {
    my ($self) = @_;
    return $self unless $self->has_matrix;
    my $class = ref $self;
    return $class->new(matrix=>$self->matrix->inv);
}


################################################################################
=head2 apply

 Function: Applies this transformation matrix to some L<PDL::Matrix>
 Example : my $transformed = $trans x $some_matrix;
           my $transformed = $trans x $some_vector;
 Returns : A 4xn L<PDL> (e.g. a row vector, when given a row vector as input)
 Args    : 4xn L<PDL>

Apply this transform to some point, or even a matrix (affine multiplication)

NB You do not need to transpose() row vectors. This method does that already,
and transposes them back to row vectors before returning them.

=cut
sub apply {
    my ($self, $other) = @_;
    return $other unless $self->has_matrix;

    # If it implements an interface, check which one
    if ($other->can('does') && $other->does('SBG::Role::Transformable')) {
        # Ask the object to transform itself, given our transformation matrix
        return $other->transform($self->matrix);
    } else {
        # Just try native PDL multiplication, assuing it's a homogenous piddle 
        return transpose($self->matrix x transpose $other);
    }
}


################################################################################
=head2 transform

 Function: Transform self by the given transformation matrix
 Example : 
 Returns : 
 Args    : 

Required by L<Role::Transformable>

NB In the matrix multiplication, self is on the right here, since self is being
transformed by the given transformation matrix

=cut
sub transform {
    my ($self,$mat) = @_;
    my $prod = $self->has_matrix ? $mat x $self->matrix : $mat;
    my $type = ref $self;
    return $type->new(matrix=>$prod);

} # transform


################################################################################
=head2 equals

 Function:
 Example :
 Returns : 
 Args    :


=cut
sub equals {
    my ($self, $other) = @_;
    # Don't compare identities
    return 1 unless $self->has_matrix || $other->has_matrix;
    # Unequal if exactly one is defined
    return 0 unless $self->has_matrix && $other->has_matrix;
    # Compare homogoneous 4x4 matrices, cell-by-cell
    return all(approx($self->matrix,$other->matrix));
}


################################################################################
=head2 stringify

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub stringify {
    my ($self) = @_;
    my $mat = $self->has_matrix ? $self->matrix : "";
    return "$mat";
}

###############################################################################
__PACKAGE__->meta->make_immutable;
1;

