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
use SBG::List qw(pairs);

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

Set 'extract' to true to try to get interactions out of comment lines too
=cut
sub read {
    my ($self, $extract) = @_;
    my $fh = $self->fh;

    # refvertexed because the nodes are object refs, rather than strings or so
    my $net = Bio::Network::ProteinNet->new(refvertexed=>1);

    while (<$fh>) {
        next if !$extract && (/^\s*\#/ || /^\s*\%/ || /^\s*$/);
        chomp;

        my ($comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2, $score) = 
            _parse_line($_) or next;

        my $interaction = $self->_make_iaction(
            $comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2, $score);

        # Now put it all into the ProteinNet. 
        # Now there is a formal association beteen Interaction and it's Node's
        $net->add_interaction(
#             -nodes => [$nodes{$comp1}, $nodes{$comp2}], 
            -nodes => [$self->node($comp1), $self->node($comp2)], 
            -interaction => $interaction,
            );
    }
    # End of file
    return $net;
} # read


################################################################################
=head2 search

 Title   : search
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

# TODO doesn't belong here
=cut
sub search {
   my ($self, @components) = @_;

   # refvertexed because the nodes are object refs, rather than strings or so
   my $net = Bio::Network::ProteinNet->new(refvertexed=>1);

   # For all pairs
   foreach my $pair (pairs(@components)) {
       my ($comp1, $comp2) = @$pair;

       my @interactions = $self->grep_db($comp1, $comp2);

       foreach my $iaction (@interactions) {
           $net->add_interaction(
               -nodes => [$self->node($comp1), $self->node($comp2)], 
               -interaction => $iaction);
       }
   }

   return $net;

} # search


# Greps the benchmark text file from Rob for templates
# Parse:

#  -- 
# Can model 
# 1ir2                #pdb
# 1ir2A.c.1.14.1-1    #true1
# 1ir2A.d.58.9.1-1    #true2
# on 
# 1svdA.c.1.14.1-1    #templ1
# 1svdA.d.58.9.1-1    #templ2
# 1.000e-150          #eval1
# 77.00               #id1
# 1.000e-44           #eval2
# 70.00               #id2
# 64/129              # 1ir2 has 129 components, 1svd has 64 of them
# 0.496               # coverage fraction 64/129
# iRMSD  8.13053      # iRMSD true1--true2/templ1--templ2
# OK 31 40   0.78     # 31 out of 40 (78%) are "OK" (in what sense?)
# I2                  # The following refer to interprets2
# Z   4.188           # i2 z-score
# p 0.005             # i2 p-val
# 
sub grep_db {
    my ($self, $comp1, $comp2) = @_;
    my ($pdb) = $comp1 =~ /^(.{4})/;
    # Grep the lines from $db
    my @lines = `grep 'Can model $pdb $comp1 $comp2 on`;
    my @interactions;
    foreach (@lines) {
        unless (/( -- )?Can model $pdb $comp1 $comp2 on (\S+) (\S+)\s+(.*)$/) {
            $logger->warn("Should've been able to parse:\n$_");
            next;
        }
        my ($templ1, $templ2) = ($2, $3);
        my $scores = $4;

        my ($pdbid1, $chainid1, $scopid1) = parse_scopid($templ1);
        my ($pdbid2, $chainid2, $scopid2) = parse_scopid($templ2);
        my ($file1, undef, $descr1) = get_descriptor($scopid1);
        my ($file2, undef, $descr2) = get_descriptor($scopid2);
        
        my $iaction = $self->_make_iaction(
            $comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2);

        my ($eval1, $sid1, $eval2, $sid2, 
            $coverage, $coverage_f, 
            undef, $irmsd,
            undef, $ok_n, $ok_tot, $ok_f,
            undef, undef, $i2z, undef, $i2p,
            ) = parse_line('\s+', 0, $scores);
        
        # Save scores in the interaction template
        $iaction->score('eval1') = $eval1;
        $iaction->score('eval2') = $eval2;
        $iaction->score('seqid1') = $sid1;
        $iaction->score('seqid2') = $sid2;
        $iaction->score('irmsd') = $irmsd;
        $iaction->score('ipts2z-score') = $i2z;
        $iaction->score('ipts2p-val') = $i2p;

        push @interactions, $iaction;
    } # foreach
    return @interactions;
} # grep_db


################################################################################
=head2 _parse_line

 Title   : _parse_line
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
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
       $logger->warn("Cannot parse interaction line:\n", $line);
       return;
   }
   return ($comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2, $score);

} # _parse_line


# Components can participate in multiple interactions
# But the nodes themselves are unique
# NB you cannot do this with Domain's, even if they are effectively equal.
# Because a Domain can be later transformed, but those are all independent
sub node : lvalue {
    my ($self,$key) = @_;
    $self->{node} ||= {};
    # Do not use 'return' with 'lvalue'
    $self->{node}{$key};
}

################################################################################
=head2 _make_iaction

 Title   : _make_iaction
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
sub _make_iaction {
    my ($self, $comp1, $comp2, $pdbid1, $descr1, $pdbid2, $descr2, $score) = @_;

    # Create Seq objects, using accession; and Node objects contain a Seq
    # Only if we have not already seen these component Nodes, else reuse
    $self->node($comp1) ||= 
            new SBG::Node(new SBG::Seq(-accession_number=>$comp1));
    $self->node($comp2) ||= 
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
    $interaction->template($self->node($comp1)) = $dom1;
    $interaction->template($self->node($comp2)) = $dom2;
    return $interaction;
} # _make_iaction

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
             $str .= "\t\"" . $udom->label . "\" -- \"" . $vdom->label . "\" [" . 
                join(', ', 
#                      "label=\"" . $ix->weight . "\"",
                     "headlabel=\"" . $udom->pdbid . "\"",
                     "taillabel=\"" . $vdom->pdbid . "\"",
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
