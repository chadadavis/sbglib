#!/usr/bin/env perl

=head1 NAME

SBG::Superposition - Represents a pair of L<DomainI>, superpositioned

=head1 SYNOPSIS

 use SBG::Superposition

=head1 DESCRIPTION

Stores the transformation matrix and scores associated with a structural alignment between two L<SBG::Domain> objects. If a domain has not been transfromed from its native location, then its transformation and the transformation of the superposition will be the same. However, if the domain had already been transformed to new relative location, these will be different.

The 'scores' attribute is a HashRef and may contain 

 Sc RMS len nfit seq_id sec_id q_len d_len n_sec n_equiv

=head1 SEE ALSO

For an explanation of the scores, see

 http://www.compbio.dundee.ac.uk/manuals/stamp.4.4/node36.html

L<SBG::TransformI> , L<SBG::DomainI>

=cut

package SBG::Superposition;
use Moose;

with qw(
    SBG::Role::Dumpable
    SBG::Role::Scorable
    SBG::Role::Storable
    SBG::Role::Transformable
    SBG::Role::Writable
);

use overload (
    '""'     => 'stringify',
    fallback => 1,
);

use Scalar::Util qw/blessed refaddr/;
use Moose::Autobox;

=head2 isid

If this is the identity superposition of a domain onto itself

=cut

has 'isid' => (
    is  => 'rw',
    isa => 'Bool',
);

=head2 to

The domain defining the frame of reference

=cut

has 'to' => (
    is   => 'rw',
    does => 'SBG::DomainI',
);

=head2 from

The domain superpositioned onto the reference domain, containing a
transformation.

=cut

has 'from' => (
    is   => 'rw',
    does => 'SBG::DomainI',
);

has 'transformation' => (
    is       => 'rw',
    does     => 'SBG::TransformI',
    handles  => [qw/matrix/],
    required => 1,
    default  => sub { new SBG::Transform::Affine },
);

=head2 identity

 Function: Represents the transformation of a domain onto itself
 Example : my $id = SBG::Superposition->identity($some_domain);
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
    my ($pkg, $dom) = @_;
    my $self = $pkg->new(
        to     => $dom,
        from   => $dom,
        scores => {
            isid   => 1,
            Sc     => 10,
            RMS    => 0,
            seq_id => 100,
            sec_id => 100,
        },
    );
    return $self;
}

=head2 transform

 Function: 
 Example : $self->transform($some_4x4_PDL_matrix);
 Returns : $self (not a new instance)
 Args    : L<PDL> Affine transformation matrix (See L<SBG::Transform::Affine>)

Required by L<SBG::Role::Transformable>

See also: L<SBG::DomainI>

=cut

sub transform {
    my ($self, $matrix) = @_;

    # Transform the underlying transformation.
    $self->transformation()->transform($matrix);

    # And the domains
    $self->from()->transform($matrix);
    $self->to()->transform($matrix);

    return $self;
}    # transform

=head2 apply

TODO take a list of objects to transform

=cut

sub apply {
    my ($self, $obj) = @_;
    $self->transformation->apply($obj)

}    # apply

=head2 inverse

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub inverse {
    my ($self,) = @_;
    my $class = blessed $self;
    my $copy;
    if ($self->isid) {

        # Use clone to keep separate copies of domain objects
        $copy = $class->identity($self->dom->clone);
    }
    else {

        # Swap the from domain with the to domain, as we're reversing
        $copy = $class->new(
            from           => $self->to->clone,
            to             => $self->from->clone,
            transformation => $self->transformation->inverse,

            # Make a copy of the ref
            scores => { %{ $self->scores } }
        );

        # And update alignment lengths
        $copy->scores->put('q_len', $self->scores->at('d_len'));
        $copy->scores->put('d_len', $self->scores->at('q_len'));
    }

    return $copy;

}    # inverse

=head2 coverage

The query is covered by the hit by X% [0:100]
Eg. if the query is 50 residues and the hit is 30 residues, then coverage is 60
Eg. if the query is 30 residues and the hit is 50 residues, then coverage is 100

=cut

sub coverage {
    my ($self,) = @_;
    my $ratio =
        100.0 * $self->scores->at('q_len') / $self->scores->at('d_len');
    return $ratio > 100.0 ? 100.0 : $ratio;
}

=head2 stringify

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub stringify {
    my ($self,) = @_;
    return '' . $self->transformation;

}    # stringify

###############################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

