#!/usr/bin/env perl

=head1 NAME

SBG::Network - Additions to Bioperl's L<Bio::Network::ProteinNet>

=head1 SYNOPSIS

 use SBG::Network;


=head1 DESCRIPTION

NB A L<Bio::Network::ProteinNet>, from which this module inherits, is a blessed
arrayref, rather than a blessed hashref. This means it is not easy to add any
additional attributes to this object, even if it is extending another class


=head1 BUGS

NB Bio::Network::ProteinNet, like Graph, from which it inherits, are not Hashes,
but rather Arrays. In order to extend these objects with any additional
attributes, one must peek into the implementation and append the base array,
e.g. with a HashRef, in which one could store extra object attributes. But we'll
avoid breaking the API as much as possible and avoid that for now.

Normally the refvertexed=>1 option should be used to store objects at the graph
nodes.

Due to a bug in Graph::AdjacencyMap::Vertex, we prefer to use
Graph::AdjacencyMap::Light. This can be achieved by setting revertexed=>0,
though, intuitively, we would prefer refvertexed=>1, as a Node in the Graph is
an object, and not just a string.

The bug is that stringification of SGB::Node is ignored, which causes Storable
to not be able to store/retrieve a SBG::Network correctly.


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

use Moose::Autobox;
use Digest::MD5 qw/md5_base64/;
use Log::Any qw/$log/;

use SBG::Node;
use SBG::U::List qw/pairs/;
use SBG::U::Cache qw/cache/;

use overload (
    '""' => 'stringify',
    );


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
    
    # This creates a Bio::Network::ProteinNet
    # refvertexed=>0 allows us to work around stringification probs in 
    # Graph::AdjacencyMap
    # TODO which?
    my $obj = $class->SUPER::new(refvertexed=>0, @ops);
#     my $obj = $class->SUPER::new(refvertexed=>1, @ops);

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
    my ($protein) = $node->proteins;
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

    # For all pairs
    my @pairs = pairs(sort $self->nodes);
    my $npairs = @pairs;
    my $ipair = 0;
    $log->debug(scalar(@pairs), ' potential edges in interaction network');
    foreach my $pair (@pairs) {
        $ipair++;
        $log->info("Edge $ipair of $npairs");
        my ($node1, $node2) = @$pair;
        my ($p1) = $node1->proteins;
        my ($p2) = $node2->proteins;

        # Disable cache until ID mapping in place
#         my @interactions = _interactions($searcher, $p1, $p2, %ops);
        my @interactions = $searcher->search($p1, $p2, %ops);

        next unless @interactions;
        $self->add_edge($node1, $node2);

        foreach my $iaction (@interactions) {
            $self->add_interaction(
                -nodes=>[$node1,$node2],
                -interaction=>$iaction,
                );
            $self->add_id_to_interaction("$iaction", $iaction);
        }
    }

    $log->info(scalar($self->nodes), ' nodes');
    $log->info(scalar($self->edges), ' edges');
    $log->info(scalar($self->interactions), ' interactions');

    return $self;
} # build


# Cache wrapper
# TODO Need to map IDs of query sequences to those in the cached interactions
sub _interactions {
    my ($searcher, $p1, $p2, %ops) = @_;

    $log->debug('cache:', $ops{cache});

    my $cache;
    my $key;
    if ($ops{cache}) {
        # Sorted hashes of lower-cases sequences, a bidirectional, unique ID
        $key = join '--', sort map { md5_base64 lc $_->seq } ($p1, $p2);
        $cache = SBG::U::Cache::cache('sbginteractions');
        my $cached = $cache->get($key);
        return @$cached if defined $cached;
    }

    my @interactions = $searcher->search($p1, $p2, %ops);

    if ($ops{cache}) {
        $cache->set($key, \@interactions);
    }

    return @interactions;

}




###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor=>0);
no Moose;
1;

