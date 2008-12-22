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
    '==' => 'eq',
    'eq' => 'eq',
    );

use lib "..";

use Data::Dumper;


# Allowed (linear) overlap between the spheres, that represent the proteins
# Centre-of-mass + Radius-of-gyration
# our $thresh = 30; # Angstrom
our $thresh = 20; # Angstrom


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
    # Save the relative EMBL::Transform instances, indexed by component name
    $self->{transform} = {};
    # Bio::Net::Interaction objects used in this assembly, i.e. templates
    $self->{interaction} = {};

    return $self;
} # new

sub eq {
    my $other = shift;
    return $self && $other && ("$self" eq "$other");
}

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
# Depth 2 means: copy assembly (1) and the hashes/objects in assembly (2).
# Does not copy what is referenced in/from the hashes/objects (3).
# I.e. Assembly can efficiently contain references to other objects without
#   incurring a cloning copy penalty.
sub clone {
    super(2);
}

# TODO DOC the interaction field
sub stringify {
    join ",", keys %{$self->{interaction}};
}


# Dump domain IDs and their transformations in STAMP format
# TODO DOC what do return vals mean
sub save {
    my $file = shift;
    my $n = keys %{$self->{cofm}};

    if ($n < 3) {
        print STDERR "Skipping dimeric assembly\n";
        return 1;
    }

    # Unique topology identifier:
    # For each edge, component names sorted, then edges sorted
    my @ikeys = keys %{$self->{interaction}};
    my @iactions = map { $self->{graph}->get_interaction_by_id($_) } @ikeys;
    my @edges = map { join(',', sort($_->nodes)) } @iactions;
    my $topology = join(';', sort(@edges));

    our %solutions;
    our $topoi;
    if (! exists $solutions{$topology}) {
        # A new topology
        $topoi++;
        print STDERR "New solution topology #$topoi: $topology\n";
        $solutions{$topology} = $topoi;
    } else {
        print STDERR "Another solution like #$topoi: $topology\n";
    }


    our $solutioni;
    $solutioni++;
    $file ||= sprintf("assembly-%03d-%03d.dom", $topoi, $solutioni);

    print STDERR 
        "Assembly: $file\n$self\n";

    open my $fh, ">out/$file" or return undef;

    print $fh "\% File: $file\n";
    print $fh "\% Assembly ID: $solutioni\n";
    print $fh "\% Topology cluster ID: $topoi\n";
    print $fh "\% Topology: $topology\n";
    print $fh "\% Templates: $self\n";
    print $fh "\n";

    # Print all CofM objects (STAMP format)
    # STAMP will number the chains alphabetically in the final output
    my $chainid = ord 'A';
    # $key is the component's label
    foreach my $key (sort keys %{$self->{cofm}}) {
        # id is the PDB ID of the template segment
        print STDERR "\tsaving: $key ", $self->cofm($key)->id(), "\n";

        print $fh "\% CHAIN ", chr($chainid++), " $key\n";

        # This uses the cumulative transform, maintained by CofM itself
#         print $fh $self->cofm($key)->dom(), "\n";

        # Or try to give it the transform that was maintained here in Assembly
        my $cofm = $self->cofm($key);
        my $transform = $self->transform($key);
        print $fh $cofm->dom2($transform), "\n";
    }
    print $fh "\n";
    close $fh;
    return 1;
} # save


sub clashes {
    my $newcofm = shift;

    # TODO configurable Config::IniFiles
    our $thresh;

    # $self->cofm is a hash of CofM objects
    # If any of them clashes with the to-be-added CofM, then disallow
    foreach my $key (keys %{$self->{cofm}}) {
        my $overlap = $newcofm->overlap($self->cofm($key));
        print STDERR 
            "\toverlap: ", $newcofm->id, "/", $self->cofm($key)->id, 
            " $overlap\n";
        if ($overlap > $thresh) {
            return 1;
        }
    }
    print STDERR "\t$newcofm fits\n";
    return 0;
}
