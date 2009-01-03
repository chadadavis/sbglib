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

Works on Graph, but assumes that multiple edges are stored as attributes of a
single edge between unique nodes. This is the pattern used by
L<Bio::Network::ProteinNet>. It does not strictly require
L<Bio::Network::ProteinNet> but will work best in that case.

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

# Keep track of edges in the covering at every moment
field 'covering' => {};


use warnings;
use Clone qw(clone);
use Graph;
use Graph::UnionFind;

# Debug print
sub _d;
sub _d0;

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

 $test($state, $traversal, $src, $dest);

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


# TODO DOC
# Keeps tracks of indexes on alternatives for edges, indexed by an edge ID
sub alt : lvalue {
    my ($self,$key) = @_;
    $self->{alt} ||= {};
    # Do not use 'return' with 'lvalue'
    $self->{alt}{$key};
} # comp


# Keeps track of what complete graph coverings have already been created
sub solution : lvalue {
    my ($self,$key) = @_;
    $self->{solution} ||= {};
    # Do not use 'return' with 'lvalue'
    $self->{solution}{$key};
} # comp


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
    _d0 "Nodes:@nodes";

    # NB cannot use all nodes together in one run, as they may have different
    # 'frames of reference'.
#     push @{$self->next_nodes}, @nodes;

    # Using one different starting node in each iteration
    foreach my $node (@nodes) {

        # Starting node for this iteraction
        $self->{next_nodes} = [ $node ];
        _d0 "=" x 80, "\nStart node: $node";

        # A new disjoint set data structure, to track which nodes in same sets
        my $uf = new Graph::UnionFind;
        # Each node is in its own set first
        $uf->add($_) for @nodes;

        # Go!
        $self->do_nodes($uf, $state, 0);
    }
} # traverse


# Looks for any edges on any outstanding nodes
sub do_nodes {
    my ($self, $uf, $state, $d) = @_;
    my $current = shift @{$self->next_nodes};

    return $self->no_nodes($uf,$state, $d) unless $current;

    # Which adjacent nodes have not yet been visited
    _d $d, "Node: $current (@{$self->{next_nodes}})";
    my @unseen = $self->_new_neighbors($current, $uf, $d);
    for my $neighbor (@unseen) {
        # push edges onto stack
        _d $d, "push'ing edge: $current,$neighbor";
        push(@{$self->{next_edges}}, [$current, $neighbor]);
    }
    # Continue processing all outstanding nodes before moving to edges
    $self->do_nodes($uf, $state, $d);
    _d $d, "<= Node: $current";
} # do_nodes


# Called when no nodes left, switches to edges, if any
sub no_nodes {
    my ($self, $uf, $state, $d) = @_;
    _d $d, "No more nodes";
    if (@{$self->next_edges}) {
        _d $d, "Edges: ", _array2D($self->{next_edges});
        $self->do_edges($uf, $state, $d+1);
    } else {
        $self->do_solution($state, $self->lastedge, $d);
    }
} # no_nodes


# Partial solution
sub do_solution {
    my ($self, $state, $callback, $d) = @_;
    my @alts = sort keys %{$self->covering};
    my $cover = join(',', @alts);
    if ($self->solution($cover)) {
#         _d $d, "Dup";
        _d0 "== Dup";
    } else {
        $self->solution($cover) = 1;
        $callback->($state, $self->graph, @alts) if defined $callback;
    }
} # do_solution

