#!/usr/bin/env perl

=head1 NAME

SBG::Network - Additions to Bioperl's L<Bio::Network::ProteinNet>

=head1 SYNOPSIS

 use SBG::Network;


=head1 DESCRIPTION

NB A L<Bio::Network::ProteinNet>, from which this module inherits, is a blessed
arrayref, rather than a blessed hashref.

=head1 SEE ALSO

L<Bio::Network::ProteinNet> , L<Bio::Network::Interaction> , L<SBG::Interaction>

=cut


################################################################################

package SBG::Network;
use Moose;
extends qw/Bio::Network::ProteinNet/;
with 'SBG::Storable';
with 'SBG::Dumpable';

use Carp;
use SBG::List qw/pairs/;

use overload (
    '""' => '_asstring',
    );


################################################################################


################################################################################
=head2 new

 Function: 
 Example : 
 Returns : 
 Args    : 

NB. Due to a bug in Graph::AdjacencyMap::Vertex, we prefer to use
Graph::AdjacencyMap::Light. This can be achieved by setting revertexed=>0,
though, intuitively, we would prefer refvertexed=>1, as a Node in the Graph is
an object, and not just a string.

The bug is that stringification of SGB::Node is ignored, which causes Storable
to not be able to store/retrieve a SBG::Network correctly.

=cut
sub new () {
    my $class = shift;
    # refvertexed because the nodes are object refs, rather than strings or so

    my $self = $class->SUPER::new(refvertexed=>0, @_);
    bless $self, $class;
    return $self;
}


################################################################################
=head2 add

 Function: Adds L<Bio::Network::Node> to L<Bio::Network::ProteinNet> 
 Example : $node = new Bio::Seq(-accession_number=>"RRP43"); $net->add($node);
 Returns : $self
 Args    : A L<Bio::Network::Node> or subclass

Also adds index ID (from accession_number) to Node. Then later:

 $node = $net->nodes_by_id('RRP43');

=cut
sub add {
    my ($self, $node) = @_;
    $self->add_node($node);
    my ($protein) = $node->proteins;
    $self->add_id_to_node($protein->accession_number, $node);
    return $self;
}


################################################################################
=head2 partition

 Function: Subsets the network into connected sub graphs 
 Example : my $subgraphs = $net->partition();
 Returns : Array/ArrayRef of L<SBG::Network>
 Args    : NA

NB these will contain the original interactions for the nodes that are still
present, including multiple interactions between two nodes.

=cut
sub partition {
    my ($self) = @_;
    my @partitions = $self->connected_components;
    my @graphs;
    foreach my $nodeset (@partitions) {
        next unless @$nodeset > 2;
        my $subgraph = $self->subgraph(@$nodeset);
        # Bless this back into our sub-class
        bless $subgraph;
        push @graphs, $subgraph;
    }
    return wantarray ? @graphs : \@graphs;
} # partitions


################################################################################
=head2 build

 Function: Uses B<searcher> to add interactions to network
 Example : $net->build();
 Returns : $self
 Args    : L<SBG::SearchI>

TODO doc

=cut
sub build {
    my ($self, $searcher) = @_;
    unless ($searcher && $searcher->does('SBG::SearchI')) {
        carp "Need a SBG::SearchI to do the template search";
        return;
    }
    # For all pairs
    foreach my $pair (pairs($self->nodes)) {
        my ($node1, $node2) = @$pair;
        my ($p1) = $node1->proteins;
        my ($p2) = $node2->proteins;
        my @interactions = $searcher->search($p1, $p2);
        
        foreach my $iaction (@interactions) {
            $self->add_interaction(
                -nodes=>[$node1,$node2],-interaction=>$iaction);
        }
    }
    
    return $self;
}


sub _asstring {
    my ($self) = @_;
    return join(",", sort($self->nodes()));
}


###############################################################################
__PACKAGE__->meta->make_immutable;
1;



