#!/usr/bin/env perl

=head1 NAME

SBG::Traversal - A recursive back-tracking traversal of a L<Graph>

=head1 SYNOPSIS

 use SBG::Traversal;

 my $traversal = new SBG::Traversal($mygraph);
 $traversal->traverse();

=head1 DESCRIPTION

Similar to BFS (breadth-first search), but specifically for multigraphs in which
each of the many edges between two nodes represent mutually exclusive
alternatives.

The gist is, since we have multigraphs, an edge is not traversed one time,
rather an edge is traversed as many times as possible, as long as alternatives
on that edge remain. We rely on a callback function to tell us when to stop
traversing a given edge.

Works on L<Graph>, but assumes that multiple edges are stored as attributes of a
single edge between unique nodes. This is the pattern used by
L<Bio::Network::ProteinNet>. It does not strictly require
L<Bio::Network::ProteinNet> but will work best in that case.

For L<Graph> edge attribute names must be defined 
 
 $graph->get_edge_attribute_names($u, $v);

=head1 SEE ALSO

L<Graph::Traversal> 

=cut

################################################################################

package SBG::Traversal;
use strict;
use warnings;
use 5.010;

use Moose;
use Moose::Util::TypeConstraints;
use Moose::Autobox;
use Clone qw/clone/;
use Graph;
use Graph::UnionFind;

# Manual tail call optimization
use Sub::Call::Recur; # qw/recur/;

use Heap::Priority;


################################################################################

# Debug printing (to trace recursion and it's unwinding)
# TODO del
use SBG::U::Log qw/log/;

use Log::Any qw/$log/;
sub _d {
    my $d = shift;
    log()->trace("  " x $d, @_);
}
sub _d0 { _d(0,@_); }


################################################################################
# Accessors


=head2 graph

Reference to the graph being traversed

=cut
has 'graph' => (
    is => 'rw',
    isa => 'Graph',
    required => 1,
    );


=head2 assembler

=cut
has 'assembler' => (
    is => 'ro',
#     isa => 'SBG::AssemblerI',
    required => 1,
    );


=head2 test


Call back function. Should return true if an edge is to be used in the
traversal. It is called as:

 my $success = $sub_test($stateclone, $graph, $src, $dest, $alt_edge_id);

=head3 B<$stateclone> 

An optional HashRef that you may pass to L<traverse>. Otherwise an empty HashRef
is used for you to store any state information. This object is cloned as
necessary during the traversal (i.e. rolling back state is automatic).

=head3 B<$graph>

The graph being traversed, as set via B<new>.

=head3 B<$src>

The source node of the multi-edge alternative under consideration

=head3 B<$dest>

The destination node of the multi-edge alternative under consideration

=head3 B<$alt_edge_id>

The name of the multi-edge alternative under consideration, as returned via:

 my @alt_edge_ids = $graph->get_edge_attribute_names($src, $dest);

You can then access this, e.g. on a L<Bio::Network::ProteinNet> via:

 my $interaction = $graph->get_interaction_by_id($alt_edge_id);


=cut



=head2 sub_solution 

Call back function. It is called when a solution has been reached, as:

 $sub_solution($stateclone, $graph, \@node_cover, \@alt_edge_cover)

It is not called when an already-seen solution is re-encountered. It is called
only once for any unique set of alternate edge IDs.

It may return whether it used/accepted the solution or not;


=head3 B<$stateclone> 

An optional HashRef that you may pass to L<traverse>. Otehrwise an empty HashRef
is used for you to store any state information. This object is cloned as
necessary during the traversal (i.e. rolling back state is automatic).

=head3 B<$graph>

The graph being traversed, as set via B<new>.

=head3 B<\@node_cover>

ArrayRef of the names of the nodes in the solution.

=head3 B<\@alt_edge_cover>

ArrayRef of the names of the alternate edge IDs in the solution graph.

=cut



