#!/usr/bin/env perl

=head1 NAME

SBG::Superposition - Represents a pair of L<DomainI>, superpositioned

=head1 SYNOPSIS

 use SBG::Superposition

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::TransformI> , L<SBG::ContainerI> , L<SBG::DomainI>

=cut

################################################################################

package SBG::Superposition;
use Moose;

with qw/
SBG::Role::Storable
SBG::Role::Dumpable
SBG::Role::Clonable
SBG::Role::Transformable
/;


use Scalar::Util qw/refaddr/;


# STAMP score fields
our @keys = qw/Domain1 Domain2 Sc RMS Len1 Len2 Align Fit Eq Secs I S P/;
has \@keys => (
    is => 'rw',
    );


=head2 reference

The domain defining the frame of reference

=cut
has 'reference' => (
    is => 'rw',
    does => 'SBG::DomainI',
    );


=head2 superpositioned

The domain superpositioned onto the reference domain

=cut
has 'superpositioned' => (
    is => 'rw',
    does => 'SBG::DomainI',
    );


=head2 isid

If this is the identity superposition of a domain onto itself

=cut
has 'isid' => (
    is => 'rw',
    isa => 'Bool',
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
    my ($dom) = @_;
    my $self = __PACKAGE__->new(
        reference => $dom,
        superpositioned => $dom,
        isid=> 1,
        Sc  => 10,
        RMS => 0,
        I => 100,
        S => 100,
        P => 0,
        );
    return $self;
};


###############################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


