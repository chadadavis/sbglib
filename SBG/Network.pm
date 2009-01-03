#!/usr/bin/env perl

=head1 NAME

SBG::Network - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<Graph> , L<Bio::Network::ProteinNet>

=cut

################################################################################

package SBG::Network;
use SBG::Root -base, -XXX;
use base qw(Bio::Network::ProteinNet);

use warnings;
use Carp;

use Graph;

use SBG::IO;


################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = Bio::Network::ProteinNet->new(refvertexed=>1,@_);
    # And add our ISA spec
    bless $self, $class;
    return $self;
}


################################################################################
=head2 graphviz

 Title   : graphviz
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :
           $filename - Where a file will be written (default: graph.png)
           $format - Optionally specify the format, explicitly

Prints any L<Graph> including L<Bio::Network::ProteinNet>

Note: file format is determined by filename extension (by graphviz itself)

=cut
sub graphviz {
    my ($self,$file,$format) = @_;
    $file ||= "graph.png";
    # File extension (everything after last . )
    my ($format) = $file =~ /\.([^\/]+?)$/;
    $format ||= 'png';
    print STDERR "graphviz: $file:$format:\n";
    my $writer = Graph::Writer::GraphViz->new(
        -format => $format,
#         -layout => 'twopi',
#         -layout => 'fdp',
        -ranksep => 1.5,
        -fontsize => 8,
        -edge_color => 'grey',
        -node_color => 'black',
        );
    $writer->write_graph($self, $file);

} # graphviz



################################################################################
1;
