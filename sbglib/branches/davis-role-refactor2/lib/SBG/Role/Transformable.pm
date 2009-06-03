#!/usr/bin/env perl

=head1 NAME

SBG::Role::Transformable - Anything that can be transformed by L<SBG::TransformI>

=head1 SYNOPSIS

with 'SBG::Role::Transformable';

# Matrix is an affine transformation matrix with homogenous coordinates.
# I.e. it is 4x4 whereby the last row is : 0,0,0,1
sub transform {
    my ($self, $matrix) = @_;
    my $type = ref $self;
    # Transpose before and after, if your data is in row-major order
    my $transformed = ($matrix x $self->points()->transpose())->transpose;
    # Create a new instance of you object, if desired
    $self = $type->new($transformed);
    # Or udpate some attribute
    $self->points($transformed);
    return $self;
}
    
=head1 DESCRIPTION

An role for identifying objects capable of being transformed geometrically

=head1 SEE ALSO

L<Clone>

=cut

################################################################################

package SBG::Role::Transformable;
use Moose::Role;


################################################################################
=head2 transform

 Function: Apply the given transformation matrix to this object
 Example : my $transformed = $my_object->transform($transformation_matrix)
 Returns : transformed object
 Args    : Affine transformation matrix (PDL) with homogenous coordinates

The matrix is 4x4, whereby the last row is : 0,0,0,1

The 3x3 rotation matrix can be extracted with

 my $rot3x3 = $mat->slice('0:2,0:2');

The 3x1 translation vector can be extracted as column vector with:

 my $transl = $mat->slice('3,0:2');

Or as a one-dimensional PDL with:

 my $transl = $mat->slice('3,0:2')->squeeze;

Or as a Perl array with:

 my $transl = $mat->slice('3,0:2')->list;

=cut
requires 'transform';


################################################################################
no Moose::Role;
1;