=head2 minsize

The solution callback function is only called on solutions this size or
larger. Default 0.

=cut
has 'minsize' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
    );

# Queues that note the edges/nodes to be processed, in a breadth-first fashion
has '_edgeq' => (
    is => 'rw',
#     isa => 'ArrayRef[ArrayRef]',
    isa => 'Heap::Priority',
    required => 1,
    default => sub { Heap::Priority->new },
    );

has '_nodeq' => (
    is => 'rw',
#     isa => 'ArrayRef',
    isa => 'Heap::Priority',
    required => 1,
    default => sub { Heap::Priority->new },
    );


# Keep track of what's in the partial solution at every moment. Edges and nodes.
# Reset for each different starting node
has '_nodecover' => (
    is => 'rw',
    isa => 'HashRef',
    required => 1,
    default => sub { {} },
    );

# Cover of edge alternatives for the current solution
has '_altcover' => (
    is => 'rw',
    isa => 'HashRef',
    required => 1,
    default => sub { {} },
    );

# Keeps tracks of indexes on alternatives for edges, indexed by an interaction
# ID.  Resets itself when appropriate.
has '_altidx' => (
    is => 'rw',
    isa => 'HashRef[Int]',
    required => 1,
    default => sub { {} },
    );

# Sorted lits of alternatives for each of NxN possible edges
has '_altlist' => (
    is => 'rw',
    isa => 'HashRef[ArrayRef[Str]]',
    required => 1,
    default => sub { {} },
    );


# Keeps track of what complete graph coverings have already been created. 
# Tracked across different starting nodes.
has '_solved' => (
    is => 'rw',
    isa => 'HashRef[Bool]',
    required => 1,
    default => sub { {} },
    );


# TODO DOC
# Number of paths aborted (i.e. time saved) during traversal
has 'rejects' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);


# Count solutions accepted by the callback function
has 'asolutions' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

# Total duplicated solutions (determined without callback function)
has 'dsolutions' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);


# Count solutions rejected by the callback function
has 'rsolutions' => (
    is => 'rw',
    isa => 'Int',
    default => 0,

);



################################################################################
# Public


################################################################################
=head2 traverse

 Function:
 Example :
 Returns : 
 Args    : $state - An optional object (HashRef) to store state information.

If no B<$state> is provided, an empty HashRef is used. You can later put your
own data into this, when it is provided to your callback functions.

If B<$state> implements Perl's L<Clone> interface, that will be used to clone
the object, as needed. Otherwise, the standard B<Clone::clone> method is used.

Each vertex in the graph is used as the starting node one time.  This is because
different traversals could theoretically produce different results.

=cut

sub traverse {
    my ($self, $state) = @_;
    # If no state object provide, use an empty hashref, Clone'able
    $state = bless({}, 'Clone') unless defined $state;
    
    $self->_init_edge_indices;

    # NB cannot use all nodes together in one run, as they may have different
    # 'frames of reference'. I.e. don't do this:
#     $self->_nodeq->push($self->graph->vertices);

    # Using one different starting node in each iteration
    foreach my $node ($self->_init_nodes) {
        # Starting node for this iteraction
        $self->_nodeq->add($node);
        _d0 "\n", ("=" x 80), "\nStart node: $node";
        # A new disjoint set data structure, to track which nodes in same sets
        my $uf = new Graph::UnionFind;
        # Each node is in its own set first
        $uf->add($_) for $self->graph->vertices;
        # Reset
        $self->_altcover({});
        $self->_nodecover({});
        # Start with a fresh state object, not defiled from previous rounds
        my $clone = $state->clone();
        # Go!
        $self->_do_nodes($uf, $clone, 0);
    }
    # Number accepted solutions;
    return $self->asolutions;
} # traverse



