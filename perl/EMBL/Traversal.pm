#!/usr/bin/env perl

=head1 NAME

EMBL::Traversal - A recusive back-tracking traversal for Graph

=head1 SYNOPSIS

use EMBL::Traversal

# Create a new Prediction object
my $traversal = new EMBL::Traversal($mygraph);

=head1 DESCRIPTION

See also L<Graph::Traversal>

=head1 BUGS

None known.

=head1 REVISION

$Id: Prediction.pm,v 1.33 2005/02/28 01:34:35 uid1343 Exp $

=head1 APPENDIX

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################

package EMBL::Traversal;

use strict;
use warnings;

use Clone qw(clone);
use List::Util;
use Graph;
use Graph::UnionFind;
use Data::Dumper;

use lib "..";
use EMBL::Assembly;


################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    :

=cut

sub new {
    my ($class, $graph, $consider, @args) = @_;
    my $self = bless {};

    $self->{graph} = $graph;
    $self->{consider} = $consider;

    $self->{next_edges} = [];
    $self->{next_nodes} = [];

    return $self;

} # new

# Convert 2D array to string list, e.g.:
# red,blue,green,grey; alpha,beta,gamma; apples,oranges
sub arraystr {
    my ($a) = @_;
    return join("; ", map { join(",", @$_) } @$a);
}

sub get_state {
    my ($self, $key) = @_;
    return ${$self->{state}}{$key};
}

sub set_state {
    my ($self, $key, $value) = @_;
    ${$self->{state}}{$key} = $value;
    return ${$self->{state}}{$key};
}


sub traverse {
    my ($self) = @_;
    my $graph = $self->{graph};

    # Start with all vertices, independent
    my @vertices = $self->{graph}->vertices();

    print STDERR "verts:@vertices\n";

    # Shuffle them
#     @vertices = List::Util::shuffle @vertices;

    # Use all verts as starting nodes
    # Cannot do this, as all nodes are in separate frames of reference
#     push @{$self->{next_nodes}}, @vertices;

    # Start at a random node
#     push @{$self->{next_nodes}}, $vertices[int rand @vertices];
    
#     push @{$self->{next_nodes}}, $vertices[0];


    # TODO Starting node should be a parameter
    foreach my $node (@vertices) {
        print STDERR ("=" x 80), "\nStart node: $node\n";
        $self->{next_nodes} = [ shift @vertices ];
        my $uf = new Graph::UnionFind;
        $uf->add($_) for @vertices;
        # Initial assembly is empty
        my $ass = new EMBL::Assembly();
        # TODO Clean this up, should be in constructor
        $ass->{graph} = $self->{graph};
#         my $ass = new EMBL::Assembly;
        $self->do_nodes2($uf, $ass);
    }

}


sub do_edges2 {
    my ($self, $uf, $assembly) = @_;
    my $current = shift @{$self->{next_edges}};

    # When no edges left on stack, go to next level down in BFS traversal tree
    # I.e. process outstanding nodes
    unless ($current) {
        print STDERR "No more edges.\n";
        if (@{$self->{next_nodes}}) {
            print STDERR "Nodes: @{$self->{next_nodes}}\n";
            # Also give the progressive solution to peripheral nodes
            $self->do_nodes2($uf, $assembly);
            return;
        } else {
            if ($assembly eq $self->{lastass}) {
#                 print STDERR 
#                     "Duplicate Assembly: $assembly\n";
                # Skip dup
            } else {
                $assembly->save();
                $self->{lastass} = $assembly;
            }
            return undef;
        }
    }

    my ($src, $dest) = @$current;
    print STDERR "Edge: $src $dest (", arraystr($self->{next_edges}), ")\n";

# TODO Need to swap next to blocks. Where does clone need to happen
# If we clone, will we still iterate over templates correctly?

    # As child nodes of traversal will change partial solutions, clone these
    my $ufclone = clone($uf);
    my $assclone = $assembly->clone();

#     my $result = $self->{consider}($src, $dest, $self, $assembly);
    my $result = $self->{consider}($src, $dest, $self, $assclone);

    if (!defined $result) {
        # No more templates left for edge: $src,$dest
        print STDERR "\tNo more alternatives for $src $dest\n";
        return undef;
    } elsif (0 eq $result) {
        # Failed to use the currently attempted template
        # Carry on with any other outstanding edges. 
        $self->do_edges2($ufclone, $assclone);
    } else {
        # Successfully placed the current interaction template
        # Consider the destination node neighbor to have been visited
        print STDERR "\tpush'ing node $dest\n";
        push @{$self->{next_nodes}}, $dest;
        # These are now in the same connected component
        $ufclone->union($src, $dest);

        # Add this template to progressive solution
        $assclone->add($result);
        # Recursive call to try other edges
        $self->do_edges2($ufclone, $assclone);

        # Backtracking, undo intermediate solution by one edge
        # Don't need this, as we already cloned
#         $assembly->remove($result);
    }

    print STDERR "<= Edge: $src $dest\n";

    # Try other templates on this edge: push this edge back onto the edge stack
    push @{$self->{next_edges}}, $current;
    # This will stop when this edge runs out of templates

#     return $self->do_edges2($uf, $assembly);
    # Should be doing this also on a clone of assembly
    # Otherwise two different template might be forced into same FoR

    # As child nodes of traversal will change partial solutions, clone these.

    # NB We are cloning here for the 2nd time in this function as we are now
    # descending into a 2nd recursive call.  

    # TODO make this flow more intuitive

    $ufclone = clone($uf);
    $assclone = $assembly->clone();
    $self->do_edges2($uf, $assclone);
}


