#!/usr/bin/env perl

=head1 NAME

SBG::NetworkIO::csv - Reads interactions and their templates from CSV file

=head1 SYNOPSIS

 use SBG::NetworkIO::csv;
 my $in = new SBG::NetworkIO::csv(file=>"interactions.csv");
 my $net = $in->read;
 my $out = new SBG::NetworkIO::graphviz(file=>">interactions.png");
 $out->write($net);

=head1 DESCRIPTION

Input routines for building up L<SBG::Interaction> objects from CSV file
input. Produces a L<SBG::Network> from them.

The input format contains one interaction per line, with this format:

 component1 component2 pdbid1 { descriptor } pdbid1 { descriptor }

Where:

component1/component2 are labels for the interacting proteins. These can be any
label, but accession numbers, e.g. UniProt would be sensible.

pdbid1/pdbid2 are PDB identifiers for the structures upon which
component1/component2 are modelled.

The descriptors are regular STAMP descriptors, in { braces }.  See:

 http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

The score can be any decimal number. Larger numbers imply stronger
interactions. The units and meaning of this score are not specified.


NB interaction templates need to have unique labels


Example:

 RRP42 RRP43  2br2b { CHAIN B } 2br2d { CHAIN D } 22.32

=head1 SEE ALSO

L<SBG::Interaction> , L<SBG::Network>

=cut

################################################################################

package SBG::NetworkIO::csv;
use Moose;

with qw/
SBG::IOI
/;


# In CSV format, a Network is just a set of Interaction
use SBG::InteractionIO::csv;

# All these needed to create a Network
use SBG::Network;
use SBG::Interaction;
use SBG::Node;


################################################################################
=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub write {
    my ($self, $net) = @_;
    # Delegate to InteractionIO
    my $iactionio = new SBG::InteractionIO::csv(%$self);

    $iactionio->write($_) for $net->interactions;

    return $self;
} # write


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

=cut
sub read {
    my ($self) = @_;
    # Delegate to InteractionIO
    my $iactionio = new SBG::InteractionIO::csv(%$self);

    my $net = new SBG::Network;
    while (my ($iaction, @nodes) = $iactionio->read) {

        # Now put it all into the ProteinNet. 
        # Now there is a formal association beteen Interaction and it's Node's
        $net->add_interaction(-nodes => [ @nodes ], -interaction => $iaction);

    }
    return $net;
} # read


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
