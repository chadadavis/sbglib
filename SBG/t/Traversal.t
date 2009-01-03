#!/usr/bin/env perl

use Test::More 'no_plan';

use SBG::Traversal;
use SBG::NetworkIO;
use Data::Dumper;

# Load up a network
my $file = "$installdir/t/simple_network.csv";
my $io = new SBG::NetworkIO(-file=>$file);
my $net = $io->read;


# Create a traversal
my $trav = new SBG::Traversal(-graph=>$net, 
#                               -test=>\&try_edge,
                              -test=>\&try_edge_shorter,
                              -lastnode=>\&lastnode,
                              -lastedge=>\&lastedge,
    );

$trav->traverse;


sub lastnode {
    my ($state, $g) = @_;
    print "lastnode:", Dumper($state->{solutions}), "\n";
    $state->{solutions} = [];
}

sub lastedge {
    my ($state, $g) = @_;
    print "lastedge:", Dumper($state->{solutions}), "\n";
    $state->{solutions} = [];

}

sub try_edge_shorter {
    my ($state, $g, $u, $v, $alt_id) = @_;

    my $ix = $g->get_interaction_by_id($alt_id);
    print STDERR "== Template $ix\n";

    # Structural compatibility test (backtrack on failure)
    my $success = (0,1)[rand(2)];

    if ($success) {
        # Add this template to progressive solution
        push @{$state->{'solutions'}}, $alt_id;
    }
    return $success;
}

sub try_edge {
    my ($state, $g, $u, $v) = @_;

    # Network's IDs of Interaction's (templates) in this Edge
    my @ix_ids = $g->get_edge_attribute_names($u, $v);
    print STDERR "== ix_ids:@ix_ids:\n";
    # Make the order unique, so that indexing is deterministic
    @ix_ids = sort @ix_ids;

    # My own name for this edge (regardless of template)
    my $edge_id = "$u--$v";

    # Which of the interaction templates, for this edge, to try (next)
    my $ix_index = $state->{'eidx'}{$edge_id} || 0;

    # If no templates (left) to try, cannot use this edge
    unless ($ix_index < @ix_ids) {
        print STDERR "== No more templates\n";
        # Now reset, for any subsequent, independent attempts on this edge
        $state->{'eidx'}{$edge_id} = 0;
        return undef;
    }

    # Try next interaction template, using the Network's ID for the interaction
    my $ix_id = $ix_ids[$ix_index];

    my $ix = $g->get_interaction_by_id($ix_id);
    print STDERR "== template ", 1+$ix_index, "/" . @ix_ids, " $ix\n";

    # Structural compatibility test (backtrack on failure)
    my $success = (-1,0,1)[rand(3)];

    # Next interaction iface to try on this edge
    $state->{'eidx'}{$edge_id} = $ix_index+1;

    if ($success) {
        # Add this template to progressive solution
        push @{$state->{'solutions'}}, $ix_id;
        return 1;
    } else {
        # This means failure, 
        return -1;
    }

} # try_edge


