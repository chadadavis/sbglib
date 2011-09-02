#!/usr/bin/env perl

=head1 NAME

SBG::NetworkIO::sif - Cytoscape Simple Interaction Format 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Network> , L<SBG::IOI>

=cut

package SBG::NetworkIO::sif;
use Moose;

with qw/
    SBG::IOI
    /;

use SBG::Network;

=head2 read

 Function: Reads the interaction lines from the stream and produces a network
 Example : my $net = $io->read();
 Returns : L<SBG::Network>
 Args    : NA

NB Not implemented
=cut

sub read {
    my ($self,) = @_;
    my $fh = $self->fh;

    my $net = SBG::Network->new();

    while (my $line = <$fh>) {
        next if /^\s*$/ || /^\s*#/;
        my ($u, $v) = split ' ';
        $net->add_edge($u, $v);
    }
    return $net;

}    # read

=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 



=cut

sub write {
    my ($self, $graph) = @_;
    my $fh = $self->fh or return;

    # For each connection between two nodes, get all of the templates
    foreach my $e ($graph->edges) {
        my ($u, $v) = sort @$e;

        # Names of attributes for this edge
        foreach my $attr ($graph->get_edge_attribute_names($u, $v)) {

            # The actual interaction object for this template
            #            my $iaction = $graph->get_interaction_by_id($attr);
            print $fh "$u pp $v\n";
        }
    }
    return $self;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
