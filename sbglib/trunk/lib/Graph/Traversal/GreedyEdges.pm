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
    $log->debug("interactions: ", $iactions->length);

    # Start recursion at interaction 0
    $self->_recurse($iactions, 0, $state);

    $log->debug('End');

} # traverse


sub _recurse {
    my ($self, $iactions, $i, $state) = @_;
    $log->debug("i:$i");
    return unless $i < $iactions->length;
    my $iaction = $iactions->[$i];
    $log->debug("i:$i $iaction");

    # Resulting complex, after (possibly) merging two disconnected complexes
    my ($merged_complex, $merged_score) = 
        $self->_try_iaction($state, $iaction);

    if (defined $merged_score) {
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
        $self->assembler->solution($merged_complex, $state_clone) 
            if $merged_complex->size > 2;

        # Recursive call, only when interaction was successfully added
        # Starts with next interaction in the list: $i+1
        # NB this isn't tail recursion and cannot be unrolled, we need to return
        $log->debug("i:$i Recursing, with   : $iaction");
        $self->_recurse($iactions, $i+1, $state_clone);
        
        $log->debug("i:$i Returned after placing iaction.");
    } 

    # Whether successful or not, now tail recurse to the next iaction,
    # Here were using the original state, i.e. before any interaction modelled
    $log->debug("i:$i Recursing, without: $iaction");
    # Tail recursion is flattened here, unless debugger active
    if (defined $DB::sub) {
        $self->_recurse($iactions, $i+1, $state);
    } else {
        # Flatten tail recursion with a goto, squashing the call stack
        @_ = ($self, $iactions, $i+1, $state);
        goto \&_recurse;
    }

    # Not reached if using tail recursion
    $log->debug("i:$i Returned after not placing iaction.");

} # _recurse


# A number of cases might be applicable, depending on network connectivity
sub _try_iaction {
    my ($self, $state, $iaction) = @_;
    # Skip if already covered
    if ($state->{'net'}->has_edge($iaction->nodes)) {
        $log->debug("Edge already covered: $iaction");
        return;
    }

    # Doesn't matter which we consider to be the source/dest node
    my ($src,$dest) = $iaction->nodes;
    my $uf = $state->{'uf'};

    # Resulting complex, after (possibly) merging two disconnected complexes
    my $merged_complex;
    # Score for placing this interaction into the solutions complex forest
    my $merged_score;

    if (! $uf->has($src) && ! $uf->has($dest) ) {
        # Neither node present in solutions forest. Create dimer
        $merged_complex = SBG::Complex->new;
        $merged_score = 
            $merged_complex->add_interaction($iaction, $iaction->keys);
        
    } elsif ($uf->has($src) && $uf->has($dest)) {
        # Both nodes present in existing complexes
        
        if ($uf->same($src,$dest)) {
            # Nodes in same complex tree already, attempt ring closure
            ($merged_complex, $merged_score) = 
                $self->_cycle($state, $iaction);
            
        } else {
            # Nodes in separate complexes, merge into single frame-of-ref
            ($merged_complex, $merged_score) = 
                $self->_merge($state, $iaction);

        }
    } else {
        # Only one node in a complex tree, other is new (a monomer)
        
        if ($uf->has($src)) {
            # Create dimer, then merge on $src
            ($merged_complex, $merged_score) = 
                $self->_add_monomer($state, $iaction, $src);
            
        } else {
            # Create dimer, then merge on $dest
            ($merged_complex, $merged_score) = 
                $self->_add_monomer($state, $iaction, $dest);
        }
    }
    
    return ($merged_complex, $merged_score);
} # _try_iaction


# Closes a cycle, using a *known* interaction template
# (i.e. novel interactions not detected at this stage)
sub _cycle {
    my ($self, $state, $iaction) = @_;
    $log->debug($iaction);
    # Take either end of the interaction, since they belong to same complex
    my ($src, $dest) = $iaction->nodes;
    my $partition = $state->{'uf'}->find($src);
    my $complex = $state->{'models'}->{$partition};

    # Modify a copy
    # TODO store these thresholds (configurably) elsewhere
    my $merged_complex = $complex->clone;
    # Difference from 10 to get something in range [0:10]
    my $irmsd = $merged_complex->cycle($iaction);
    return unless defined($irmsd) && $irmsd < 15;
    # Give this a ring bonus of +10, since it closes a ring
    # Normally a STAMP score gives no better than 10
    my $merged_score = 20 - $irmsd;
    
    return ($merged_complex, $merged_score);
} # _cycle


# Merge two complexes, into a common spacial frame of reference
sub _merge {
    my ($self, $state, $iaction) = @_;
    $log->debug($iaction);
    # Order irrelevant, as merging is symmetric
    my ($src, $dest) = $iaction->nodes;

    my $src_part = $state->{'uf'}->find($src);
    my $src_complex = $state->{'models'}->{$src_part};
    my $dest_part = $state->{'uf'}->find($dest);
    my $dest_complex = $state->{'models'}->{$dest_part};

    my $merged_complex = $src_complex->clone;
    my $merged_score = $merged_complex->merge_interaction($dest_complex,$iaction);

    return ($merged_complex, $merged_score);
} # _merge


################################################################################
=head2 _add_monomer

 Function: 
 Example : 
 Returns : 
 Args    : 

Add a single component to an existing complex, using the given interaction.

One component in the interaction is homologous to a component ($ref) in the model

=cut
sub _add_monomer {
    my ($self, $state, $iaction, $ref) = @_;
    $log->debug($iaction);
    # Create complex out of a single interaction
    my $add_complex = SBG::Complex->new;
    $add_complex->add_interaction($iaction, $iaction->keys);

    # Lookup complex to which we want to add the interaction
    my $ref_partition = $state->{'uf'}->find($ref);
    my $ref_complex = $state->{'models'}->{$ref_partition};
    my $merged_complex = $ref_complex->clone;
    my $merged_score = $merged_complex->merge_domain($add_complex, $ref);

    return ($merged_complex, $merged_score);

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
    my @iactions = $self->interactions;
    my @desc = sort { $b->scores->{$field} <=> $a->scores->{$field} } @iactions;
    return [ @desc ];

} # interactions_by_field


###############################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