# Sort the alternatives available to each possible edge initially
# Later, we'll just index into these lists, w/o having to re-sort
sub _init_edge_indices {
    my ($self) = @_;
    my @nodes = $self->graph->vertices;
    for (my $i = 0; $i < @nodes; $i++) {
        my $u = $nodes[$i];
        for (my $j = $i+1; $j < @nodes; $j++) {
            my $v = $nodes[$j];
            my @alt_ids = sort {
                $self->assembler->score($self->graph, $b) <=>
                    $self->assembler->score($self->graph, $a)
            } $self->graph->get_edge_attribute_names($u, $v);  
            log()->trace("$u $v : @alt_ids");
            $self->_altlist->put("$u--$v", \@alt_ids);
            $self->_altlist->put("$v--$u", \@alt_ids);
        }
    }
}


# Sorts the nodes according to their highest-scoring incident interactions
sub _init_nodes {
    my ($self) = @_;
    my %max;
    my @nodes = $self->graph->vertices;
    # Map stringification to object
    my %nodes = map { $_ => $_ } @nodes;
    foreach my $u (@nodes) {
        foreach my $v ($self->graph->vertices) {
            my $max = $self->_edge_max($u,$v) or next;
            $max{$u} ||= $max;
            $max{$u} = $max if $max > $max{$u};
            $max{$v} ||= $max;
            $max{$v} = $max if $max > $max{$v};
        }
    }
    my @maxes = sort { $max{$b} <=> $max{$a} } keys %max;
    log()->trace("nodes ordered by _edge_max:@maxes");
    # Map string names back to objects
    @nodes = map { $nodes{$_} } @maxes;
    return @nodes;
}


# The score of the next alternative that would be tried on the given edge
sub _edge_max {
    my ($self, $u, $v) = @_;
    # Name of edge
    my $edge_id = "$u--$v";
#     log()->trace("edge_id:$edge_id");
    # Index of next alternative on this edge, or begin at 0
    my $altidx = $self->_altidx->at($edge_id) || 0;
#     log()->trace("altidx:$altidx");
    # The identify of that index in this edge's list of alternatives:
    my $altlist = $self->_altlist->at($edge_id) or return;
#     log()->trace("altlist:@$altlist");
    my $altid = $altlist->[$altidx] or return;
#     log()->trace("altid:$altid");
    my $score = $self->assembler->score($self->graph, $altid);
    log()->trace("edge:$edge_id alt:$altid score:$score");
    return $score;
}


# Looks for any edges on any outstanding nodes
sub _do_nodes {
    my ($self, $uf, $state, $d) = @_;
    my $current = $self->_nodeq->pop;
    return $self->_no_nodes($uf, $state, $d) unless $current;

    # Which adjacent nodes have not yet been visited
    _d $d, "Node: $current";
    my @unseen = $self->_new_neighbors($current, $uf, $d);
    for my $neighbor (@unseen) {
        # push edges onto stack
        _d $d, "pushing edge: $current--$neighbor";
        # priority queue, based on average alternative score of edge
        my $edge_max = $self->_edge_max($current, $neighbor);
        $self->_edgeq->add([$current, $neighbor], $edge_max);
    }
    # Continue processing all outstanding nodes before moving to edges
    # Tail recursion is flattened here
    defined($DB::sub) ? 
        $self->_do_nodes($uf, $state, $d) : recur($self, $uf, $state, $d);
    _d $d, "<= Node: $current";
} # _do_nodes


# Called when no nodes left, switches to edges, if any
sub _no_nodes {
    my ($self, $uf, $state, $d) = @_;
    _d $d, "No more nodes";
    my $nedges = scalar $self->_edgeq->get_heap;
    if ($nedges) {
        _d $d, "Edges: $nedges";
        $self->_do_edges($uf, $state, $d+1);
    } else {
        $self->_do_solution($state, $d);
    }
    return;
} # _no_nodes


