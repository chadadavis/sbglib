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
extends qw/Bio::Network::ProteinNet Moose::Object/;

with qw/
SBG::Role::Storable
SBG::Role::Dumpable
/;

use File::Temp qw/tempfile/;
use SBG::U::List qw/pairs/;
use SBG::U::Log qw/log/;

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
    my ($class, %ops) = @_;
    
    # This creates a Bio::Network::ProteinNet
    my $obj = $class->SUPER::new(refvertexed=>0, %ops);

    # This appends the object with goodies from Moose::Object
    # __INSTANCE__ place-holder fulfilled by $obj 
    $obj = $class->meta->new_object(__INSTANCE__ => $obj, %ops);

    # bless'ing should be automatic!
    bless $obj, $class;
    return $obj;
};


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
        log()->erorr("Need a SBG::SearchI to do the template search");
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


# Do output from scratch in order to accomodate multiple edges
# TODO DOC
# TODO options? Can GraphViz module still be used to parse these out?
sub graphviz {
    my ($graph, $file) = @_;
    $file ||= 'graph.dot';
    my $fh;
    unless (open $fh, ">$file") {
        log()->error("Cannot write to: ", $file, " ($!)");
        return;
    }
    return unless $graph && $fh;

    my $pdb = "http://www.rcsb.org/pdb/explore/explore.do?structureId=";

    my $str = join("\n",
                   "graph {",
                   "\tnode [fontsize=6];",
                   "\tedge [fontsize=8, color=grey];",
                   ,"");
    # For each connection between two nodes, get all of the templates
    foreach my $e ($graph->edges) {
        # Don't ask me why u and v are reversed here. But it's correct.
        my ($v, $u) = @$e;
        # Names of templates for this edge
        my @templ_ids = $graph->get_edge_attribute_names($u, $v);
        foreach my $t (@templ_ids) {
            # The actual interaction object for this template
            my $ix = $graph->get_interaction_by_id($t);
            # Look up what domains model which halves of this interaction
            my $uname = $ix->template($u)->seq;
            my $vname = $ix->template($v)->seq;
            my $udom = $ix->template($u)->domain;
            my $vdom = $ix->template($v)->domain;
             $str .= "\t\"" . $uname . "\" -- \"" . $vname . "\" [" . 
                join(', ', 
#                      "label=\"" . $ix->weight . "\"",
                     "headlabel=\"" . $udom->pdbid . "\"",
                     "taillabel=\"" . $vdom->pdbid . "\"",
                     "headtooltip=\"" . $udom->descriptor . "\"",
                     "tailtooltip=\"" . $vdom->descriptor . "\"",
                     "headURL=\"" . $pdb . $udom->pdbid . "\"",
                     "tailURL=\"" . $pdb . $vdom->pdbid . "\"",
                     "];\n");
        }
    }

    $str .= "}\n";
    print $fh $str;
    return $file;
}


sub _asstring {
    my ($self) = @_;
    return join(",", sort($self->nodes()));
}


###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor=>0);
1;



