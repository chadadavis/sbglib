#!/usr/bin/env perl

=head1 NAME

SBG::InteractionIO::csv - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::IOI>

=cut

################################################################################

package SBG::InteractionIO::csv;
use Moose;

with qw/
SBG::IOI
/;

use Moose::Autobox;
use Carp;

use SBG::Types qw/$re_pdb $re_descriptor/;
use SBG::Interaction;

# All these needed to create an Interaction
use SBG::Interaction;
use SBG::Model;
use SBG::Domain;
use SBG::Node;
use SBG::Seq;


################################################################################
=head2 _nodes

 Function: 
 Example : 
 Returns : 
 Args    : 

Components can participate in multiple interactions.  But the nodes themselves
are unique.

NB you cannot do this with Domain's, even if they are effectively equal.
Because a Domain can be later transformed, but those are all independent.

=cut
has '_nodes' => (
    is => 'ro',
    isa => 'HashRef[SBG::Node]',
    lazy => 1,
    default => sub { { } },
    );


################################################################################
=head2 count

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub count {
    my ($self,) = @_;
    return $self->_nodes->keys->length;

} # count


################################################################################
=head2 write

 Function: tab-separated line of components and their templates 
 Example : $output->write($interaction);
 Returns : $self
 Args    : L<SBG::Interaction> - 

RRP41 RRP42  2br2 { A 108 _ to A 148 _ } 2br2 { D 108 _ to D 148 _ } 


=cut
sub write {
    my ($self, @interactions) = @_;
    my $fh = $self->fh or return;

    foreach my $iaction (@interactions) {
        next unless $iaction->nodes;
        my $nodes = [ $iaction->nodes ];
        my $models = $nodes->map(sub{ $iaction->get($_) });
        my $doms = $models->map(sub{ $_->subject });
        my $pdbs = $doms->map(sub{ $_->pdbid });
        my $descrs = $doms->map(sub{ $_->descriptor });

        printf $fh
            "%s\t%s\t%s\t{ %s }\t%s\t{ %s }\n",
            @$nodes, $pdbs->[0], $descrs->[0], $pdbs->[1], $descrs->[1];

    }
    return $self;
} # write


################################################################################
=head2 read

 Function: Reads the interaction lines from the stream and produces a network
 Example : my $net = $io->read();
 Returns : L<SBG::Interaction>
 Args    : NA

E.g.:

RRP41 RRP42  2br2first { CHAIN A } 2br2second { CHAIN B }
# or
RRP41 RRP42  2br2 { A 5 _ to A 220 _ } 2br2 { B 1 _ to B 55 _ }

=cut
sub read {
    my ($self) = @_;
    my $fh = $self->fh or return;

    while (my $line = <$fh>) {
        chomp $line;
        # Comments and blank lines
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*\%/;
        next if $line =~ /^\s*\#/;

        unless ($line =~ 
                /^\s*
                 (\S+) # Component 1
                 \s+
                 (\S+) # Component 2
                 \s+
                 (${re_pdb})\S*\s+\{\s*($re_descriptor)\s*\}
                 \s+
                 (${re_pdb})\S*\s+\{\s*($re_descriptor)\s*\}
                 \s*(.*)$
                 /x) {
            carp("Cannot parse interaction:\n$line\n");
            return;
        }

        my ($accno1, $accno2) = ($1, $2);
        my ($pdbid1, $pdbid2) = ($3, $13);
        my ($descr1, $descr2) = ($4, $14);
        my $scorestr = $23;
        $scorestr = "qw($scorestr)";
        my $scores = { eval $scorestr };

        my ($node1, $model1) = $self->_make_node($accno1, $pdbid1, $descr1);
        my ($node2, $model2) = $self->_make_node($accno2, $pdbid2, $descr2);

        my $interaction = SBG::Interaction->new();
        $interaction->set($node1 => $model1);
        $interaction->set($node2 => $model2);
        $interaction->scores($scores);
        my $weight = 
            $interaction->scores->at('weight') || 
            $interaction->scores->at('default') || 0;
        $interaction->weight($weight);
        # Return just the interaction, unless nodes also wanted
        return wantarray ? ($interaction, $node1, $node2) : $interaction;
    }
    return;
} # read


sub _make_node {
    my ($self, $accno, $pdbid, $descr) = @_;
    # Check cached nodes before creating new ones
    my $node = $self->_nodes->at($accno);
    my $seq;
    unless (defined $node) {
        $seq = SBG::Seq->new(-display_id=>$accno);
        $node = SBG::Node->new($seq);
        $self->_nodes->put($accno, $node)
    }
    ($seq) = $node->proteins unless defined $seq;
    my $dom = SBG::Domain->new(pdbid=>$pdbid,descriptor=>$descr);
    my $model = SBG::Model->new(query=>$seq, subject=>$dom);

    return ($node, $model);
}


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
