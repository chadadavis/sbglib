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
# NB Order of inheritance matters here
extends qw/Bio::Network::ProteinNet Moose::Object/;

with qw/
SBG::Role::Storable
SBG::Role::Dumpable
/;


use SBG::U::List qw/pairs/;
use SBG::U::Log qw/log/;

use overload (
    '""' => 'stringify',
    );



################################################################################
=head2 new

 Function: 
 Example : 
 Returns : 
 Args    : 

Normally the refvertexed=>1 option should be used to store objects at the graph
nodes.

Due to a bug in Graph::AdjacencyMap::Vertex, we prefer to use
Graph::AdjacencyMap::Light. This can be achieved by setting revertexed=>0,
though, intuitively, we would prefer refvertexed=>1, as a Node in the Graph is
an object, and not just a string.

The bug is that stringification of SGB::Node is ignored, which causes Storable
to not be able to store/retrieve a SBG::Network correctly.

=cut
override 'new' => sub {
    my ($class, @ops) = @_;
    
    # This creates a Bio::Network::ProteinNet
    my $obj = $class->SUPER::new(refvertexed=>0, @ops);

    # Normally, we would override a non-Moose base class with: But we don't,
    # since Bio::Network::ProteinNet is an ArrayRef, not a HashRef, like most
    # objects.

#     $obj = $class->meta->new_object(__INSTANCE__ => $obj);

    # bless'ing should be automatic!
    bless $obj, $class;
    return $obj;
};


sub stringify {
    my ($self) = @_;
    return join(",", sort($self->nodes()));
}


################################################################################
=head2 add_node

 Function: Adds L<Bio::Network::Node> to L<Bio::Network::ProteinNet> 
 Example : $seq = new Bio::Seq(-accession_number=>"RRP43"); 
           $node = new Bio::Network::Node($seq); 
           $net->add_node($node);
 Returns : $self
 Args    : A L<Bio::Network::Node> or subclass

Also adds index ID (from B<accession_number>) to Node. Then, you can:

 $node = $net->nodes_by_id('RRP43');

=cut
override 'add_node' => sub {
    my ($self, $node) = @_;
    my $res = $self->SUPER::add_node($node);
    my ($protein) = $node->proteins or return;
    $self->add_id_to_node($protein->accession_number, $node);
    return $res;
};


################################################################################
=head2 add_interaction

 Function: 
 Example : 
 Returns : 
 Args    : 

Delegates to L<Bio::Network::ProteinNet> but makes sure that the Interaction has
a primary_id.

=cut
override 'add_interaction' => sub {
    my ($self, %ops) = @_;
    my $iaction = $ops{'-interaction'};
    my $nodes = $ops{'-nodes'};
    unless (defined $iaction->primary_id) {
        $iaction->primary_id(join('--', @$nodes));
    }
    my $res = $self->SUPER::add_interaction(%ops);
    return $res;

}; # add_interaction


################################################################################
=head2 partition

 Function: Subsets the network into connected sub graphs 
 Example : my $subgraphs = $net->partition();
 Returns : Array/ArrayRef of L<SBG::Network>
 Args    : NA

NB these will contain the original interactions for the nodes that are still
present, including any multiple interactions between two nodes.

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

    # For all pairs
    foreach my $pair (pairs($self->nodes)) {
        my ($node1, $node2) = @$pair;
        my ($p1) = $node1->proteins;
        my ($p2) = $node2->proteins;
        my @interactions = $searcher->search($p1, $p2);
        
        foreach my $iaction (@interactions) {
            $self->add_interaction(
                -nodes=>[$node1,$node2],
                -interaction=>$iaction,
                );
        }
    }
    
    return $self;
}


###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor=>0);
no Moose;
1;

