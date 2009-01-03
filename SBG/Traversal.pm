#!/usr/bin/env perl

=head1 NAME

SBG::Traversal - A recursive back-tracking traversal of a L<Graph>

=head1 SYNOPSIS

 use SBG::Traversal;

 my $traversal = new SBG::Traversal($mygraph);
 $traversal->traverse();

=head1 DESCRIPTION

Similar to BFS (breadth-first search), but specifically for multigraphs in which
each the many edges between two nodes represent mutually exclusive alternatives.

The gist is, since we have multigraphs, an edge is not traversed one time, and
edge is traversed as many times as possible. We rely on a callback function to
tell us when to stop traversing a given edge. 

=head1 SEE ALSO

L<Graph::Traversal> 

=cut

################################################################################

package SBG::Traversal;
use SBG::Root -base, -XXX;

# Reference to the graph being traversed
field 'graph';

# Call back functions
field 'test';
field 'lastnode';
field 'lastedge';

# Queues that note the edges/nodes to be processed, in a breadth-first fashion
field 'next_edges' => [];
field 'next_nodes' => [];


use warnings;
use Clone qw(clone);
use Graph;
use Graph::UnionFind;



################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    :

-graph

Callbacks:

$traversal is this L<SBG::Traversal> and $stateclone is a hashref
that can be used to store state information. It is cloned as necessary.

-test  :
The $test function should return true if an edge is to be used in the
traversal. It is called as:

 $test($src, $dest, $state, $traversal);

src and dest are the source and destination nodes of the edge being
considered. 
$test() must return: -1/0/1
-1: Failed to traverse the edge this time
0: Exhausted all possibilities for traversing this edge in any way
+1: Succeeded in traversing this edges this time, though other multiedges remain

-lastnode : (optional)
The last node has just been processed and there are no edges left.

 $lastnode($state, $traversal)

-lastedge : (optional)
The last edge has just been processed and there are no nodes left

 $lastedge($state, $traversal)


=cut
sub new () {
    my ($class, %o) = @_;
    my $self = { %o };
    bless $self, $class;
    $self->_undash;
    return $self;
} # new





################################################################################
=head2 traverse

 Title   : traverse
 Usage   :
 Function:
 Example :
 Returns : 
 Args    : $state - An optional object (hashref) to store state information.

If no $state is provided, an empty hashref is used. You can later put your own
data into this when it is provided to your callback functions.

If $state implements Perl's L<Clone> interface, that will be used to clone the
object, as needed. Otherwise, the standard B<Clone::clone> method is used.

Each vertex in the graph is used as the starting node one time.  This is because
different traversals could theoretically produce different results.

TODO consider allowing starting node (single one) as parameter

TODO Under what circumstances will solutions be redundant. When can we spare
ourselves of the extra computation?

=cut
sub traverse {
    my $self = shift;
    # If no state object provide, use an empty hashref, Clone'able
    my $state = shift || {};
    bless($state, 'Clone');

    my @nodes = $self->graph->vertices();
    print STDERR "Nodes:@nodes\n";

    # NB cannot use all nodes together in one run, as they may have different
    # 'frames of reference'.
#     push @{$self->next_nodes}, @nodes;

    # Using one different starting node in each iteration
    foreach my $node (@nodes) {
        # Starting node for this iteraction
        $self->{next_nodes} = [ $node ];
        print STDERR ("=" x 80), "\nStart node: $node\n";

        # A new disjoint set data structure, to track which nodes in same sets
        my $uf = new Graph::UnionFind;
        # Each node is in its own set first
        $uf->add($_) for @nodes;

        # Go!
        $self->do_nodes($uf, $state);
    }
} # traverse


