#!/usr/bin/env perl

=head1 NAME

SBG::Node - Additions to Bioperl's Bio::Network::Node

=head1 SYNOPSIS

use SBG::Node;


=head1 DESCRIPTION

A node in a protein interaction network (L<Bio::Network::ProteinNet>)

Derived from L<Bio::Network::Node> . It is extended simply to add some simple
stringification and comparison operators.

=head1 SEE ALSO

L<Bio::Network::Node> , L<Bio::Network::ProteinNet> , L<Bio::Network::Interaction>

=cut

################################################################################

package SBG::Node;
use SBG::Root -base, -XXX;
use base qw(Bio::Network::Node);


use overload (
    '""' => 'asstring',
    'cmp' => 'compare',
    'eq' => 'equal',
    );


################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new Bio::Network::Node(@_);
    # And add our ISA spec
    bless $self, $class;
    # Is now both a Bio::Network::Node and an SBG::Node
    return $self;
}

sub asstring {
    my ($self) = @_;
    return join(",", $self->proteins);
} # asstring


sub equal {
    my ($a, $b) = @_;
    return 0 == compare($a, $b);
}

# Setwise comparison
sub compare {
    my ($a, $b) = @_;

    return undef unless ref($b) && $b->isa("Bio::Network::Node");

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


# Setwise counts of $a < $b (-1), $a == $b (0), $a > $b (+1)
sub tally {
    my ($a, $b) = @_;

    # Compare all against all.
    # Store all comparisons
    my %cmp = (-1 => 0, 0 => 0, +1 => 0);

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

1;

__END__
