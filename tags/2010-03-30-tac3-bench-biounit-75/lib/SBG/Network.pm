#!/usr/bin/env perl

=head1 NAME

SBG::Network - Additions to Bioperl's L<Bio::Network::ProteinNet>

=head1 SYNOPSIS

 use SBG::Network;


=head1 DESCRIPTION

NB A L<Bio::Network::ProteinNet>, from which this module inherits, is a blessed
arrayref, rather than a blessed hashref. Adding attributes should be done with
the custom API of L<Graph> which uses B<set_graph_attribute($name, $value)> and
B<get_graph_attribute($name)>. Also a HashRef can preload many of these using
B<set_graph_attributes($hashref)> and B<get_graph_attributes>.


=head1 SEE ALSO

L<Bio::Network::ProteinNet> , L<Bio::Network::Interaction> , L<SBG::Interaction>

=cut


################################################################################

package SBG::Network;
use Moose;
# NB Order of inheritance matters here
extends qw/Bio::Network::ProteinNet Moose::Object/;

with 'SBG::Role::Storable';
with 'SBG::Role::Dumpable';
with 'SBG::Role::Writable';
with 'SBG::Role::Versionable';

use overload (
    '""' => 'stringify',
    fallback => 1,
    );

use Moose::Autobox;
use Log::Any qw/$log/;

use Bio::Tools::Run::Alignment::Clustalw;

use SBG::Node;
use SBG::U::List qw/pairs/;
use SBG::U::Cache qw/cache/;



################################################################################
=head2 new

 Function: 
 Example : 
 Returns : 
 Args    : 


NB Need to override new() as Bio::Network::ProteinNet is not of Moose



=cut
override 'new' => sub {
    my ($class, @ops) = @_;
    
    # This creates a Bio::Network::ProteinNet. refvertexed_stringfied means the
    # Nodes are objects, not simple strings and that the stringification of the
    # object, rather than its address, is used as the hash key. NB refvertexed
    # is not sufficient here if objects are serialized, because the deserialized
    # node objects will necessarily have a different memory address.
    my $obj = $class->SUPER::new(refvertexed_stringified=>1, @ops);

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
=head2 proteins

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub proteins {
    my ($self,) = @_;
    return map { $_->proteins } $self->nodes;

} # proteins


################################################################################
=head2 add_node

 Function: Adds L<Bio::Network::Node> to L<Bio::Network::ProteinNet> 
 Example : $seq = new Bio::Seq(-display_id=>"RRP43"); 
           $node = new Bio::Network::Node($seq); 
           $net->add_node($node);
 Returns : $self
 Args    : A L<Bio::Network::Node> or subclass

Also adds index ID (from B<display_id>) to Node. Then, you can:

 $node = $net->nodes_by_id('RRP43');

=cut
override 'add_node' => sub {
    my ($self, $node) = @_;
    my $res = $self->SUPER::add_node($node);
    my ($protein) = $node->proteins;
    $self->add_id_to_node($protein->display_id, $node);
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
    unless ($iaction->primary_id) {
        $iaction->primary_id(join('--', @$nodes));
    }
    my $res = $self->SUPER::add_interaction(%ops);
    return $res;

}; # add_interaction



sub symmetry {
    my ($self,) = @_;

    if ($self->has_graph_attribute('symmetry')) {
        return $self->get_graph_attribute('symmetry');
    }

    my $symmetry = Graph::Undirected->new(unionfind=>1);
    my @nodes = $self->nodes;
    # Define homologous groups, initially each protein homologous to self
    $symmetry->add_vertex("$_") for @nodes;

    my $clustal = Bio::Tools::Run::Alignment::Clustalw->new;
    my $homo_thresh = 90;

    # For all pairs
    my @pairs = pairs(@nodes);
    foreach my $pair (@pairs) {
        $log->debug("Testing homology: @$pair");
        next if $symmetry->same_connected_components(@$pair);

        # Align two proteins
        my @prots = map { $_->proteins } @$pair;
        my $aln = $clustal->align(\@prots);
        $log->debug(' identity:', $aln->percentage_identity, 
                    ' score:', $aln->score);

        if ($aln->percentage_identity > $homo_thresh) {
            $log->debug("Grouping homologs: @$pair");
            $symmetry->add_edge("$pair->[0]", "$pair->[1]");
        }
    }
    my @sets = $symmetry->connected_components;
    my $str = join(',', map { '(' . join(',',@$_) . ')' } @sets);
    $log->debug($str);

    $self->set_graph_attribute('symmetry', $symmetry);
    return $symmetry;

} # symmetry



################################################################################
=head2 homologs

 Function: 
 Example : 
 Returns : 
 Args    : 

List of node names that are in the same homology class as the given node
=cut
sub homologs {
    my ($self, $node) = @_;
    my $symmetry = $self->get_graph_attribute('symmetry') or return;
    my @homos = 
        $symmetry->connected_component_by_index(
            $symmetry->connected_component_by_vertex($node)
        );
    return @homos;

} # homologs


################################################################################
=head2 add_seq

 Function: 
 Example : 
 Returns : 
 Args    : An Array of L<Bio::PrimarySeqI>


=cut
sub add_seq {
    my ($self, @seqs) = @_;
    my @nodes = map { SBG::Node->new($_) } @seqs;
    # Each node contains one sequence object
    $self->add_node($_) for @nodes;
    $self->delete_graph_attribute('symmetry');
    return $self;

} # add_seq


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
    my ($self, %ops) = @_;
    my @partitions = $self->connected_components;
    my @graphs;
    foreach my $nodeset (@partitions) {
        next if $ops{minsize} && @$nodeset < $ops{minsize};
        my $subgraph = $self->subgraph(@$nodeset);
        # Bless this back into our sub-class
        bless $subgraph;
        push @graphs, $subgraph;
    }
    return wantarray ? @graphs : \@graphs;
} # partitions


