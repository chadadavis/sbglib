#!/usr/bin/env perl


=head1 NAME

Graph::Traversal::GreedyEdges - Traverses graph in the order of Kruskal's MST,
but skips incompatible edges and continues with remaining edges.

=head1 SYNOPSIS


=head1 DESCRIPTION

Similar to L<Graph::Traversal::BFS> (breadth-first search), but specifically for
multigraphs, in which ...

=head1 SEE ALSO

L<Graph::Traversal> 

=cut

package Graph::Traversal::GreedyEdges;
use Moose;
use Moose::Autobox;
use subs::parallel;
use Graph;

use Log::Any qw/$log/;
use Scalar::Util qw/blessed/;
use Data::Dump qw/dump/;
use SBG::U::List qw/reorder/;
use Graph::UnionFind;

use Bio::Network::ProteinNet;

################################################################################

=head1 Attributes

=cut 

=head2 graph

Reference to the graph being traversed

=cut
has 'net' => (
    is => 'rw',
    isa => 'SBG::Network',
    required => 1,
    handles => [qw/neighbors vertices edges interactions/],
    );


=head2 assembler

Call back object

TODO BUG cannot enforce SBG::AssemblerI when using TestAssembler
=cut
has 'assembler' => (
    is => 'ro',
#     does => 'SBG::AssemblerI',
    required => 1,
    );


################################################################################
=head2 sorter

 Function: 
 Example : 
 Returns : 
 Args    : 

Applied to a list of L<SBG::Interaction>, determines which B<scores> field to
sort by.

=cut
has 'sorter' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    default => "default",
    );


################################################################################
=head2 minsize

The solution callback function is only called on solutions this size or
larger. Default 0.

=cut
has 'minsize' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
    );



################################################################################
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

    # A new disjoint set data structure, to track which nodes in same sets
    my $uf = Graph::UnionFind->new;
    # Graph of solution(s) topology
    my $solutions = SBG::Network->new;
    # All interaction templates, sorted by best score
    my $iactions = $self->interactions_by_field($self->sorter);

    foreach my $iaction (@$iactions) {
        # Skip if solution graph already has an interaction modelling the edge
        if ($solutions->has_edge($iaction->nodes)) {
            $log->debug(join('--',$iaction->nodes), " already covered");
            next;
        }
        
        # Resulting complex, after (possibly) merging two disconnected complexes
        my $merged_complex;
        # Score for placing this interaction into the solutions complex forest
        my $merged_score;

        # Doesn't matter which we consider to be the source/dest node
        my ($src,$dest) = $iaction->nodes;

        if (! $uf->has($src) && ! $uf->has($dest) ) {
            # Neither node present in solutions forest
            # Create a dimer, update forest
            $merged_complex = SBG::Complex->new;
            $merged_score = 
                $merged_complex->add_interaction($iaction, $iaction->keys);
        } elsif ($uf->has($src) && $uf->has($dest)) {

           # Both nodes present in existing complexes
           if ($uf->same($src,$dest)) {

               # Nodes in same complex tree already, attempted ring closure
               my $partition_node = $uf->find($src);
               $merged_complex = 
                   $self->net->get_vertex_attribute($partition_node,'complex');
               # Difference from 10 to get something in range [0:10]
               $merged_score = 10 - $merged_complex->cycle($iaction);
           } else {
                # Nodes in separate complexes, merge into single frame-of-ref
                
                my $src_partition = $uf->find($src);
                my $src_complex = 
                    $self->net->get_vertex_attribute($src_partition,'complex');
                my $dest_partition = $uf->find($dest);
                my $dest_complex = 
                    $self->net->get_vertex_attribute($dest_partition,'complex');

                $merged_score = 
                    $src_complex->merge_interaction($dest_complex, $iaction);
                $merged_complex = $src_complex;
           }
        } else {
            # Only one node in a complex tree, other is new (a monomer)
            if ($uf->has($src)) {
                # Create dimer from $dest, then merge on $src
                ($merged_complex, $merged_score) = 
                    $self->_add_monomer($uf, $iaction,$src,$dest);
            } else {
                # Create dimer from $src, then merge on $dest
                ($merged_complex, $merged_score) = 
                    $self->_add_monomer($uf, $iaction,$dest, $src);
            }
        }

        # If merging succeeded
        if (defined $merged_score) {
            # Update reference complex of each node: $src and $dest
            $self->net->set_vertex_attribute($src,'complex',$merged_complex);
#             $self->net->set_vertex_attribute($merged_complex,'complex',$src);
            $self->net->set_vertex_attribute($dest,'complex',$merged_complex);
#             $self->net->set_vertex_attribute($merged_complex,'complex',$dest);

            # Copy interaction to solution network
            $solutions->add_interaction(-nodes=>[$iaction->nodes],
                                       -interaction=>$iaction);

            # Note that these nodes are now connected
            $uf->union($src,$dest);

            # Every successfully modelled interaction creates a new model
            # This is the merged complex
            $self->assembler->solution(
                $merged_complex, $self->net, 
                [$solutions->nodes], [$solutions->interactions]);
        }

    } # foreach $iaction

} # traverse


################################################################################
=head2 _add_monomer

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub _add_monomer {
    my ($self,$uf, $iaction,$ref) = @_;

    # Create complex out of a single interaction
    my $add_complex = SBG::Complex->new;
    $add_complex->add_interaction($iaction, $iaction->keys);

    # Lookup complex to which we want to add the interaction
    my $ref_partition = $uf->find($ref);
    my $ref_complex = 
        $self->net->get_vertex_attribute($ref_partition,'complex');

    my $merged_score = $ref_complex->merge_domain($add_complex, $ref);

    return ($ref_complex, $merged_score);

} # _add_monomer


################################################################################
=head2 interactions_by_field

 Function: 
 Example : 
 Returns : 
 Args    : 

Return interactions, sorted by the named interaction score. An interaction may
have more than one score, and therefore more than one way of being ordered among
other interactions.

=cut
sub interactions_by_field {
    my ($self, $field) = @_;

    # Sort by user-defined 'scores' field (in SBG::Interaction)
    $field ||= $self->sorter;

    # Get all interactions in network, over all edges
    my $iactions = [ $self->interactions ];

    my $asc = reorder($iactions, 
                      undef, 
                      sub { $_->scores->at($field) });
    # TODO descending or ascending could be an option
    my $desc = $asc->reverse;
    return $desc;
} # interactions_by_field


###############################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
