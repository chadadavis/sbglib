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
with 'SBG::Storable';

use overload (
    '""' => '_asstring',
    'cmp' => '_compare',
    fallback => 1,
    );


################################################################################

sub new () {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}


sub _asstring {
    my ($self) = @_;
    return join(",", $self->proteins);
} # _asstring


sub _compare {
    my ($a, $b) = @_;
    return unless ref($b) && $b->isa("Bio::Network::Node");
    # Assume each Node holds just one protein
    # Need to stringify here, otherwise it's recursive
    return "$a" cmp "$b";
}


###############################################################################
__PACKAGE__->meta->make_immutable;
1;

