#!/usr/bin/env perl

=head1 NAME

EMBL::Node - Additions to Bioperl's Bio::Network::Node

=head1 SYNOPSIS

use EMBL::Node;


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
    );

# Other modules in our hierarchy
use lib "..";


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

# Setwise comparison
sub compare {
    my ($a, $b) = @_;
    
    # Shortcut, since comparing lists is not always meaningful
#     return 0;

    # Compare all agains all.
    # If all A's are less than all B's, then A < B, and vice versa
    # If results are mixed, return 0 (equivalent)
    my @a = $a->proteins;
    my @b = $b->proteins;
    # Store all comparisons
    my %cmp;
    foreach my $pa (@a) {
        foreach my $pb (@b) {
            # Either -1, 0, +1
            # Count the occurences of each of these 3 possible results
            $cmp{$pa cmp $pb}++;
        }
    }
    # If no A's were ever smaller, then A is bigger than all B's
    if ($cmp{-1} == 0) { 
        return 1;
    } elsif ($cmp{1} == 0) {
        return -1;
    } else {
        # Mixed sets
        return 0;
    }
}

###############################################################################

1;

__END__