################################################################################
=head2 seeds

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub seeds {
    my ($self,) = @_;
    
    # Indexed by PDBID and by edge label
    my $seeds = {};
    foreach my $edge ($self->edges) {
        my @nodes = sort @$edge;
        my $edgelabel = join('--',@nodes);
        my %interactions = $self->get_interactions(@nodes);
        foreach my $iaction_key (keys %interactions) {
            my $iaction = $interactions{$iaction_key};
            my $pdbid = $iaction->pdbid;
            $seeds->{$pdbid} ||= {};
            $seeds->{$pdbid}{$edgelabel} ||= [];
            my $domains = join('--', $iaction->domains(\@nodes)->flatten);
            $seeds->{$pdbid}{$edgelabel}->push($domains);
        }
    }

    # Which seeds cover the most edges
    my @keys = sort { 
        $seeds->{$b}->keys->length <=> $seeds->{$a}->keys->length
    } $seeds->keys->flatten;
    my $sorted_seeds = { map { $_ => $seeds->{$_} } @keys };
    return $sorted_seeds;

} # seeds


################################################################################
=head2 size

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub size {
    my ($self,) = @_;
    return scalar($self->nodes);

} # size


################################################################################
=head2 build

 Function: Uses B<searcher> to add interactions to network
 Example : $net->build();
 Returns : The Network built, which may not be the same as the original object
 Args    : L<SBG::SearchI>


=cut
sub build {
    my ($self, $searcher, %ops) = @_;

    my @pairs = pairs(sort $self->nodes);
    my $npairs = @pairs;
    my $ipair = 0;
    $log->debug($npairs, ' potential edges in interaction network');
    foreach my $pair (@pairs) {
        $ipair++;
        my ($node1, $node2) = @$pair;
        my ($p1) = $node1->proteins;
        my ($p2) = $node2->proteins;
        $log->info("Edge $ipair of $npairs ($p1--$p2)");
        my @interactions = $searcher->search($p1, $p2, %ops);
        $log->info("$p1--$p2: ", scalar(@interactions), ' interactions');
        next unless @interactions;

        $self->add_edge($node1, $node2);
        foreach my $iaction (@interactions) {
            $self->add_interaction(
                -nodes=>[$node1,$node2],
                -interaction=>$iaction,
                );
            # This allows the Network to lookup an Interaction by its ID
            # It's not the same as the ID that the Interaction stores in itself
            $self->add_id_to_interaction("$iaction", $iaction);
        }
    }

    $log->info(scalar($self->nodes), ' nodes');
    $log->info(scalar($self->edges), ' edges');
    $log->info(scalar($self->interactions), ' interactions');

    return $self;
} # build


###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor=>0);
no Moose;
1;

