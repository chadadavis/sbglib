#!/usr/bin/env perl

=head1 NAME

SBG::Domain - Represents a domain of a protein structure. 

=head1 SYNOPSIS

 use SBG::Domain;

=head1 DESCRIPTION

=head1 SEE ALSO

L<SBG::DomainI>

=cut

################################################################################

package SBG::Domain;
use Moose;
use MooseX::StrictConstructor;

# Defines what must be implemented to represent a 3D structure
with qw/
SBG::DomainI 
/;


use overload (
    '""' => 'stringify',
    '==' => 'equal',
    fallback => 1,
    );


################################################################################
# Accessors



# Record linkages to other domains This does not define where the domain
# currently is, but identifies the linking transformation that was used to
# originally join it into a complex.
# TODO should be a Superposition.pm
has 'linker' => (
    is => 'rw',
    does => 'SBG::TransformI',
    required => 1,
    default => sub { new SBG::Transform::Homog },
    );


################################################################################
# Methods required by SBG::DomainI

# TODO should create warnings here

sub dist { return }
sub sqdist { return }
sub rmsd { return }
sub evaluate { return }

sub volume { return }
sub overlap { return }


################################################################################
=head2 transform

 Function: 
 Example : $self->transform($some_4x4_PDL_matrix); # no-op
 Returns : $self
 Args    : L<SBG::Transform>

This simply updates the cumulative L<SBG::Transform> but
does not transform any structures, since there are none in this class.

=cut
sub transform {
    my ($self,$newtrans) = @_;
    return $self unless defined($newtrans);

    # Update the cumulative transformation
    my $prod = $newtrans x $self->transformation;
    $self->transformation($prod);
    return $self;

} # transform




################################################################################
=head2 equal

 Function:
 Example :
 Returns : 
 Args    :

Are two domains effectively equal.
This includes the external 3D representation of the domain.
=cut
sub equal {
    my ($self, $other) = @_;
    # Must be of the same type
    return 0 unless defined $other && blessed($self) eq blessed($other);
    # Shortcut: Obviously equal if at same memory location
    return 1 if refaddr($self) == refaddr($other);
    # Fields, from most general to more specific
    my @fields = qw(pdbid descriptor file);
    foreach (@fields) {
        # If any field is different, the containing objects are different
        return 0 if 
            $self->$_ && $other->$_ && $self->$_ ne $other->$_;
    }
    # Transformations. If not defined, then assume the objects are equivalent 
    my $transeq = $self->transformation == $other->transformation;
    return $transeq;

} # equal


################################################################################
__PACKAGE__->meta->make_immutable;
1;

