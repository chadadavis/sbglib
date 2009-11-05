#!/usr/bin/env perl

=head1 NAME

SBG::Network - Additions to Bioperl's L<Bio::Network::ProteinNet>

=head1 SYNOPSIS

 use SBG::Network;


=head1 DESCRIPTION

NB A L<Bio::Network::ProteinNet>, from which this module inherits, is a blessed
arrayref, rather than a blessed hashref. This means it is not easy to add any
additional attributes to this object, even if it is extending another class


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


use Cache::File;

use SBG::Node;
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


NB Need to override new() as Bio::Network::ProteinNet is not of Moose

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


# Has to use package vars, as Bio::Network is an ArrayRef not a HashRef
sub cache {
    my ($self) = @_;
    our $cache;
    return $cache if $cache;

    my $base = $ENV{CACHEDIR} || $ENV{TMPDIR} || '/tmp';
    my $arch = `uname -m`;
    chomp $arch;
    my $cachedir = "${base}/sbgnetwork_${arch}";

    $cache = Cache::File->new(
        cache_root => $cachedir,
        lock_level => Cache::File::LOCK_NFS(),
        );
    log()->trace($cachedir);
    return $cache;
}


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
    # Check cache
    $ops{cache} = 1 unless defined $ops{cache};

    my $cacheid = "$self";
    my $cached = $ops{cache} ? $self->cache->thaw($cacheid) : undef;
    log()->trace('cache:', $ops{cache});
    log()->trace('cacheid:',$cacheid);
    log()->trace('cached:', defined($cached) || 0);
    if (defined $cached) {
        log()->debug($cacheid, ' (cached)');
        return $cached;
    }

    # For all pairs
    foreach my $pair (pairs(sort $self->nodes)) {
        my ($node1, $node2) = @$pair;
        my ($p1) = $node1->proteins;
        my ($p2) = $node2->proteins;
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
    $self->cache->freeze($cacheid, $self) if $ops{cache};

    log()->debug(scalar($self->nodes), ' nodes');
    log()->debug(scalar($self->edges), ' edges');
    log()->debug(scalar($self->interactions), ' interactions');

    return $self;
}


###############################################################################
__PACKAGE__->meta->make_immutable(inline_constructor=>0);
no Moose;
1;

