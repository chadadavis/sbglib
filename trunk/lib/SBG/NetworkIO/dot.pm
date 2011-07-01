#!/usr/bin/env perl

=head1 NAME

SBG::NetworkIO::graphviz - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Network> , L<SBG::IOI>

=cut

################################################################################

package SBG::NetworkIO::dot;
use Moose;

with qw/
SBG::IOI
/;


use Graph::Writer::GraphViz;

use SBG::Network;


################################################################################
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

    warn "Not implemented";
    my $net = new SBG::Network;

    while (my $line = <$fh>) {
        next unless $line =~ //;
        chomp;
    }
    return $net;

} # read


################################################################################
=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 

This write manually generates a graphviz format that is able to accomodate
multiple edges.

# TODO options? Can GraphViz module still be used to parse these out?

=cut
sub write {
    my ($self, $graph) = @_;
    my $fh = $self->fh or return;

    my $str = join("\n",
                   "graph {",
                   "\tnode [fontsize=10];",
                   "\tedge [fontsize=8, color=grey];",
                   ,"");

    # For each connection between two nodes, get all of the templates
    foreach my $e ($graph->edges) {
        # Don't ask me why u and v are reversed here. But it's correct.
        my ($v, $u) = @$e;
        # Names of attributes for this edge
        foreach my $attr ($graph->get_edge_attribute_names($u, $v)) {
            # The actual interaction object for this template
            my $iaction = $graph->get_interaction_by_id($attr);

            $str .= "\t\"$u\" -- \"$v\" [" . 
                join(', ', 
                     "headlabel=\"" . $iaction->get($v)->subject . "\"",
                     "taillabel=\"" . $iaction->get($u)->subject . "\"",
                     "];\n");
        }
    }

    $str .= "}\n";
    print $fh $str;
    return $self;
}



################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
