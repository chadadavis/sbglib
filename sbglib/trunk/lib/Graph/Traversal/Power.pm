#!/usr/bin/env perl


=head1 NAME

Graph::Traversal::Power - Traversal based interdependent edges

=head1 SYNOPSIS


=head1 DESCRIPTION

Similar to L<Graph::Traversal::BFS> (breadth-first search), but specifically for multigraphs, in which

each of the many edges between two nodes represent different alteratives for reach one destination node from a source node. Graphs may also contain other restrictions 


For a given source node, considers the powerset of outgoing edges and uses a
callback object to determine which of those are viable. As soon as a viable
subset of outbound edges to the next depth of nodes is found, those nodes at the
next dept are processed, in a depth first fashion.


Multi-edges are defined by edge attributes on a L<Graph>. The name of the attribute is a label for the multi-edge; the value of the attribute 


Works on L<Graph>, but assumes that multiple edges are stored as attributes of a
single edge between unique nodes. This is also the pattern used by
L<Bio::Network::ProteinNet>.


=head1 SEE ALSO

L<Graph::Traversal> 

=cut

package Graph::Traversal::Power;
use Moose;
use Moose::Autobox;
use Graph;
use Graph::UnionFind;
use Bit::Vector::Overload;
Bit::Vector->Configuration("in=enum,out=bin");
use Log::Any qw/$log/;




=head1 Attributes

=cut 

=head2 graph

Reference to the graph being traversed

=cut
has 'graph' => (
    is => 'rw',
    isa => 'Graph',
    required => 1,
    handles => [qw/neighbors vertices/],
    );


=head2 assembler

Call back object

=cut
has 'assembler' => (
    is => 'ro',
# TODO enforce role
#     does => 'SBG::AssemblerI',
    required => 1,
    );



=head2 minsize

The solution callback function is only called on solutions this size or
larger. Default 0.

=cut
has 'minsize' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
    );




=head1 Methods

=cut

=head2 traverse

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub traverse {
    my ($self) = @_;

    my $nodes = $self->_init_nodes;
    my $results = $nodes->map(sub{$self->_start_one($_)});
    my $finished = $results->grep(sub{defined $_});
    return $self->assembler->finished($finished);
}


# Get the list of start nodes, in order of priority
sub _init_nodes {
    my ($self) = @_;
    my $nodes = [ $self->graph->vertices ];
    $nodes = $nodes->sort;
    return $nodes;
}


sub _start_one {
    my ($self, $startnode) = @_;
    my $nodeq = [$startnode];
    my $sedges = $self->_expand_nodes([$startnode]);

    $sedges = $sedges->sort;

#     return $self->_do_level($sedges);
}


# Given Array of nodes, returns Array of sedges
sub _expand_nodes {
    my ($self, $nodes) = @_;
    my $edges = $nodes->map(sub{$self->_node2edges});
    my $sedges = $edges->map(sub{$self->_edge2sedges});
    return $sedges;
}


sub _node2edges {
    # TODO 
}


sub _edge2sedges {
    my ($self, $src, $dests) = @_;
    my $sedges_a = [];
    foreach my $dest (@$dests) {
        my $sedges_h = { $self->graph->get_edge_attributes($src, $dest) };
        
        # TODO If edge has no attributes, add one for the single edge
        # Required for this to work on simple graphs

        # Create an array of objects from the hash
        $sedges_a->push( $sedges_h->hslice([$_])) for $sedges_h->keys;
        $sedges_a->map(sub{ $_->{src}=$src; $_->{dest}=$dest });

        # TODO BUG score?
        $sedges_a->map(sub{ $_->{score}= 0  });
    }
} # _edges2sedges


