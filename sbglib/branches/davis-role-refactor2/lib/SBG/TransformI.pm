#!/usr/bin/env perl

=head1 NAME

SBG::TransformI - Represents a transformation matrix 

=head1 SYNOPSIS

 package SBG::Transform::MyTransformImplementation;
 use Moose;
 with qw/SBG::TransformI/;


=head1 DESCRIPTION

An L<SBG::TransformI> can transform L<SBG::DomainI>s or L<SBG::ComplexI>s. It
is compatible with STAMP transformation matrices (3x4)

Fields cannot be changed once the transformation object has been created. All
operations, such as inversion and composition, return new transformation
objects.

Whether a matrix has been set (i.e. when it is not the identity) can be
determined via $transform->has_matrix(). This allows for noop shortcuts when
doing multiplication, inverse, stringification, etc.

=head1 SEE ALSO

L<SBG::TransformIO::stamp> , L<SBG::DomainI> , L<SBG::ComplexI>


=cut

################################################################################


package SBG::TransformI;
use Moose::Role;
use Moose::Util::TypeConstraints;

with qw/
SBG::Role::Storable
SBG::Role::Dumpable
SBG::Role::Clonable
SBG::Role::Transformable
/;


# NB this is not carried into implementing classes.
# It is here as a suggestion of what you should be overloading
use overload (
    'x'  => 'apply', 
    '!'  => 'inverse', 
    '==' => 'equals',
    '""' => 'stringify',
    );


################################################################################
=head2 matrix

 Function: 
 Example : 
 Returns : 
 Args    : 

The 4x4 homogenous transformation matrix

The fourth row is simply [ 0,0,0,1 ]

=cut
has 'matrix' => (
    is => 'ro',
    isa => 'PDL',
    lazy_build => 1,
    );


################################################################################
=head2 _build_matrix

 Function: matrix constructor
 Example : Called automatically from new()
 Returns : L<PDL>
 Args    : NA

This method needs to be provided by implementing classes to initialize the
respective matrix.

=cut
requires '_build_matrix';



################################################################################
=head2 apply

 Function: Applies this transformation to a given vector/matrix
 Example : my $new_vector = $this_transform->apply($vector)
 Returns : L<PDL> transformed object
 Args    : L<PDL> to be transformed by this transformation


=cut
requires 'apply';


################################################################################
=head2 inverse

 Function: Inverse of this transformation matrix
 Example : my $inv = $this_transform->inverse();
 Returns : new instance of L<SBG::TransformI>
 Args    : NA


=cut
requires 'inverse';


################################################################################
=head2 equals

 Function: True when transformation matrices are equivalent
 Example : if ($transform_a->equal($transform_b) { ... }
 Returns : Bool
 Args    : L<SBG::TransformI>


=cut
requires 'equals';


###############################################################################
no Moose::Role;
1;


