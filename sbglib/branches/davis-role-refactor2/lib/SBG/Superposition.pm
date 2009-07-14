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


with 'SBG::Role::Dumpable';
with 'SBG::Role::Scorable';
with 'SBG::Role::Storable';
with 'SBG::Role::Transformable';


use Scalar::Util qw/refaddr/;


# STAMP score fields
our @stats = qw/Sc RMS len nfit seq_id sec_id q_len d_len n_sec n_equiv/;
has \@stats => (
    is => 'rw',
    );


=head2 isid

If this is the identity superposition of a domain onto itself

=cut
has 'isid' => (
    is => 'rw',
    isa => 'Bool',
    );


=head2 to

The domain defining the frame of reference

=cut
has 'to' => (
    is => 'rw',
    does => 'SBG::DomainI',
    );


=head2 from

The domain superpositioned onto the reference domain, containing a
transformation.

Also handles B<transformation> via L<SBG::DomainI>

=cut
has 'from' => (
    is => 'rw',
    does => 'SBG::DomainI',
    handles => [ qw/transformation/ ],
    );


################################################################################
=head2 identity

 Function: Represents the transformation of a domain onto itself
 Example : my $id = SBG::Superposition::identity($some_domain);
 Returns : new L<SBG::Superposition>
 Args    : L<SBG::DomainI>

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
        to => $dom,
        from => $dom,
        isid=> 1,
        Sc  => 10,
        RMS => 0,
        seq_id => 100,
        sec_id => 100,
        );
    return $self;
};


################################################################################
=head2 transform

 Function: 
 Example : $self->transform($some_4x4_PDL_matrix);
 Returns : $self (not a new instance)
 Args    : L<PDL> Affine transformation matrix (See L<SBG::Transform::Affine>)

Required by L<SBG::Role::Transformable>

See also: L<SBG::DomainI>

=cut
sub transform {
    my ($self,$matrix) = @_;
    # Transform the underlying 'from' domain's transformation. The 'to' domain
    # is the reference domain, it remains unchanged.
    $self->from()->transform($matrix);
    return $self;
} # transform


###############################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