# Processing any outstanding edges
# For each, gets the next alternative
# Try to validate the alternative based on the provided callback function
# Recurses to exhaust all possibilities
sub _do_edges {
    my ($self, $uf, $state, $d) = @_;
    my $current = $self->_edgeq->pop;
    return $self->_no_edges($uf, $state, $d) unless $current;
    my ($src, $dest) = @$current;
    _d $d, "Edge:$src--$dest";

    # ID of next alternative to try on this edge, if any
    my $alt_id = $self->_next_alt($src, $dest, $d);
    unless ($alt_id) {
        # No more unprocessed multiedges remain between these nodes: $src,$dest
        _d $d, "No more alternative edges for $src $dest";
        # Try any other outstanding edges at this depth first, though
        # Tail recursion is flattened here
        defined($DB::sub) ? 
            $self->_do_edges($uf, $state, $d) : recur($self,$uf, $state, $d);
        return;
    }

    # As child nodes in traversal may change partial solutions, clone these.
    # This implicitly allows us to backtrack later if $test() fails, etc
    my $stateclone = $state->clone();

    # Do we want to go ahead and traverse this edge?
    $self->_test_alt($uf, $stateclone, $src, $dest, $alt_id, $d);

    # After alt. edge is tested, remaining alternatives on that edge tested also
    # 2nd recursion here. This is because we wait for the previous round to
    # finish, with all of it's chosen edges, before retrying alternatives on any
    # of the edges. Assumption is that multi-edges are incompatible. That's why
    # we wait until now to re-push them.
    # Back onto priority queue
    $self->_edgeq->add($current, $self->_edge_max(@$current));
    # Go back to using the original $state that we had before this alternative
    # Tail recursion is flattened here
    defined($DB::sub) ? 
        $self->_do_edges($uf, $state, $d) : recur($self, $uf, $state, $d);
    
} # _do_edges


# Test an alternative for an edge 
sub _test_alt {
    my ($self, $uf, $stateclone, $src, $dest, $alt_id, $d) = @_;

    # Do we want to go ahead and traverse this edge?
    my $score = $self->assembler->test(
        $stateclone, $self->graph, $src, $dest, $alt_id);

    if (! defined $score) {
        # Current edge was rejected, but alternative multiedges may remain
        $self->rejects($self->rejects + 1);
        _d $d, "Pruned path (" . $self->rejects . ")";
        # Continue using the same state, in case the failure must be remembered
        # Flatten the indirect recursion by turning a tail call into a goto
        if (defined($DB::sub)) {
            $self->_do_edges($uf, $stateclone, $d);
        } else {
            @_ = ($self, $uf, $stateclone, $d);
            goto \&_do_edges;
        }
    } else {
        # Edge alternative succeeded. 
        _d $d, "Succeeded. Node $dest reachable";
        $self->_altcover->put($alt_id, $alt_id);
        unless ($self->_nodecover->exists($src)) {
            $self->_nodecover->put($src, $src);
        }
        $self->_nodecover->put($dest, $dest);

        # priority queue: Node has a placement score here,
        $self->_nodeq->add($dest, $score);

        # $src and $dest are now in the same connected component. 
        # But clone this first, to be able to undo/backtrack afterward
        my $ufclone = clone($uf);
        $ufclone->union($src, $dest);
        # Recursive call to traverse rest of graph, beyond this edge
        # Continue using the same state, in case the success must be remembered
        # NB Cannot eliminate recursion here as we still need a rollback after
        $self->_do_edges($ufclone, $stateclone, $d);
        # Backtrack to before this alternative was accepted
        $self->_altcover->delete($alt_id);
        $self->_nodecover->delete($dest);
    }
    _d $d, "<= Edge: $src $dest";
    _d $d, "Node cover: ", $self->_nodecover->keys->sort->join(' ');

} # _test_alt


