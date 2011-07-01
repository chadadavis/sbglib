#!/usr/bin/env perl

=head1 NAME

SBG::Superposition - Represents a pair of L<DomainI>, superpositioned

=head1 SYNOPSIS

 use SBG::Superposition

=head1 DESCRIPTION

'scores' can contain 

 Sc RMS len nfit seq_id sec_id q_len d_len n_sec n_equiv

=head1 SEE ALSO

L<SBG::TransformI> , L<SBG::DomainI>

=cut

################################################################################

package SBG::Superposition;
use Moose;


with 'SBG::Role::Dumpable';
with 'SBG::Role::Scorable';
with 'SBG::Role::Storable';
with 'SBG::Role::Transformable';


use overload (
    '""' => 'stringify',
    );

use Scalar::Util qw/refaddr/;
use Moose::Autobox;


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
        scores => {
        isid=> 1,
        Sc  => 10,
        RMS => 0,
        seq_id => 100,
        sec_id => 100,
        },
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


################################################################################
=head2 apply

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub apply {
    my ($self,@objs) = @_;
    $self->transformation->apply(@objs)

} # apply



################################################################################
=head2 inverse

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub inverse {
    my ($self,) = @_;
    my $class = ref $self;
    my $copy = $class->new(%$self);

    # If it's just the identity, don't change anything
    return $copy if $self->isid;

    my $from = $copy->from->clone;
    my $to = $copy->to->clone;
    # The Transforms are the inverse of one another
    $to->transformation($from->transformation->inverse);
    # Swap
    $copy->to($from);
    $copy->from($to);
    # And update alignment lengths
    $copy->scores->put('q_len', $self->scores->at('d_len'));
    $copy->scores->put('d_len', $self->scores->at('q_len'));

    return $copy;

} # inverse


################################################################################
=head2 stringify

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub stringify {
    my ($self,) = @_;
    return '' . $self->transformation;

} # stringify


###############################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;


