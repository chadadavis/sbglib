#!/usr/bin/env perl

=head1 NAME

EMBL::Interaction - Additions to Bioperl's Bio::Network::Interaction

=head1 SYNOPSIS

use EMBL::Interaction;


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

package Bio::Network::Interaction;

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
    return $self->primary_id;
}

sub compare {
    my ($a, $b) = @_;
    return $a->primary_id cmp $b->primary_id;
}


###############################################################################

1;

__END__
