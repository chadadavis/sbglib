#!/usr/bin/env perl

=head1 NAME

SBG::Superposition - Represents L<SBG::Transform> between L<SBG::DomainI>
objects

=head1 SYNOPSIS

 use SBG::Superposition

=head1 DESCRIPTION


=head1 SEE ALSO

L<PDL::Transform> , L<SBG::Superposition::stamp> , L<SBG::DomainI>

http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

=cut

################################################################################

package SBG::Superposition;

use Moose;

with qw/
SBG::Role::Storable
SBG::Role::Dumpable
/;

use SBG::DomainI;
use SBG::Transform;


################################################################################
# Accessors



# STAMP score fields
our @keys = qw/Domain1 Domain2 Sc RMS Len1 Len2 Align Fit Eq Secs I S P/;

has \@keys => (
    is => 'rw',
    );


=head2 isid

Is identity transformation

=cut 
has 'isid' => (
    is => 'rw',
    );


=head2 transform

=cut
has 'transform' => (
    is => 'rw',
    isa => 'SBG::Transform',
    required => 1,
    );


=head2 reference

The domain defining the frame of reference

=cut
has 'reference' => (
    is => 'rw',
    does => 'SBG::DomainI',
    required => 1,
    );


has 'domains' => (
    is => 'rw',
    isa => 'ArrayRef[SBG::DomainI]',
    );



################################################################################
=head2 identity

 Function: Represents the transformation of a domain onto itself
 Example : my $id_trans = SBG::Transform::t_identity();
 Returns : L<SBG::Transform>
 Args    : NA

NB: The difference between this and just using C<new()>, which also uses and
identity transformation, is that this method explicitly sets the STAMP scores
for the transformation to their maximum values. I.e. this is to explicitly say
that one is transforming a domain onto itself and that the identity transform is
high-scoring. The C<new()> just uses the identity transform as a convenient
default and sets no scores on the transform.

=cut
sub identity {
    my $self = __PACKAGE__->new(
        isid=> 1,
        Sc  => 10,
        RMS => 0,
        I => 100,
        S => 100,
        P => 0,
        );
    return $self;
};


################################################################################
=head2 inverse

 Function: Returns the inverse of the given L<SBG::Transform>
 Example : my $newtransf = $origtrans->inverse;
 Returns : Returns the inverse L<SBG::Transform>, 
 Args    : L<SBG::Transform>

Does not modify the current transform. 

=cut
override 'inverse' => sub {
    my ($self) = @_;
    return $self if $self->isid();

    # The inverse PDL::Transform object, calls PDL::Transform::inverse(@_);
    my $transform = super();

    # Pack it in a SBG::Transform, copying constructing other (Moose) attributes
    my $class = ref $self;
    $self = $class->new(transform=>$transform, %$self);
    return $self;
};


################################################################################
=head2 relativeto

 Function: Aransformation of A (or $self), relative to B
 Example : my $A_relative_to_B = $A_transform->relativeto($B_transform);
 Returns : L<SBG::Transform>
 Args    : Two L<SBG::Transform>, i.e. $self an $some_other

Creates a new L<SBG::Transform> without modifying existing ones. I.e the result
is what A would be, in B's frame of reference, but B will not be modified. To
put many transformations into one frame of reference:

 my $refernce = shift @transforms;
 foreach (@transforms) {
    $_ = $_->relativeto($reference);
 }

NB this is the cumulative transformation, i.e. absolute

=cut
sub relativeto ($$) {
    my ($self, $ref) = @_;
    # Always apply transform on the left
    my $t = $ref->inverse x $self;
    return $t;

} # relativeto


################################################################################
=head2 compose

 Function:
 Example :
 Returns : 
 Args    :

Matrix composition.

NB 'after' is not sufficient, becuase the return value of
PDL::Transform::compose needs to be re-bless'd

=cut
override 'compose' => sub {
    my ($self, $other) = @_;
    @_ = ($self, $other);
    # Don't waste time multiplying identities
    return $self unless defined($other);
    return $self if $other->isid;
    return $other if $self->isid;

    # Call the parent's compose() on the same arguments
    my $prod = super();
    my $class = ref $self;
    return $class->new(transform=>$prod);

};


################################################################################
=head2 _equal

 Function:
 Example :
 Returns : 
 Args    :


=cut
sub _equal ($$) {
    my ($self, $other) = @_;
    return 0 unless defined($other);
    # Equal if neither has yet been set
    return 1 if $self->isid && $other->isid;
    return all($self->matrix == $other->matrix);
    return all($self->offset == $other->offset);
}


################################################################################
=head2 _pdl2homog

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub _pdl2homog {
    my ($self,) = @_;
    my $homog = zeroes 4,4;
    # Transpose the matrix in to row-major order as well
    $homog->slice('0:2,0:2') .= $self->matrix->transpose;
    $homog->slice('3,0:2') .= $self->offset->transpose;
    $homog->slice('3,3') .= 1;
    return $homog;

}


################################################################################
=head2 _homog2pdl

 Function: 
 Example : 
 Returns : 
 Args    : PDL of 4x4, homogenous, in row-major order

=cut
sub _homog2pdl {
    my ($homog,) = @_;
    # Convert back from row-major to PDL's col-major
    my $mat = $homog->slice('0:2,0:2')->transpose;
    # And squeeze transposed matrix into a 1-D vector
    my $offset = $homog->slice('3,0:2')->transpose->squeeze;
    # Transpose the matrix back to PDL's col-major order
    my $obj = __PACKAGE__->new(matrix=>$mat, post=>$offset);
    return $obj;

} 


################################################################################
=head2 compose_all

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub compose_all {
    my ($self,) = @_;

    my $transforms = $self->{'params'}{'clist'};
    my $homogenous = $transforms->map(sub { _pdl2homog($_)});
    my $prod = reduce { $a x $b } @$homogenous;
    my $pdl = _homog2pdl($prod);
    return $pdl;

} # compose_all


###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;