# Consume the entire node queue, get all down edges, then subedges
# Sorts and indexes sedges
sub _nodes2sedges {
    my ($self, $nodeq) = @_;
    # Set of sedges expanding out from this level
    my $sedges_level = [];
    # For all reachable nodes, collect all possible edges to get there,
    while (my $node = $nodeq->pop) {
        my $dests = $self->_neighbors($node);
        my $sedgeids = $self->_edge2sedges($node, $dests);
        $sedges_level->push($sedgeids->flatten);
    }    

    # TODO Sort sedges ascending by score, i.e. best last
    # ...
    my $sedge_index = 
    { map { $sedges_level->[$_] => $_ } (0..$sedges_level->length-1) };

    return $sedges_level, $sedge_index;

} # _nodes2edges 




sub _neighbors {
    my ($self, $node, $uf) = @_;
    # Nodes not yet seen 
    my $down = [];
    my $cross = [];
    foreach my $adjacent ($self->graph->neighbors($node)) {
        # Unseen neighbor
        if (! $uf->same($node, $adjacent)) {
            $down->push($adjacent);
            next;
        }
        # Previously seen neighbor
        $cross->push($adjacent);
    }
    # TODO add cross edges to detect cycles, optionally
    # TODO detect the one back sedge?
    return $down;
}


sub conflict_mask {
    my ($map, $conflict) = @_;
    my $indices = $map->slice($conflict);
    my $mask = Bit::Vector->new($map->keys->length);
    $mask->from_Enum($indices->join(','));
    print "mask:$mask:\n";
    return $mask;
}


sub bitstr2indices {
    my $str = shift;
    # Bit str has index 0 on the right, so reverse it
    my @bits =  split //, reverse $str;
    my @indices = grep { $bits[$_] } (0..$#bits);
    return @indices;
}



sub _edge_max {
    my ($graph, $edge) = @_;
    return 1.0;
}


###############################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__


sub _do_level {
    my ($subedges) = @_;

    # The level stack, whereby a level is depth from the start node
    my $edgeq = [];

  do_nodes:
    # TODO Solution here if no nodes?
    my $edges = $nodeq->map(sub{node2edges($_)});
    my $sedges = $edges->map(sub{edge2sedges($_)});

    
    # TODO BUG if we put the bitvector on the stack, still need to track what the indexes index into, assuming we only have a local index for sedges at the current level. That has to go on the stack too. Unravelling recursion is recursive ...


    my $bitvector = Bit::Vector->new(scalar @$sedges);
# Set all to enabled, and count down to empty set
    $bitvector->Fill;

    # Get the powerset of all the sedges (set min=>1 to skip the empty set)
    my $powerset = Data::PowerSet->new({min=>1}, @$sedges_level);
    # Add push it onto the edge stack
    $edgeq->push($powerset);

    # TODO Solution here when nodes all processed?

  do_edges:

    # TODO solution here when no edges?

    # As long as there are levels to process
    while (my $bitvector = $edgeq->pop) {
        
        # As long as a level still has set of sedges to consider
      sedge_set: for (; $bitvector; $bitvector--) {
          
          print "$bitvector : ";
     
          foreach (@$eblacklist) {
              # See if the mask is a subset of the $bitvector (ie if it applies)
              if ($_ < $bitvector) { 
                  $log->debug("masked by $_");
                  print "masked\n"; 
                  next;
              }
          }

          my $sedge_set = $sedges->slice(bitstr2indices("$bitvector"))->reverse;

          # Try one subset of subedges
          my ($successes, $conflicts) = $self->try($sedge_set);

          foreach my $conflict (@$conflicts) {
              # Blacklist , after converting back to bitvector
              $eblacklist->push(conflict_mask($sedge2idx, $conflict));
          }

          next unless $successes && $successes->length > 0;

          foreach my $success (@$successes) {
              
              # Map sedges to dest nodes
              # Add dest nodes to $uf->union($sedge->dest)
                # Convert to list of sedges
                # Map to destination nodes
              my $dest = $success->map(sub{$_->dest});
              # Push onto node stack
              $nodeq->push($dest);
          }
            
          # Do not continue looking at edge sets.
          # Rather go to next level of nodes
          # Push this poweredge back onto the edge stack (index remembered)
          $edgeq->push($bitvector);
          goto do_nodes;

      } # for each sedge subset
    } # For each power edge

} # _do_level