# Called when no edges left, switches to processing nodes, if any
sub _no_edges {
    my ($self, $uf, $state, $d) = @_;
    _d $d, "No more edges";
    # When no edges left on stack, go to next level down in BFS traversal tree
    # I.e. process outstanding nodes
    my $nnodes = scalar $self->_nodeq->get_heap;
    if ($nnodes) {
        _d $d, "Nodes: $nnodes";
        # Also give the progressive solution to peripheral nodes
        $self->_do_nodes($uf, $state, $d+1);
    } else {
        # Partial solution
        $self->_do_solution($state, $d);
    }
    return;
} # _no_edges


# Uses a L<Graph::UnionFind> to keep track of nodes in the graph (the
# other graph, the one being traversed), that are still to be visited.
sub _new_neighbors {
    my ($self, $node, $uf, $d) = @_;

    my @adj = $self->graph->neighbors($node);
    # Only adjacent vertices not already in same traversal set (i.e. the unseen)
    my @unseen = grep { ! $uf->same($node, $_) } @adj;

    _d $d, "adjacent @adj; unseen: @unseen";
    return @unseen;
}


# Get ID of next alternative for a given edge $u,$v
sub _next_alt {
    my ($self, $u, $v, $d) = @_;
    # A label for the current edge, regardless of alternative
    my $edge_id = "$u--$v";
    # List of names of alternatives on this edge
    my $altlist = $self->_altlist->at($edge_id) or return;
    # Tells us the index of which alternative to try next on this edge
    my $altidx = $self->_altidx->at($edge_id) || 0;

    # If no alternatives (left) to try, cannot use this edge
    unless ($altidx < $altlist->length) {
        _d $d, "No more templates";
        # Now reset, for any subsequent, independent attempts on this edge
        $self->_altidx->put($edge_id, 0);
        return;
    }

    _d $d, "Alternative: ", 1+$altidx, "/" . $altlist->length;

    # The ID of the chosen alternative
    my $altid = $altlist->[$altidx];
    # Next time, take the next one;
    $self->_altidx->put($edge_id, $altidx+1);

    return $altid;

} # _next_alt


# Partial solution.  
# Assumes that the edges alternatives can be strinigified and
# that the stringifications are unique.

sub _do_solution {
    my ($self, $state, $d) = @_;


    my $nodes = $self->_nodecover->values;
    my $alts = $self->_altcover->values;
    return unless $alts->length;
    return if $self->minsize > $nodes->length;

    my $solution_label = $alts->sort->join(',');
    my $nidentical = $self->_solved->at($solution_label);
    if ($nidentical) {
        _d $d, "Duplicate solution: $solution_label";
        $self->_solved->put($solution_label, ++$nidentical);
        $self->dsolutions($self->dsolutions+1);
        return;
    } else {
        $self->_solved->put($solution_label, 1);
    }


    log()->debug("Potential solution: $solution_label");
    if ($self->assembler->solution(
            $state, $self->graph, $nodes, $alts, $self->rejects)) {
        $self->asolutions($self->asolutions+1);
        log()->trace("Accepted solution: $solution_label");
    } else {
        $self->rsolutions($self->rsolutions+1);
        log()->trace("Rejected solution: $solution_label");
    }


} # _do_solution

# Sort hash by value
sub _byvalue {
    my ($hash) = @_;
    my $keys = $hash->keys;
    my $values = [ sort { $hash->at($a) <=> $hash->at($b) } @$keys ];
    return $values;
}


# Convert 2D array to string list, e.g.:
# red--blue; alpha--beta; apples--oranges
sub _array2D {
    return join("; ", map { join("--", @$_) } @{$_[0]});
}


sub DEMOLISH {
    my ($self) = @_;
    
    # TODO Shouldn't need this
    $self->assembler->solution();

    $log->info("rejected paths: " . $self->rejects);
    $log->info("rejected solutions: " . $self->rsolutions);
    $log->info("duplicate solutions: " . $self->dsolutions);
    $log->info("accepted solutions: " . $self->asolutions);
}


###############################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
