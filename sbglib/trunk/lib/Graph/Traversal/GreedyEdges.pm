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

# Manual tail call optimization
use Sub::Call::Recur qw/recur/;
use subs::parallel;
use Clone qw/clone/;

use SBG::U::List qw/reorder/;


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
=head2 _subcomplex

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has '_subcomplex' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
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
    # Graph of solution(s) topology
    my $solution = SBG::Network->new;
    # All interaction templates, sorted by best score
    my $iactions = $self->interactions_by_field($self->sorter);

    $self->_recurse($iactions, 0, $uf, $solution);

} # traverse


sub _recurse {
    my ($self, $iactions, $i, $uf, $solution) = @_;
    my $iaction = $iactions->[$i] or return;

    $log->debug("$i $iaction");

    # Resulting complex, after (possibly) merging two disconnected complexes
    my ($merged_complex, $merged_score) = 
        $self->_try_iaction($uf, $solution, $iaction);

    if (defined $merged_score) {
        # Clone state, add interaction to cloned state, recurse on next iaction

        my $uf_clone = clone($uf);
        $self->_subcomplex->{refaddr($uf_clone)} = {};

        # TODO DES verify that depth 2 is a sufficient short-cut
#         my $solution_clone = clone($solution, 2);
        my $solution_clone = clone($solution);

        # Now update the cloned state with the placed interaction

        # Note that these nodes are now connected
        my ($src, $dest) = $iaction->nodes;
        $uf_clone->union($src,$dest);

        # Update reference complex of each node: $src and $dest
        # After the unioni, $src and $dest are found in the same partition
        my $partition = $uf_clone->find($src);
        $self->_subcomplex->{refaddr($uf_clone)}{$partition} = $merged_complex;

        # Copy interaction to solution network
        $solution_clone->add_interaction(-nodes=>[$iaction->nodes],
                                         -interaction=>$iaction);
        
        # Every successfully modelled interaction creates a new solution model
        $self->assembler->solution($merged_complex, $solution_clone);

        # Recursive call, only when interaction was successfully added
        $log->debug("Recursing after iaction placed ...");
        $self->_recurse($iactions, $i+1, $uf_clone, $solution_clone);
        
        # Cleanup:
        $self->_subcomplex->delete(refaddr($uf_clone));

    } 

    # Whether successful or not, now tail recurse to the next iaction
    $log->debug("Recursing after iaction not placed ...");
    # Tail recursion is flattened here, unless debugger active
    # TODO TEST
#     if (defined $DB::sub) {
    if (1) {
        return $self->_recurse($iactions, $i+1, $uf, $solution);
    } else {
        recur($self, $iactions, $i+1, $uf, $solution);
    }

} # _recurse



sub _try_iaction {
    my ($self, $uf, $solution, $iaction) = @_;
    # Skip if already covered
    return if $solution->has_edge($iaction->nodes);

    # Doesn't matter which we consider to be the source/dest node
    my ($src,$dest) = $iaction->nodes;

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
                $self->_cycle($uf, $solution, $iaction);
            
        } else {
            # Nodes in separate complexes, merge into single frame-of-ref
            ($merged_complex, $merged_score) = 
                $self->_merge($uf, $solution, $iaction);

        }
    } else {
        # Only one node in a complex tree, other is new (a monomer)
        
        if ($uf->has($src)) {
            # Create dimer, then merge on $src
            ($merged_complex, $merged_score) = 
                $self->_add_monomer($uf, $solution, $iaction,$src);
            
        } else {
            # Create dimer, then merge on $dest
            ($merged_complex, $merged_score) = 
                $self->_add_monomer($uf, $solution, $iaction,$dest);
        }
    }
    
    return ($merged_complex, $merged_score);
} # _try_iaction


sub _cycle {
    my ($self, $uf, $solution, $iaction) = @_;
    # Take either end of the interaction, since they belong to same complex
    my ($src, $dest) = $iaction->nodes;
    my $partition = $uf->find($src);
    my $complex = $self->_subcomplex->{refaddr($uf)}{$partition};

    # Modify a copy
    my $merged_complex = $complex->clone;
    # Difference from 10 to get something in range [0:10]
    my $irmsd = $merged_complex->cycle($iaction);
    return unless defined($irmsd) && $irmsd < 15;
    # Give this a ring bonus of +10, since it closes a ring
    # Normally a STAMP score gives no better than 10
    my $merged_score = 20 - $irmsd;
    
    return ($merged_complex, $merged_score);
} # _cycle


sub _merge {
    my ($self, $uf, $solution, $iaction) = @_;
    # Order irrelevant, as merging is symmetric
    my ($src, $dest) = $iaction->nodes;

    my $src_part = $uf->find($src);
#     my $src_complex = $solution->get_vertex_attribute($src_part,'complex');
    my $src_complex = $self->_subcomplex->{refaddr($uf)}{$src_part};
    my $dest_part = $uf->find($dest);
#     my $dest_complex = $solution->get_vertex_attribute($dest_part,'complex');
    my $dest_complex = $self->_subcomplex->{refaddr($uf)}{$dest_part};

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


=cut
sub _add_monomer {
    my ($self, $uf, $solution, $iaction, $ref) = @_;

    # Create complex out of a single interaction
    my $add_complex = SBG::Complex->new;
    $add_complex->add_interaction($iaction, $iaction->keys);

    # Lookup complex to which we want to add the interaction
    my $ref_partition = $uf->find($ref);
#     my $ref_complex = $solution->get_vertex_attribute($ref_partition,'complex');
    my $ref_complex = $self->_subcomplex->{refaddr($uf)}{$ref_partition};
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
