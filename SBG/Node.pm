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


# Setwise comparison
sub _compare_sets {
    my ($a, $b) = @_;

    return unless ref($b) && $b->isa("Bio::Network::Node");

    # If all A's are less than all B's, then A < B, and vice versa
    # If results are mixed, return 0 (equivalent)
    my %cmp = tally($a,$b);

    if ($cmp{-1} && !($cmp{0} || $cmp{+1})) {
        return -1;
    } elsif ($cmp{+1} && !($cmp{0} || $cmp{-1})) {
        return +1;
    } else {
        return 0;
    }
}


################################################################################
=head2 tally

 Function: 
 Example : 
 Returns : 
 Args    : 

Setwise counts of $a < $b (-1), $a == $b (0), $a > $b (+1)

=cut
sub tally {
    my ($a, $b) = @_;

    # Compare all against all.
    # Store all comparisons
    my %cmp = (-1 => 0, 0 => 0, +1 => 0);

    # TODO should probably sort these?
    my @a = $a && $a->proteins;
    my @b = $b && $b->proteins;
    foreach my $pa (@a) {
        foreach my $pb (@b) {
            # Either -1, 0, +1
            # Count the occurences of each of these 3 possible results
            $cmp{$pa cmp $pb}++;
        }
    }

    return %cmp;
}

###############################################################################
__PACKAGE__->meta->make_immutable;
1;