# TODO DOC
sub do_nodes {
    my ($self, $uf, $state) = @_;
    my $current = shift @{$self->next_nodes};

    return $self->no_nodes($uf,$state) unless $current;

    # Which adjacent nodes have not yet been visited
    my @unseen = $self->_new_neighbors($current, $uf);
    print STDERR "Node: $current (@{$self->{next_nodes}})\n";
    for my $neighbor (@unseen) {
        # push edges onto stack
        print STDERR "\tpush'ing edge: $current,$neighbor\n";
        push(@{$self->{next_edges}}, [$current, $neighbor]);
    }
    $self->do_nodes($uf, $state);
    print STDERR "<= Node: $current\n";
} # do_nodes


sub no_nodes {
    my ($self, $uf, $state) = @_;
    print STDERR "No more nodes.\n";
    if (@{$self->next_edges}) {
        print STDERR "Edges: ", _array2D($self->{next_edges}), "\n";
        $self->do_edges($uf, $state);
    } else {
        # Partial solution
        $self->{lastedge}($state, $self) if $self->lastedge;
    }
} # no_nodes


# TODO DES shorten this
# TODO DOC
sub do_edges {
    my ($self, $uf, $state) = @_;
    my $current = shift @{$self->{next_edges}};

    return $self->no_edges($uf, $state) unless $current;

    my ($src, $dest) = @$current;
    print STDERR "Edge: $src $dest (", _array2D($self->{next_edges}), ")\n";

    # As child nodes in traversal may change partial solutions, clone these
    # This implicitly allow us to backtrack later if $self->test() fails, etc
    my $ufclone = clone($uf);
    my $stateclone = $state->clone();
    # Do we want to go ahead and traverse this edge?
    my $result = $self->{test}($src, $dest, $self, $stateclone);

    # Was traversing this edge possible this time?
    if (!defined $result) {
        # No more unprocessed multiedges remain between these nodes: $src,$dest
        print STDERR "\tNo more alternative edges for $src $dest\n";
        return undef;
    } elsif (-1 == $result) {
        # Current edge was rejected, but alternative multiedges may remain
        # Carry on with any other outstanding edges, using same state.
        push @{$self->{next_edges}}, $current;
        $self->do_edges($ufclone, $stateclone);
    } elsif (1 == $result) {
        # Traversing this multiedge succeeded, but may be alternative multiedges
        # Consider the destination node neighbor to have been visited now
        print STDERR "\tpush'ing node $dest\n";
        push @{$self->{next_nodes}}, $dest;
        # These are now in the same connected component
        $ufclone->union($src, $dest);
        # Recursive call to try other multiedges between $src,$dest
        push @{$self->{next_edges}}, $current;
        # NB No backtracking/undoing needed now, as we cloned $uf and $state
        $self->do_edges($ufclone, $stateclone);
    } else {
        carp $self->test . " must return: -1,0,+1 . Got: $result\n";
        return undef;
    }
    print STDERR "<= Edge: $src $dest\n";
} # do_edges


sub no_edges {
    my ($self, $uf, $state) = @_;

    # When no edges left on stack, go to next level down in BFS traversal tree
    # I.e. process outstanding nodes
    print STDERR "No more edges.\n";
    if (@{$self->{next_nodes}}) {
        print STDERR "Nodes: @{$self->{next_nodes}}\n";
        # Also give the progressive solution to peripheral nodes
        $self->do_nodes($uf, $state);
    } else {
        # Partial solution
        $self->{lastnode}($state, $self) if $self->lastnode;
    }
} # no_edges


# Uses a L<Graph::UnionFind> to keep track of nodes in the graph (the
# other graph, the one being traversed), that are still to be visited.
sub _new_neighbors {
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


# TODO DEL

# These functions used by Assembly::try_edge()
# Should be in Assembly, which is the state object
sub get_state {
    my ($self, $key) = @_;
    return ${$self->{state}}{$key};
}

sub set_state {
    my ($self, $key, $value) = @_;
    ${$self->{state}}{$key} = $value;
    return ${$self->{state}}{$key};
}


###############################################################################

1;

__END__
