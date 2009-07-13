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

use MooseX::AttributeHelpers;
use Text::ParseWords qw/parse_line/;

use SBG::Network;
use SBG::Interaction;
use SBG::Node;
use SBG::Seq;
use SBG::Domain;


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
has 'nodes' => (
    is => 'ro',
    isa => 'HashRef[SBG::Node]',
    metaclass => 'Collection::Hash',
    lazy => 1,
    default => sub { { } },
    provides => {
        'get' => 'get',
        'set' => 'set',
    }
    );


################################################################################
=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub write {
    my ($self, $net) = @_;
    my $fh = $self->fh or return;
    foreach my $iaction ($net->interactions) {
        my @nodes = $iaction->nodes;
        my @doms = map { $iaction->get($_)->subject } @nodes;
        my @ids = map { $doms[$_]->id } (0..$#doms);
        my @descrs = map { $doms[$_]->descriptor } (0..$#doms);
        printf $fh 
            "%s\t%s\t%s\t{ %s }\t%s\t{ %s }\n",
            @nodes, $ids[0], $descrs[0], $ids[1], $descrs[1];
    }
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
    my $fh = $self->fh;

    my $net = new SBG::Network;

    while (<$fh>) {
        next if (/^\s*\#/ || /^\s*\%/ || /^\s*$/);
        chomp;

        my ($iaction, @nodes) = 
            $self->_parse_line($_) or next;

        # Now put it all into the ProteinNet. 
        # Now there is a formal association beteen Interaction and it's Node's
        $net->add_interaction(-nodes => [ @nodes ], -interaction => $iaction);

    }
    return $net;
} # read


sub _parse_line {
   my ($self, $line) = @_;

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

   my ($node1, $model1) = $self->_make_node($comp1, $pdbid1, $descr1);
   my ($node2, $model2) = $self->_make_node($comp2, $pdbid2, $descr2);

   my $iaction = new SBG::Interaction(
       models=>{ $node1=>$model1, $node2=>$model2, }
       );

   return ($iaction, $node1, $node2);

} # _parse_line


sub _make_node {
    my ($self, $accno, $pdbid, $descr) = @_;
    # Check cached nodes before creating new ones
    my $node = $self->get($accno);
    my $seq;
    unless (defined $node) {
        $seq = new SBG::Seq(-accession_number=>$accno);
        $node = new SBG::Node($seq);
        $self->set($accno, $node)
    }
    ($seq) = $node->proteins unless defined $seq;
    my $dom = new SBG::Domain(pdbid=>$pdbid,descriptor=>$descr);
    my $model = new SBG::Model(query=>$seq, subject=>$dom);

    return ($node, $model);
}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
