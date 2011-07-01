#!/usr/bin/env perl

=head1 NAME

SBG::NetworkIO - Reads interactions and their templates from file

=head1 SYNOPSIS

 use SBG::NetworkIO;
 my $net = new SBG::NetworkIO(file=>"interactions.csv")->read;
 $net->graphviz("printed_graph.png");

=head1 DESCRIPTION

Input routines for building up L<SBG::Interaction> objects from CSV file
input. Produces a L<Bio::Network::ProteinNet> from them, which is also a
L<Graph>.

The input format contains one interaction per line, with this format:

 component1 component2 pdbid1 { descriptor } pdbid1 { descriptor }

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

L<SBG::Interaction> , L<SBG::Network>

=cut

################################################################################

package SBG::NetworkIO;
use Moose;
extends qw/SBG::IO Exporter/;
our @EXPORT_OK = qw(graphviz graphvizmulti);

use Text::ParseWords;
use Bio::Network::ProteinNet;
use Graph::Writer::GraphViz;

use Bio::Network::ProteinNet;

use SBG::Network;
use SBG::Interaction;
use SBG::Node;
use SBG::Seq;
use SBG::Domain;
use SBG::Template;
use SBG::List qw(pairs);
use SBG::HashFields;

################################################################################
# Fields


################################################################################
=head2 node

 Function: 
 Example : 
 Returns : 
 Args    : 

Components can participate in multiple interactions.  But the nodes themselves
are unique.

NB you cannot do this with Domain's, even if they are effectively equal.
Because a Domain can be later transformed, but those are all independent.

=cut
hashfield 'node';



################################################################################
=head2 read

 Function: Reads the interaction lines from the stream and produces a network
 Example : my $net = $io->read();
 Returns : L<SBG::Network>
 Args    : NA

E.g.:

RRP41 RRP42  2br2 { CHAIN A } 2br2 { CHAIN B }
# or
RRP41 RRP42  2br2 { A 5 _ to A 220 _ } 2br2 { B 1 _ to B 55 _ }

Set 'extract' to true to try to get interactions out of comment lines too
=cut
sub read {
    my ($self, $extract) = @_;
    my $fh = $self->fh;

    my $net = new SBG::Network;

    while (<$fh>) {
        next if !$extract && (/^\s*\#/ || /^\s*\%/ || /^\s*$/);
        chomp;

        my ($comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2) = 
            _parse_line($_) or next;

        my $interaction = $self->_make_interaction(
            $comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2);

        # Now put it all into the ProteinNet. 
        # Now there is a formal association beteen Interaction and it's Node's
        $net->add_interaction(
            -nodes => [$self->node($comp1), $self->node($comp2)], 
            -interaction => $interaction,
            );
    }
    # End of file
    return $net;
} # read


sub _make_node {
    my ($self, $comp, $pdbid, $descr) = @_;
    my $seq = new SBG::Seq(-accession_number=>$comp);
    my $node = $self->node($comp) || new SBG::Node($seq);
    $self->node($comp, $node);
    my $dom = new SBG::Domain(pdbid=>$pdbid,descriptor=>$descr);
    my $templ = new SBG::Template(seq=>$seq,domain=>$dom);
    return ($node, $templ);
}

sub _make_interaction {
    my ($self, $comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2) = @_;
    my ($node1, $templ1) = $self->_make_node($comp1, $pdbid1, $descr1);
    my ($node2, $templ2) = $self->_make_node($comp2, $pdbid2, $descr2);
    my $iactionid = "$templ1--$templ2";
    my $iaction = new SBG::Interaction(-id=>$iactionid);
    $iaction->template($node1,$templ1);
    $iaction->template($node2,$templ2);
    return $iaction;
}


sub _parse_line {
   my ($line) = @_;

   # Get the stuff in { brackets } first: the STAMP domain descriptors
   my ($head, $descr1, $pdbid2, $descr2, $score) = 
       parse_line('\s*[{}]\s*', 0, $line);
   # Then parse out everything else from the beginning, just on whitespace
   my @fields = parse_line('\s+', 0, $head);
   # Take the last three "words", ignoring any preceeding comments or junk
   my ($comp1, $comp2, $pdbid1) = @fields[-3,-2,-1];

   $score ||= 0;
   unless ($comp1 && $comp2 && $pdbid1 && $pdbid2) {
       warn("Cannot parse interaction line:\n", $line);
       return;
   }
   return ($comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2, $score);

} # _parse_line


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



################################################################################
__PACKAGE__->meta->make_immutable;
1;
