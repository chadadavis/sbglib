#!/usr/bin/env perl

=head1 NAME

SBG::Node - Additions to Bioperl's Bio::Network::Node

=head1 SYNOPSIS

use SBG::Node;


=head1 DESCRIPTION


=head1 BUGS

None known.

=head1 REVISION

$Id: Prediction.pm,v 1.33 2005/02/28 01:34:35 uid1343 Exp $

=head1 APPENDIX

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################

package Bio::Network::Node;


use overload (
    '""' => 'stringify',
    'cmp' => 'compare',
    'eq' => 'equal',
    );

# Other modules in our hierarchy
use lib "..";

use Data::Dumper; 

################################################################################
=head2 

 Title   : 
 Usage   : 
 Function: 
 Returns : 
 Args    : 
           

=cut

sub stringify {
    my ($self) = @_;
    my $class = ref($self) || $self;
    return join(",", $self->proteins);
}

sub equal {
    my ($a, $b) = @_;



    return 0 == compare($a, $b);
}

# Setwise comparison
sub compare {
    my ($a, $b) = @_;

    return undef unless ref($b) eq "Bio::Network::Node";

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
