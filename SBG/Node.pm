#!/usr/bin/env perl

=head1 NAME

SBG::Node - Additions to Bioperl's L<Bio::Network::Node>

=head1 SYNOPSIS

 use SBG::Node;


=head1 DESCRIPTION

A node in a protein interaction network (L<Bio::Network::ProteinNet>)

Derived from L<Bio::Network::Node> . It is extended simply to add some simple
stringification and comparison operators.

=head1 SEE ALSO

L<Bio::Network::Node> , L<SBG::Network>

=cut

################################################################################

package SBG::Node;
use Moose;
extends 'Bio::Network::Node';

use overload (
    '""' => '_asstring',
    'cmp' => '_compare',
    fallback => 1,
    );


################################################################################

sub _asstring {
    my ($self) = @_;
    return join(",", $self->proteins);
} # _asstring


sub _compare {
    my ($a, $b) = @_;
    return unless ref($b) && $b->isa("Bio::Network::Node");
    # Assume each Node holds just one protein
    return $a cmp $b;
}


###############################################################################
__PACKAGE__->meta->make_immutable;
1;

