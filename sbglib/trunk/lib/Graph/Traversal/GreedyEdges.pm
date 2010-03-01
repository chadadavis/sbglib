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

use Log::Any qw/$log/;
use Scalar::Util qw/blessed refaddr/;
use Data::Dump qw/dump/;
use Graph;
use Graph::UnionFind;
use Bio::Network::ProteinNet;
use Storable qw/dclone/;

use SBG::Complex;


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
    # Graph of current solution topology
    my $net = SBG::Network->new;
    # Each connected component in the solution interaction network is a complex
    my $models = {};
    # Wrap these three things into a single state object
    my $state = {
        uf => $uf,
        net => $net,
        models => $models,
    };

    # All interaction templates, sorted descending by the field $self->sorter
    my $iactions = $self->interactions_by_field($self->sorter);
    $log->info("interactions: ", $iactions->length);

    # Start recursion at interaction 0
    $self->_recurse($iactions, 0, $state);

    $log->info('End');

} # traverse


sub _recurse {
    my ($self, $iactions, $i, $state, $leftmost) = @_;

    $log->debug('leftmost:' . ($leftmost || 'undef') . " i:$i");
    return unless $i < $iactions->length;
    my $iaction = $iactions->[$i];
    $log->debug("i:$i $iaction");

    # Resulting complex, after (possibly) merging two disconnected complexes
    my ($merged_complex, $merged_score) = 
        $self->assembler->test($state, $iaction);

    if (defined $merged_score) {
        unless (defined $leftmost) {
            $leftmost = $i;
            $log->info("leftmost: $leftmost");
        }

        # Clone state, add interaction to cloned state, recurse on next iaction
        my $state_clone = dclone($state);
        # Now update the cloned state with the placed interaction

        # Note that these nodes are now connected
        my ($src, $dest) = $iaction->nodes;
        $state_clone->{'uf'}->union($src,$dest);

        # Update reference complex of each node: $src and $dest
        # After the union, $src and $dest are found in the same partition
        my $partition = $state_clone->{'uf'}->find($src);
        $state_clone->{'models'}->{$partition} = $merged_complex;

        # Copy interaction to solution network
        $state_clone->{'net'}->add_interaction(-nodes=>[$iaction->nodes],
                                               -interaction=>$iaction);
        
        # Every successfully modelled interaction creates a new solution model
        $self->assembler->solution($state_clone, $partition);

        # Recursive call, only when interaction was successfully added
        # Starts with next interaction in the list: $i+1
        # NB this isn't tail recursion and cannot be unrolled, we need to return
        $log->debug("i:$i Recursing, with   : $iaction");
        $self->_recurse($iactions, $i+1, $state_clone, $leftmost);
        
        $log->debug("i:$i Returned after placing iaction.");
    } 

    # Whether successful or not, now tail recurse to the next iaction,
    # Here were using the original state, i.e. before any interaction modelled
    $log->debug("i:$i Recursing, without: $iaction");
    $leftmost = undef if $leftmost == $i;
    # Tail recursion is flattened here, unless debugger active
    if (defined $DB::sub) {
        $self->_recurse($iactions, $i+1, $state, $leftmost);
    } else {
        # Flatten tail recursion with a goto, squashing the call stack
        @_ = ($self, $iactions, $i+1, $state, $leftmost);
        goto \&_recurse;
    }

    # Not reached if using tail recursion
    $log->debug("i:$i Returned after not placing iaction.");

} # _recurse



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
    my @iactions = $self->interactions;
#     my @desc = sort { $b->scores->{$field} <=> $a->scores->{$field} } @iactions;
    my @desc = sort { $b->weight <=> $a->weight } @iactions;
    return [ @desc ];

} # interactions_by_field


###############################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
