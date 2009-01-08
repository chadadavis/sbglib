#!/usr/bin/env perl

=head1 NAME

SBG::NetworkIO - Reads interactions and their templates from file

=head1 SYNOPSIS

 use SBG::NetworkIO;
 my $net = new SBG::NetworkIO(-file=>"interactions.csv")->read;
 $net->graphviz("printed_graph.png");

=head1 DESCRIPTION

Input routines for building up L<SBG::Interaction> objects from CSV file
input. Produces a L<Bio::Network::ProteinNet> from them, which is also a
L<Graph>.

The input format contains one interaction per line, with this format:

 component1 component2 template1 { descriptor } template2 { desc } score

Where:

component1/component2 are labels for the interacting proteins. These can be any
label, but accession numbers, e.g. UniProt would be sensible.

template1/template2 are any labels for the structures upon which
component1/component2 are modelled. These can be any labels, but L<SBG::STAMP>
prefers it when the first four characters of the label are the PDB ID (case
insensitive) of the model structure.

The descriptors are regular STAMP descriptors, in { braces }.  See:
http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

The score can be any decimal number. Larger numbers imply stronger
interactions. The units and meaning of this score are not specified.

Example:

 RRP42 RRP43  2br2b { CHAIN B } 2br2d { CHAIN D } 22.32

=head1 SEE ALSO

L<SBG::IO> , L<SBG::Interaction> , L<Bio::Network::ProteinNet>

=cut

################################################################################

package SBG::NetworkIO;
use SBG::Root -base, -XXX;
use base qw(SBG::IO);

our @EXPORT_OK = qw(graphviz graphvizmulti);

use warnings;
use Carp;
use Text::ParseWords;
use Bio::Network::ProteinNet;
use Graph::Writer::GraphViz;

use SBG::Interaction;
use SBG::Node;
use SBG::Seq;
use SBG::Domain;

################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new SBG::IO(@_);
    return unless $self;
    # And add our ISA spec
    bless $self, $class;
    return $self;
} # new


################################################################################
=head2 read

 Title   : read
 Usage   : my $net = $io->read();
 Function: Reads the interaction lines from the stream and produces a network
 Example : (see above)
 Returns : L<Bio::Network::ProteinNet>
 Args    : NA

E.g.:

RRP41 RRP42  2br2 { CHAIN A } 2br2 { CHAIN B } 69.70 
# or
RRP41 RRP42  2br2 { A 5 _ to A 220 _ } 2br2 { B 1 _ to B 55 _ } 69.70 

=cut
sub read {
    my $self = shift;
    my $fh = $self->fh;

    # refvertexed because the nodes are object refs, rather than strings or so
    my $net = Bio::Network::ProteinNet->new(refvertexed=>1);

    # Components can participate in multiple interactions
    # But the nodes themselves are unique
    my %nodes;
    # NB you cannot do this with Domain's, even if they are effectively equal.
    # Because a Domain can be later transformed, but those are all independent

    while (<$fh>) {
        next if /^\s*\#/ || /^\s*\%/ || /^\s*$/;
        chomp;

        # Get the stuff in { brackets } first: the STAMP domain descriptors
        my ($head, $descr1, $pdbid2, $descr2, $score) = 
            parse_line('\s*[{}]\s*', 0, $_);
        # Then parse out everything else from the beginning, just on whitespace
        my ($comp1, $comp2, $pdbid1) = 
            parse_line('\s+', 0, $head);
        $score ||= 0;
        unless ($comp1 && $comp2 && $pdbid1 && $pdbid2) {
            $logger->error("Cannot parse interaction:\n$_");
            next;
        }

        # Create Seq objects, using accession; and Node objects contain a Seq
        # Only if we have not already seen these component Nodes, else reuse
        $nodes{$comp1} ||= 
            new SBG::Node(new SBG::Seq(-accession_number=>$comp1));
        $nodes{$comp2} ||= 
            new SBG::Node(new SBG::Seq(-accession_number=>$comp2));

        # Template domains.
        # Will be created, even if they are equivalent to previously created dom
        # Because the template domains are specific to an interaction template
        my $dom1 = new SBG::Domain(
            -label=>$comp1,-pdbid=>$pdbid1,-descriptor=>$descr1);
        my $dom2 = new SBG::Domain(
            -label=>$comp2,-pdbid=>$pdbid2,-descriptor=>$descr2);

        # Unique (in the whole network) interaction label/id
        my $iactionid = "$comp1($pdbid1 $descr1)--$comp2($pdbid2 $descr2)";
        $logger->trace("Interaction:$iactionid $score");

        # Interaction object.
        my $interaction = new SBG::Interaction(-id=>$iactionid,-weight=>$score);
        # The Interaction notes which Domain models which Node
        $interaction->template($nodes{$comp1}) = $dom1;
        $interaction->template($nodes{$comp2}) = $dom2;

        # Now put it all into the ProteinNet. 
        # Now there is a formal association beteen Interaction and it's Node's
        $net->add_interaction(
            -nodes => [$nodes{$comp1}, $nodes{$comp2}], 
            -interaction => $interaction,
            );
    }
    # End of file
    return $net;
} # read


################################################################################
=head2 graphviz

 Title   : graphviz
 Usage   : SBG::NetworkIO::graphviz($somegraph,"mygraph.png");
 Function: Uses L<Graph::Writer::GraphViz> to write a L<Graph> as an image
 Example : SBG::NetworkIO::graphviz($somegraph,"mygraph.png",
               -rankstep=>1.5,
               -fontsize=>8,
               );
 Returns : NA
 Args    : 
           graph - A L<Graph> e.g. a L<Bio::Network::ProteinNet>
           file - A path to a file to create/write
           %options - Options passed on to L<Graph::Writer::GraphViz> 

You can also import the function:
use SBG::NetworkIO qw(graphviz);
graphviz($somegraph,"mygraph.png");

=cut
sub graphviz {
    my $graph = shift;
    my $file = shift;
    return unless $graph && $file;
    my %ops = @_;

    unless (defined $ops{-format}) {
        ($ops{-format}) = $file =~ /\.([^\/]+?)$/;
        $ops{-format} ||= 'png';
    }

    my $writer = Graph::Writer::GraphViz->new(%ops);
    $writer->write_graph($graph, $file);

} # graphviz


# Do output from scratch in order to accomodate multiple edges
# TODO DOC
# TODO options? Can GraphViz module still be used to parse these out?
sub graphvizmulti {
    my ($graph, $file) = @_;
    return unless $graph && $file;

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
            my $udom = $ix->template($u);
            my $vdom = $ix->template($v);
            # Don't ask me why u and v are reversed here. But it's correct.
            $str .= "\t$u -- $v [" . 
                join(', ', 
                     "label=\"" . $ix->weight . "\"",
                     "headlabel=\"" . $udom->label . "\"",
                     "taillabel=\"" . $vdom->label . "\"",
                     "headtooltip=\"" . $udom->descriptor . "\"",
                     "tailtooltip=\"" . $vdom->descriptor . "\"",
                     "headURL=\"" . $pdb . $udom->pdbid . "\"",
                     "tailURL=\"" . $pdb . $vdom->pdbid . "\"",
                     "];\n");
        }
    }

    $str .= "}\n";
    open my $fh, ">$file";
    print $fh $str;
}

################################################################################
1;
