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




package SBG::TransformI;
use Moose::Role;


with 'SBG::Role::Clonable';
with 'SBG::Role::Dumpable';
with 'SBG::Role::Storable';
with 'SBG::Role::Transformable';
with 'SBG::Role::Writable';


# NB this is not carried into implementing classes.
# It is here as a suggestion of what you should be overloading
# use overload (
#     'x'  => \&mult, 
#     '!'  => \&inverse, 
#     '==' => \&equals,
#     '""' => \&stringify,
#     fallback => 1,
#     );


use Module::Load;



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
    # Allows objects to be used as native PDL types, via the 'PDL' hash field
    trigger => sub { my ($self, $val) = @_; $self->{PDL} = $self->matrix; },
    );



=head2 _build_matrix

 Function: matrix constructor
 Example : Called automatically from new()
 Returns : L<PDL>
 Args    : NA

This method needs to be provided by implementing classes to initialize the
respective matrix.

=cut
requires '_build_matrix';




=head2 reset

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
requires 'reset';



=head2 apply

 Function: Applies this transformation to a given vector/matrix
 Example : my $new_vector = $this_transform->apply($vector)
 Returns : L<PDL> transformed object
 Args    : L<PDL> to be transformed by this transformation


=cut
requires 'apply';




=head2 mult

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
requires 'mult';



=head2 inverse

 Function: Inverse of this transformation matrix
 Example : my $inv = $this_transform->inverse();
 Returns : new instance of L<SBG::TransformI>
 Args    : NA


=cut
requires 'inverse';



=head2 equals

 Function: True when transformation matrices are equivalent
 Example : if ($transform_a->equal($transform_b) { ... }
 Returns : Bool
 Args    : L<SBG::TransformI>


=cut
requires 'equals';


# Implicitly thread-safe: cloning (i.e. threading) is disallowed. 
# This prevents double free bugs. Spawned thread only has undef references then.
# See man perlmod
sub CLONE_SKIP { 1 }



=head2 relativeto

 Function: 
 Example : 
 Returns : 
 Args    : 

C = B x A

C x A^-1 = B x A x A^-1

C x A^-1 = B

Given C (self) and A, solves for B transformation

=cut
sub relativeto {
    my ($self,$other) = @_;

    return $self x $other->inverse;

} # relativeto


###############################################################################
no Moose::Role;
1;


