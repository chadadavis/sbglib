#!/usr/bin/env perl

=head1 NAME

EMBL::Assembly - 

=head1 SYNOPSIS


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

package EMBL::Assembly;
use Spiffy -Base, -XXX;
use base 'Clone';

use overload (
    '""' => 'stringify',
    );

use lib "..";


################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    :

=cut

sub new() {
    my $self = bless {};

    # Save the EMBL::CofM instances, indexed by component name
    $self->{cofm} = {};
    # Save the relative EMBL::Transform instance, indexed by component name
    $self->{transform} = {};
    # Bio::Net::Interaction objects used in this assembly, i.e. templates
    $self->{interaction} = {};

    return $self;
} # new

# Index hash of EMBL::CofM, by component name
sub cofm {
    my ($id, $cofm) = @_;
    if (defined $cofm) {
        $self->{cofm}{$id} = $cofm;
    }
    return $self->{cofm}{$id};
}

# Index hash of EMBL::Transform, by component name
sub transform {
    my ($id, $transform) = @_;
    if (defined $transform) {
        $self->{transform}{$id} = $transform;
    }
#     $self->{transform}{$id} ||= new EMBL::Transform();
    return $self->{transform}{$id};
}

# Add a chosen interaction template
sub add {
    my $ix = shift;
    $self->{interaction}{$ix} = $ix;
    return $self->{interaction}{$ix};
}

# Remove a node or an interaction
sub remove {
    my $id = shift;
    delete $self->{interaction}{$id};
    delete $self->{transform}{$id};
    delete $self->{cofm}{$id};
}


# A shallow copy, copies hashes and their pointers.
# Doesn't copy referenced CofM/Transform objects.
# This is necessary, as backtracking graph traversal creates many Assembly's
# Depth 2 means: copy assembly (1) and the hashes in assembly (2).
# Does not copy what is referenced in the hashes (3).
sub clone {
    super(2);
}

sub stringify {
    join ",", keys %{$self->{interaction}};
}

