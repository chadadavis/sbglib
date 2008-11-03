#!/usr/bin/env perl

=head1 NAME

EMBL::Traversal - A recusive back-tracking traversal for Graph

=head1 SYNOPSIS

use EMBL::Traversal

# Create a new Prediction object
my $traversal = new EMBL::Traversal($mygraph);

=head1 DESCRIPTION

See also L<Graph::Traversal>

=head1 BUGS

None known.

=head1 REVISION

$Id: Prediction.pm,v 1.33 2005/02/28 01:34:35 uid1343 Exp $

=head1 APPENDIX

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################

package EMBL::Traversal;

use strict;
use warnings;

use Clone qw(clone);
use List::Util;

use lib "..";

use Graph;
use Graph::UnionFind;

use Data::Dumper;


################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    :

=cut

sub new {
    my ($class, $graph, $consider, @args) = @_;
    my $self = {};
    bless $self, $class;

    $self->{graph} = $graph;
    $self->{consider} = $consider;

    return $self;

} # new

sub get_state {
    my ($self, $key) = @_;
    return ${$self->{state}}{$key};
}

sub set_state {
    my ($self, $key, $value) = @_;
    ${$self->{state}}{$key} = $value;
    return ${$self->{state}}{$key};
}


sub traverse {
    my ($self) = @_;
    my $graph = $self->graph;

    # Start with all vertices, independent
    my @vertices = $self->graph()->vertices();
    # Shuffle them
    @vertices = List::Util::shuffle @vertices;

    # Start with full set of vertices
#     $self->do_node($uf, @vertices);
#     $self->do_set(@vertices);
#     $self->do_nodes2(@vertices);
    push @{$self->{next_nodes}}, @vertices;

    my $uf = new Graph::UnionFind;
    $uf->add($_) for @nodes;

    $self->do_nodes2($uf);

}


sub do_edges2 {
    my ($self, $uf) = @_;
    my $current = pop @{$self->{next_edges}};
    my ($src, $dest) = @$current;

    my $result = $self->consider()->($start, $neighbor, $self);
    if (!defined $result) {
        # No more templates left for this edge
        return;
    }

    my $clone = clone($uf);

    if (0 == $result) {
        # Failed to use the currently attempated template
    } else {
        # Successfully placed the current interaction template
        push @{$self->next_nodes}, $dest;
        $clone->union($src, $dest);
    }

    # Recursive call
    $self->do_edges2($clone);
    # After recursive call: 

}

sub do_nodes2 {
    my ($self, $uf) = @_;
    my $current = pop @{$self->{next_nodes}};

    my @unseen = $self->new_neighbors($current, $uf);
    for my $neighbor (@unseen) {
        # push edges onto stack
        push(@{$self->next_edges}, [$current, $neighbor]);
    }
    $self->do_edges2($uf);

}


sub new_neighbors {
    my ($self, $node, $uf) = @_;

    my @adj = $self->graph()->neighbors($node);
    # Only adjacent vertices not already in same traversal set (i.e. the unseen)
    my @unseen = grep { ! $uf->same($node, $_) } @adj;

    print STDERR "\tadj: @adj; unseen: @unseen\n";

    return @unseen;
}


sub do_set {
    my ($self, @nodes) = @_;

    # UnionFind data structure to track where we already were
    my $uf = new Graph::UnionFind;
    $uf->add($_) for @nodes;

    foreach my $entry (@nodes) {
        print STDERR "Entry: $entry\n";
        my $clone = clone($uf);
        $self->do_node($clone, $entry, []);

        # TODO DEL
        # Just do a single (random) entry point for now
        last;
    }
}


sub do_node {
    my ($self, $uf, $start, $assembly) = @_;

    print STDERR "At $start:\n";
    my @unseen = $self->new_neighbors($start, $uf);

    foreach my $neighbor (@unseen) {
        print STDERR "\t$start -- $neighbor\n";

        # Make a copy where edge is established (pass this down)
        # TODO DES This is a lot of copying. Alternatives?
        my $clone = clone($uf);

        # In this temporary copy, union my neighbor into my set
        $clone->union($start, $neighbor);

        # As long as this edge is successful, keep 'running' it

        # TODO DES this doesn't make sense because it stop on the first failure
        # As I don't know the difference between "single failure" and "exhausted"

        while (my $result = $self->consider()->($start, $neighbor, $self)) {
            # OK, visit the neighboring vertex
            # Process outstanding vertices, with this edge now in place
#             $self->do_node($clone, @nodes);

            # Partial solution, pass it down traversal tree
            push @$assembly, $result;
            # Get the assembly that's passed back up
            my $lowerassembly = $self->do_node($clone, $neighbor, $assembly);
            # Undo the partial solution after backtracking
            pop @$assembly;

            # NB we don't try to combine partial solutions over the same edge
        }
        print STDERR "\t<= back at edge: $start -- $neighbor\n";
    }
    # This node is done, do rest of forest without this node
    # This is important, as the interaction network may be disconnected

    # TODO DES Of course, this also causes the whole procedure to be repeated
    # for every possibly entry point to the graph. I.e. many duplicate
    # solutions. But at least some of these are necessary in the case where
    # we've picked a bad entry point. Alternative, do_node could return what
    # nodes it has already processed.

    # TODO save solution, if any (use a callback)
    print STDERR "\tDone at $start: Assembly: @$assembly\n";
    return $assembly
#     $self->do_node($uf, @nodes);

}

################################################################################
=head2 AUTOLOAD

 Title   : AUTOLOAD
 Usage   : $obj->member_var($new_value);
 Function: Implements get/set functions for member vars. dynamically
 Returns : Final value of the variable, whether it was changed or not
 Args    : New value of the variable, if it is to be updated

Overrides built-in AUTOLOAD function. Allows us to treat member vars. as
function calls.

=cut

sub AUTOLOAD {
    my ($self, $arg) = @_;
    our $AUTOLOAD;
    return if $AUTOLOAD =~ /::DESTROY$/;
    my ($pkg, $file, $line) = caller;
    $line = sprintf("%4d", $line);
    # Use unqualified member var. names,
    # i.e. not 'Package::member', rather simply 'member'
    my ($field) = $AUTOLOAD =~ /::([\w\d]+)$/;
    $self->{$field} = $arg if defined $arg;
    return $self->{$field} || '';
} # AUTOLOAD


###############################################################################

1;

__END__
