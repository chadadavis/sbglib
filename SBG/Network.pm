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

# TODO import bin/mkconnected

################################################################################

package SBG::Network;
use Moose;
extends 'Bio::Network::ProteinNet';
with 'SBG::Storable';


use overload (
    '""' => '_asstring',
    );


################################################################################

# Subset the network and return array of SBG::Network
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

# Get all interactions (L<SBG::Interaction>) between $u and $v
sub interactions {
    my ($self, $u, $v) = @_;
    my @iaction_names = $self->get_edge_attribute_names($u, $v);
    next unless @iaction_names;
    my @iactions = map { $self->get_interaction_by_id($_) } @iaction_names;
    return wantarray ? @iactions : \@iactions;
}


sub _asstring {
    my ($self) = @_;
    return join(",", sort($self->nodes()));
}


###############################################################################

1;

__END__
