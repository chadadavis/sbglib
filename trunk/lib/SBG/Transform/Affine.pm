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

package SBG::Transform::Affine;
use Moose;

with('SBG::TransformI',);

use overload (
    'x'      => 'mult',
    '!'      => 'inverse',
    '=='     => 'equals',
    '""'     => 'stringify',
    fallback => 1,
);

use Module::Load;
#use Devel::Comments;
# use PDL::MatrixOps qw/identity/; # Broken diagonal() not a proper lvalue
use PDL::Ufunc qw/any/;
use PDL::Core;
use PDL::Basic qw/transpose/;

use SBG::U::RMSD qw/identity/;

# To be Storable
use PDL::IO::Storable;

=head2 _build_matrix

 Function: 
 Example : 
 Returns : 
 Args    : 

The 4x4 homogenous transformation matrix. Created only when needed.

The fourth row is simply [ 0,0,0,1 ] , as required by homogenous coordinates.

=cut

sub _build_matrix {
    my ($self) = @_;
    my $mat = identity(4);

    # PDL is an alias to matrix
    $self->{PDL} = $mat;
    return $mat;
}

=head2 rotation

The rotational component of the transformation, a 3x3 matrix

=cut 

sub rotation {
    my ($self) = @_;
    my $m = $self->matrix;
    return $m->slice('0:2,0:2');
}

=head2 translation 

The translational component of the transformation, a 3x1 column vector

=cut

sub translation {
    my ($self) = @_;
    my $m = $self->matrix;

    # Column major order: 3rd column, rows 0,1,2
    return $m->slice('3,0:2');
}

=head2 reset

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub reset {
    my ($self,) = @_;
    $self->{PDL} = $self->{matrix} = identity(4);
}    # reset

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

    # Invert a copy
    my $inv = $self->matrix->copy->inv;
    return $class->new(matrix => $inv);
}

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
    }
    else {

        # Just try native PDL multiplication, assuing it's a homogenous piddle
        return transpose($self->matrix x transpose $other);
    }
}

=head2 mult

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub mult {
    my ($self, $other) = @_;
    return $other unless $self->has_matrix;

    my $prod = $self->matrix x $other->matrix;
    my $type = ref $self;
    load($type);
    return $type->new(matrix => $prod);

}    # mult

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
    my ($self, $mat) = @_;

    my $mymat = $self->matrix;
    my $prod  = $mat x $mymat;
    $mymat .= $prod;
    return $self;
}    # transform

=head2 equals

 if ($transform_a->equals($transform_b, '5%')) {
     print "Equal to within 5% (of the average)\n"
 }

The difference is measured relative to the element-wise abs(max(.)) of the two matrixes.

The default tolerance is 1%. Optionally a minimum absolute tolerance can be specified.

 $transform_a->equals($transform_b, '5%', 0.5);

This means up to 5% of the maximum absolute value of each cell, and if 5% is less than 0.5 in a cell, the 0.5 deviation from the maximum absolute value of that cell will still be tolerated. This is to address the complication of dealing with very small numbers.

=cut

sub equals {
    my ($self, $other, $tol, $tol_min) = @_;
    $tol = '1%' unless defined $tol;

    # Don't compare identities
    return 1 unless $self->has_matrix || $other->has_matrix;

    # Unequal if exactly one is defined
    return 0 unless $self->has_matrix && $other->has_matrix;

    # Compare homogoneous 4x4 matrices, cell-by-cell
    my ($mat1, $mat2) = ($self->matrix, $other->matrix);
    ### mat1 : "$mat1"
    ### $mat2 : "$mat2"
    # Element-wise max magnitude
    my $max = 
          $mat1 * (abs $mat1 >= abs $mat2)
        + $mat2 * (abs $mat2 >  abs $mat1);
    ### $max : "$max"
    # Absolute deviation
    my $diff = abs($mat1 - $mat2);
    ### $diff : "$diff"

    # If tolerance is given as percentage (of the max of the matrixes)
    # Note, a percentage is relative to each cell
    if ($tol =~ /(\d+)\%$/) {
        $tol = abs $max * $1 / 100.0;
        # Rounding (replace anything less than $tol_min with $tol_min
        $tol .= $tol * ($tol >= $tol_min) + $tol_min * ($tol < $tol_min);
    }
    else {
        # Each cell has the same tolerance for the deviation
        my $matrix = zeroes 4,4;
        # Element-wise assignment
        $matrix .= $tol;
        $tol = $matrix;
        # Now cell-wise deviations can be compared to this matrix
    }
    ### $tol : "$tol"
    my $mask = $diff > $tol;
    ### dif > tol : "$mask"
    return ! any($diff > $tol);
}


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


__PACKAGE__->meta->make_immutable;
no Moose;
1;