sub do_nodes2 {
    my ($self, $uf, $assembly) = @_;
    my $current = shift @{$self->{next_nodes}};

    unless ($current) {
        print STDERR "No more nodes.\n";
        if (@{$self->{next_edges}}) {
            print STDERR "Edges: ", arraystr($self->{next_edges}), "\n";
            $self->do_edges2($uf, $assembly);
            return;
        } else {
            if ($assembly eq $self->{lastass}) {
#                 print STDERR 
#                     "Duplicate Assembly: $assembly\n";
                # Skip dup
            } else {
                # Partial solution
                $assembly->save();
                # Note this, so as not to duplicate it
                $self->{lastass} = $assembly;
            }
            return undef;
        }
    }

    print STDERR "Node: $current (@{$self->{next_nodes}})\n";

    my @unseen = $self->new_neighbors($current, $uf);
    for my $neighbor (@unseen) {
        # push edges onto stack
        print STDERR "\tpush'ing edge: $current,$neighbor\n";
        push(@{$self->{next_edges}}, [$current, $neighbor]);
    }
    $self->do_nodes2($uf, $assembly);

    print STDERR "<= Node: $current\n";
}


sub new_neighbors {
    my ($self, $node, $uf) = @_;

    my @adj = $self->{graph}->neighbors($node);
    # Only adjacent vertices not already in same traversal set (i.e. the unseen)
    my @unseen = grep { ! $uf->same($node, $_) } @adj;

    print STDERR "\tadj: @adj; unseen: @unseen\n";

    return @unseen;
}


sub do_set {
    my ($self, @nodes) = @_;

    # UnionFind data structure to track where we already were
    my $uf = new Graph::UnionFind;
    $uf->add($_) for @nodes;

    foreach my $entry (@nodes) {
        print STDERR "Entry: $entry\n";
        my $clone = clone($uf);
        $self->do_node($clone, $entry, []);

        # TODO DEL
        # Just do a single (random) entry point for now
        last;
    }
}


sub do_node {
    my ($self, $uf, $start, $assembly) = @_;

    print STDERR "At $start:\n";
    my @unseen = $self->new_neighbors($start, $uf);

    foreach my $neighbor (@unseen) {
        print STDERR "\t$start -- $neighbor\n";

        # Make a copy where edge is established (pass this down)
        # TODO DES This is a lot of copying. Alternatives?
        my $clone = clone($uf);

        # In this temporary copy, union my neighbor into my set
        $clone->union($start, $neighbor);

        # As long as this edge is successful, keep 'running' it

        # TODO DES this doesn't make sense because it stop on the first failure
        # As I don't know the difference between "single failure" and "exhausted"

        while (my $result = 
               $self->{consider}($start, $neighbor, $self, $assembly)) {
            # OK, visit the neighboring vertex
            # Process outstanding vertices, with this edge now in place
#             $self->do_node($clone, @nodes);

            # Partial solution, pass it down traversal tree
            push @$assembly, $result;
            # Get the assembly that's passed back up
            my $lowerassembly = $self->do_node($clone, $neighbor, $assembly);
            # Undo the partial solution after backtracking
            pop @$assembly;

            # NB we don't try to combine partial solutions over the same edge
        }
        print STDERR "\t<= back at edge: $start -- $neighbor\n";
    }
    # This node is done, do rest of forest without this node
    # This is important, as the interaction network may be disconnected

    # TODO DES Of course, this also causes the whole procedure to be repeated
    # for every possibly entry point to the graph. I.e. many duplicate
    # solutions. But at least some of these are necessary in the case where
    # we've picked a bad entry point. Alternative, do_node could return what
    # nodes it has already processed.

    # TODO save solution, if any (use a callback)
    print STDERR "\tDone at $start: Assembly: @$assembly\n";
    return $assembly
#     $self->do_node($uf, @nodes);

}


###############################################################################

1;

__END__
