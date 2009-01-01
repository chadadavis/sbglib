#!/usr/bin/env perl

=head1 NAME

SBG::Traversal - A recusive back-tracking traversal of a Graph

=head1 SYNOPSIS

 use SBG::Traversal;

 my $traversal = new SBG::Traversal($mygraph);

=head1 DESCRIPTION


 TODO

Similar to BFS (breadth-first search)

  does this also work on any L<Graph> or just ProteinNet ?

=head1 SEE ALSO

L<Graph::Traversal>

=cut

################################################################################

package SBG::Traversal;
use SBG::Root -Base, -XXX;

# Reference to the graph being traversed
field 'graph';

# Call back function used to determine whether an edge is traversed or not
field 'consider';

# Queues noting the edges/nodes to be processed, in a breadth-first fashion
field 'next_edges' => [];
field 'next_nodes' => [];


use warnings;
use Clone qw(clone);
use Graph;
use Graph::UnionFind;

# TODO DEL
#   state saving object should be generic
use SBG::Assembly;


################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    :

-graph
-consider

=cut
sub new () {
    my ($class, %o) = @_;
    my $self = { %o };
    bless $self, $class;
    $self->_undash;
    return $self;
} # new



# These functions used by try_edge()
# Should be in Assembly, which is the state object
sub get_state {
    my ($key) = @_;
    return ${$self->{state}}{$key};
}

sub set_state {
    my ($key, $value) = @_;
    ${$self->{state}}{$key} = $value;
    return ${$self->{state}}{$key};
}


################################################################################
=head2 traverse

 Title   : traverse
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Each vertex in the graph as used as the starting node one time.  This is because
different traversals could theoretically produce different results.

TODO consider allowing starting node (single one) as parameter

=cut
sub traverse {
    my @nodes = $self->graph->vertices();

    print STDERR "Nodes:@nodes\n";

    # NB cannot use all nodes together in one run, as they may have different
    # frames of reference.
#     push @{$self->next_nodes}, @nodes;


    # Using one different starting node in each iteration
    foreach my $node (@nodes) {
        print STDERR ("=" x 80), "\nStart node: $node\n";

        $self->{next_nodes} = [ $node ];

        # A new disjoint set data structure, to track which nodes in same sets
        my $uf = new Graph::UnionFind;
        # Each node is in its own set first
        $uf->add($_) for @vertices;

        # TODO Clean this up, should be in constructor
        # Initial assembly is empty
        my $ass = new SBG::Assembly();
        
        # How to cleanly get this graph in to the assembly?
        #  Where is this needed?
        $ass->{graph} = $self->{graph};

        # Go!
        $self->do_nodes2($uf, $ass);
    }

} # traverse


# TODO DES shorten this
sub do_edges2 {
    my ($uf, $assembly) = @_;
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
                $assembly->write() if $assembly->ncomponents() > 2;
                $self->{lastass} = $assembly;
            }
            return undef;
        }
    }

    my ($src, $dest) = @$current;
    print STDERR "Edge: $src $dest (", _array2D($self->{next_edges}), ")\n";

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
} # do_edges2


sub do_nodes2 {
    my ($uf, $assembly) = @_;
    my $current = shift @{$self->{next_nodes}};

    unless ($current) {
        print STDERR "No more nodes.\n";
        if (@{$self->{next_edges}}) {
            print STDERR "Edges: ", _array2D($self->{next_edges}), "\n";
            $self->do_edges2($uf, $assembly);
            return;
        } else {
            if ($assembly eq $self->{lastass}) {
#                 print STDERR 
#                     "Duplicate Assembly: $assembly\n";
                # Skip dup
            } else {
                # Partial solution
                $assembly->write() if $assembly->ncomponents() > 2;
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
} # do_nodes2


# TODO DOC
sub new_neighbors {
    my ($self, $node, $uf) = @_;

    my @adj = $self->{graph}->neighbors($node);
    # Only adjacent vertices not already in same traversal set (i.e. the unseen)
    my @unseen = grep { ! $uf->same($node, $_) } @adj;

    print STDERR "\tadj: @adj; unseen: @unseen\n";

    return @unseen;
}



# Convert 2D array to string list, e.g.:
# red,blue,green,grey; alpha,beta,gamma; apples,oranges
sub _array2D {
    my ($a) = @_;
    return join("; ", map { join(",", @$_) } @$a);
}


###############################################################################

1;

__END__