# Processing any outstanding edges
# For each, gets the next alternative
# Try to validate the alternative based on the provided callback function
# Recurses to exhaust all possibilities
sub do_edges {
    my ($self, $uf, $state, $d) = @_;
    my $current = shift @{$self->{next_edges}};

    return $self->no_edges($uf, $state, $d) unless $current;

    my ($src, $dest) = @$current;
    _d $d, "Edge: $src $dest (", _array2D($self->{next_edges}), ")";

    # ID of next alternative to try on this edge, if any
    my $alt_id = $self->next_alt($src, $dest, $d);
    unless ($alt_id) {
        # No more unprocessed multiedges remain between these nodes: $src,$dest
        _d $d, "No more alternative edges for $src $dest";
        # Try any other outstanding edges at this level first, though
        $self->do_edges($uf, $state, $d);
        return;
    }

    # As child nodes in traversal may change partial solutions, clone these
    # This implicitly allow us to backtrack later if $self->test() fails, etc
    my $stateclone = $state->clone();
    # Do we want to go ahead and traverse this edge?
    my $success = $self->{test}($stateclone, $self->graph, $src, $dest, $alt_id);

    if (! $success) {
        # Current edge was rejected, but alternative multiedges may remain
        _d $d, "Failed";
        # Carry on with any other outstanding edges.
        # Continue using the same state, in case the failure must be remembered
        $self->do_edges($uf, $stateclone, $d);
        # And then 'fall through' to repeat this edge's alternatives too
    } else {
        # Edge alternative succeeded. 
        _d $d, "Succeeded";
        $self->covering->{$alt_id} = 1;
        # Consider the destination node neighbor to have been visited now.
        # These are now in the same connected component. 
        # But clone this first, to be able to undo/backtrack afterward
        my $ufclone = clone($uf);
        $ufclone->union($src, $dest);
        _d $d, "Node $dest reachable";
        push @{$self->{next_nodes}}, $dest;
        # Recursive call to try other multiedges between $src,$dest
        # Continue using the same state, in case the success must be remembered
        $self->do_edges($ufclone, $stateclone, $d);
        # And then 'fall through' to repeat this edge's alternatives too
        # Undo
        delete $self->covering->{$alt_id};
    }

    _d $d, "<= Edge: $src $dest";
    # 2nd recursion here. This is because we wait for the previous round to
    # finish, with all of it's chosen edges, before retrying alternatives on any
    # of the edges. Assumption is that multi-edges are incompatible. That's why
    # we wait until now to re-push them.
    push @{$self->{next_edges}}, $current;

    # Go back to using the state that we had before this alternative
    $self->do_edges($uf, $state, $d);
} # do_edges


# Called when no edges left, switches to processing nodes, if any
sub no_edges {
    my ($self, $uf, $state, $d) = @_;

    # When no edges left on stack, go to next level down in BFS traversal tree
    # I.e. process outstanding nodes
    _d $d, "No more edges";
    if (@{$self->{next_nodes}}) {
        _d $d, "Nodes: @{$self->{next_nodes}}";
        # Also give the progressive solution to peripheral nodes
        $self->do_nodes($uf, $state, $d+1);
    } else {
        # Partial solution
        $self->do_solution($state, $self->lastnode, $d);
    }
} # no_edges


# Uses a L<Graph::UnionFind> to keep track of nodes in the graph (the
# other graph, the one being traversed), that are still to be visited.
sub _new_neighbors {
    my ($self, $node, $uf, $d) = @_;

    my @adj = $self->{graph}->neighbors($node);
    # Only adjacent vertices not already in same traversal set (i.e. the unseen)
    my @unseen = grep { ! $uf->same($node, $_) } @adj;

    _d $d, "adj: @adj; unseen: @unseen";
    return @unseen;
}


# Get ID of next alternative for a given edge $u,$v
sub next_alt {
    my ($self, $u, $v, $d) = @_;

    # IDs of edge attributes (the alternatives on this edge)
    # Sort, to make indexes unique between invocations of this method
    my @alt_ids = sort $self->graph->get_edge_attribute_names($u, $v);
    _d $d, join ", ", @alt_ids;

    # A label for the current edge, regardless of alternative
    my $edge_id = "$u--$v";

    # Tells us which alternative to try next
    my $alt_idx = $self->alt($edge_id) || 0;

    # If no alternatives (left) to try, cannot use this edge
    unless ($alt_idx < @alt_ids) {
        _d $d, "No more templates";
        # Now reset, for any subsequent, independent attempts on this edge
        $self->alt($edge_id) = 0;
        return undef;
    }

    # The ID of the chosen alternative
    my $alt_id = $alt_ids[$alt_idx];
    _d $d,  "Template ", 1+$alt_idx, "/" . @alt_ids;

    # Next time, take the next one;
    $self->alt($edge_id) += 1;

    return $alt_id;

} # next_alt


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

sub _d0 { _d(0,@_); }
sub _d {
    my $d = shift;
    print STDERR ("\t" x $d), @_, "\n";
}
###############################################################################

1;

__END__
