#!/usr/bin/env perl

=head1 NAME

SBG::Network - Additions to Bioperl's L<Bio::Network::ProteinNet>

=head1 SYNOPSIS

 use SBG::Network;


=head1 DESCRIPTION


=head1 SEE ALSO

L<Bio::Network::Interaction> , L<SBG::Interaction>

=cut

# TODO import bin/mkconnected

################################################################################

package SBG::Network;
use SBG::Root -base;
use base qw(Bio::Network::ProteinNet);

field 'subgraphid' => 0;

use overload (
    '""' => '_asstring',
    );



################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new Bio::Network::ProteinNet(@_);
    # And add our ISA spec
    bless $self, $class;
    # Is now both a Bio::Network::ProteinNet and an SBG::Network
    return $self;
}


################################################################################

# Subset the network and return array of SBG::Network
sub partition {
    my ($self) = @_;
    my @partitions = $self->connected_components;
    my $partition_i = 0;
    my @graphs;
    foreach my $nodeset (@partitions) {
        next unless @$nodeset > 2;
        $partition_i++;
        my $subgraph = $self->subgraph(@$nodeset);
        print "I'm a ", ref($self), "\n";
        bless $subgraph, ref($self);
        print "he's a ", ref($subgraph), "\n";

#         $subgraph->subgraphid($partition_i);
        print 
            "Subgraph $partition_i : ", 
            scalar(@$nodeset), " components, ", 
            scalar($subgraph->interactions), " interaction templates on ",
            scalar($subgraph->edges), " edges",
            "\n";
        push @graphs, $subgraph;
    }
    return @graphs;
} # partitions


################################################################################

# Get all interactions (L<SBG::Interaction>) between $u and $v
sub templates {
    my ($self, $u, $v) = @_;
    my @iaction_names = $self->get_edge_attribute_names($u, $v);
    next unless @iaction_names;
    my @iactions = map { $self->get_interaction_by_id($_) } @iaction_names;
    return @iactions;
}


sub _asstring {
    my ($self) = @_;
    return join(",", sort($self->nodes()));
}


###############################################################################

1;

__END__
