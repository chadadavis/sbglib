#!/usr/bin/env perl

=head1 NAME

SBG::NetworkIO::graphviz - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Network> , L<SBG::IOI>

=cut

################################################################################

package SBG::NetworkIO::graphviz;
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
    my $net = new SBG::Network;

    warn "Not implemented";


    while (<$fh>) {
        next unless //;
        chomp;
    }

    return $net;
} # read


################################################################################
=head2 write

 Title   : write
 Usage   : 
 Function: Uses L<Graph::Writer::GraphViz> to write a L<Graph> as an image
 Returns : NA
 Args    : 
           %options - Options passed on to L<Graph::Writer::GraphViz> 

 my $io = new SBG::NetworkIO::graphviz(file=>">mygraph.png");
 $io->write($somegraph, 
               -rankstep=>1.5,
               -fontsize=>8,
               %other_options,
 );

=cut
sub write {
    my ($self, $graph, %ops) = @_;
    my $file = $self->file or return;

    unless (defined $ops{-format}) {
        ($ops{-format}) = $file =~ /\.([^\/]+?)$/;
        $ops{-format} ||= 'png';
    }

    my $writer = Graph::Writer::GraphViz->new(%ops);
    $writer->write_graph($graph, $file);
    return $self;
} # write



################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
