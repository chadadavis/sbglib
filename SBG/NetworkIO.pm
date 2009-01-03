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

use warnings;
use Carp;
use Text::ParseWords;
use Bio::Network::ProteinNet;

use SBG::Interaction;
use SBG::Node;
use SBG::Seq;
use SBG::Domain;

################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new SBG::IO(@_);
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
        my ($head, $descr1, $templ2, $descr2, $score) = 
            parse_line('\s+[{}]\s+', 0, $_);
        # Then parse out everything else from the beginning, just on whitespace
        my ($comp1, $comp2, $templ1) = 
            parse_line('\s+', 0, $head);
        $score ||= 0;
        unless ($comp1 && $comp2 && $templ1 && $templ2) {
            carp "Cannot parse interaction:\n$_\n";
            return;
        }

        # Unique (in the whole network) interaction label/id
        my $iactionid = "$comp1($templ1 $descr1)--$comp2($templ2 $descr2)";
        print STDERR "Interaction:$iactionid $score\n";

        # Create Seq objects, using accession; and Node objects contain a Seq
        # Only if we have not already seen these component Nodes, else reuse
        $nodes{$comp1} ||= 
            new SBG::Node(new SBG::Seq(-accession_number=>$comp1));
        $nodes{$comp2} ||= 
            new SBG::Node(new SBG::Seq(-accession_number=>$comp2));
        # Template domains.
        # Will be created, even if they are equivalent to previously created dom
        # Because the template domains are specific to an interaction template
        my $dom1 = new SBG::Domain(-stampid=>$templ1,-descriptor=>$descr1);
        my $dom2 = new SBG::Domain(-stampid=>$templ2,-descriptor=>$descr2);

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
 Usage   : $io->graphviz($somegraph);
 Function:
 Example : my $io = new SBG::NetworkIO(-file=>"picture.png"); $io->graphviz($g);
 Returns : NA
 Args    : A L<Graph> e.g. a L<Bio::Network::ProteinNet>

Note: file format is determined by filename extension (by graphviz itself)

=cut
sub graphviz {
    my ($self,$graph,$format) = @_;
    my $file = $self->file || "graph.png";
    # File extension (everything after last . )
    unless ($format) {
        ($format) = $file =~ /\.([^\/]+?)$/;
        $format ||= 'png';
    }
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
