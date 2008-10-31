#!/usr/bin/env perl

use strict;
use warnings;

use Graph;
use Graph::Writer::Dot;
use Graph::Writer::GraphViz;
use Graph::Traversal::BFS;
use Text::ParseWords;
use Bio::Seq;
use Bio::Network::ProteinNet;
use Bio::Network::Node;
use Bio::Network::Edge;
use Bio::Root::IO;

# Non-CPAN libs
use lib '..';
use EMBL::DB;
use Bio::DB::KEGG; # Not (yet) Bioperl
use EMBL::Seq;
use EMBL::Node;
use EMBL::Interaction;

use Data::Dumper;

# Read IDs from a file, whitespace-separated
my $ids = read_components(shift);
# Convert to array of Bio::Seq objects
my $components = sequences($ids);
# A network of components
my $netcomponents = network($components);
# printg ($netcomponents, "components.dot");

# A network of iaction templates
my $nettemplates = read_templates(shift);
# printg ($nettemplates, "templates.dot");
# graphviz($nettemplates, "templates.png");
graphviz($nettemplates, "templates.dot");
stats($nettemplates);

# Traversing:
# MST does not seem to work on multi-edged Bio::Network::ProteinNet
# mst($nettemplates);
# BFS
traverse($nettemplates);

# mytraverse($nettemplates);



exit;

################################################################################

sub mytraverse {
    my ($g) = @_;
    
    # Can be done in parallel
    foreach my $subgraph ($g->connected_components) {
        my $start = $subgraph->[rand(@$subgraph)];
        print STDERR "start:$start:\n";

        # Recursion starts
        dive($g, $start);
    }
}

sub dive {
    my ($g, $v) = @_;
    # Incident edges

    my @edges = $g->edges_at($v);
    print STDERR "edges:", arraystr(\@edges), "\n";

    foreach my $edge (@edges) {

        my @ix_ids = $g->get_edge_attribute_names(@$edge);
        @ix_ids = sort @ix_ids;
        print STDERR "ix_ids:@ix_ids: ";

        foreach my $ix (@ix_ids) {

#             my $ix_id = $ix_ids[$state];
#             print STDERR "$state/" . @ix_ids . " ";
#             my $ix = $g->get_interaction_by_id($ix_id);
#             print STDERR "$ix ";
#             # Structural compatibility test (backtrack on failure)
#             # Simulate clash here, backtrack?
#             my $success = try_interaction($ix);
#             print STDERR $success?'Y':'N', " ";

        }

    }

}


# Convert 2D array to string list, e.g.:
# red,blue,green,grey; alpha,beta,gamma; apples,oranges
sub arraystr {
    my ($a) = @_;
    return join("; ", map { join(",", @$_) } @$a);
}

sub stats {
    my ($graph) = @_;

    print "nodes: " . $graph->nodes . "\n";
    print "edges: " . $graph->edges . "\n";
    print "interactions: " . $graph->interactions . "\n";

    print "is_countedged:", $graph->is_countedged, "\n";
    print "is_multiedged:", $graph->is_multiedged, "\n";
    print "is_multivertexed:", $graph->is_multivertexed, "\n";
    print "is_multi_graph:", $graph->is_multi_graph, "\n";

    print "is_tree:", $nettemplates->is_tree, "\n";
    print "is_forest:", $nettemplates->is_forest, "\n";

    my @arts = $graph->articulation_points;
    print "articulation_points: @arts\n";
    my @unconn = $graph->unconnected_nodes;
    print "unconnected_nodes: @unconn \n";

    my @connected = $graph->connected_components;
    print "connected_components:\n\t";
    print join("; ", map { join(",", @$_) } @connected);
    print "\n";

    print "graph:\n$graph\n";
}

sub do_visit {
    my ($v, $traversal) = @_;

}

sub no_visit {
    my ($v, $traversal) = @_;

    print STDERR "\tGiving up on $v\n";

    my $seen = $traversal->{'seen'};
    my $unseen = $traversal->{'unseen'};
    my $order = $traversal->{'order'};

    # Add it to nodes that have already been seen
    $seen->{$v} = $v;
    # Remove from unseen nodes
    delete $unseen->{$v};
    # Remove from traversal order

    # TODO determine this automatically
    # BFS works from the left of the array, DFS from the right
    # I.e. If DFS, pop. If BFS, shift
    # Actually don't need to change this, doesn't affect neighbors
#     pop @$order;


    print STDERR "\tseen:", join(",", keys %$seen), "\n";
    print STDERR "\tseeing:", join(",", @$order), "\n";
    print STDERR "\tunseen:", join(",", keys %$unseen), "\n";

}


sub try_edge {
    my ($u, $v, $traversal) = @_;

    my $g = $traversal->graph;
#     my $e = new Bio::Network::Edge([$u, $v]);
    # IDs of Interaction's in this Edge
    my @ix_ids = $g->get_edge_attribute_names($u, $v);
    @ix_ids = sort @ix_ids;
    print STDERR "ix_ids:@ix_ids: ";

    # Extract current state of this edge, if any
    my $edge_id = "$u--$v";

#     my $seen = $traversal->{'seen'};
#     my $unseen = $traversal->{'unseen'};
#     my $order = $traversal->{'order'};
#     $traversal->set_state($edge_id . "seen", $seen);
#     $traversal->set_state($edge_id . "unseen", $unseen);
#     $traversal->set_state($edge_id . "order", $order);

    # Which of the interaction templates, for this edge, to try (next)
    my $ix_index = $traversal->get_state($edge_id . "ix_index") || 0;

    # If no templates (left) to try, do not traverse this edge
    unless ($ix_index < @ix_ids) {
        no_visit($v, $traversal);
        return;
    }

    # Try next interaction template
    my $ix_id = $ix_ids[$ix_index];
    print STDERR "$ix_index/" . @ix_ids . " ";
    my $ix = $g->get_interaction_by_id($ix_id);
    print STDERR "$ix ";

    # Structural compatibility test (backtrack on failure)
    my $success = try_interaction($ix);
    print STDERR $success?'Y':'N', " ";

    $traversal->set_state($edge_id . "success", $success);

    # Next interaction iface to try on this edge
    $ix_index++;
    $traversal->set_state($edge_id . "ix_index", $ix_index);

    if ($success) {
        # Template was successful. Allow traversal to continue unaltered
    } else {
        # Cannot traverse this edge with this template
        # Redo this edge (using any remaining available interface templates)
        printf STDERR "\n";
        call_tree_edge($u, $v, $traversal);
    }
} # try_edge

sub try_interaction {
    my ($ix) = @_;

    # Structural compatibility test (backtrack on failure)
    # Simulate clash here, backtrack?
    my $success = rand() < .5;
    return $success;
}

sub call_tree_edge {
    my ($u, $v, $traversal) = @_;

    my $seen = $traversal->{'seen'};
    my $unseen = $traversal->{'unseen'};
    my $order = $traversal->{'order'};

    print STDERR "tree_edge:\n";
    print STDERR "\tseen:", join(",", keys %$seen), "\n";
    print STDERR "\tseeing:", join(",", @$order), "\n";
    print STDERR "\tunseen:", join(",", keys %$unseen), "\n";
#     print STDERR "\torder:", join(",", @{$traversal->{'order'}}), "\n";

#     print STDERR "preorder:", join(",", $traversal->preorder), "\n";


    print STDERR "\ttree_edge $u $v: ";
    try_edge($u,$v,$traversal);
    print STDERR "\n";
}

sub call_non_tree_edge {
    my ($u, $v, $traversal) = @_;
    print STDERR "non_tree_edge $u $v\n";
#     try_edge($u,$v,$traversal);
}

sub call_cross_edge {
    my ($u, $v, $traversal) = @_;
    print STDERR "cross_edge $u $v\n";
}

sub call_back_edge {
    my ($u, $v, $traversal) = @_;
    print STDERR "back_edge $u $v\n";
}

sub call_down_edge {
    my ($u, $v, $traversal) = @_;
    print STDERR "down_edge $u $v\n";
}

sub call_pre_edge {
    my ($u, $v, $traversal) = @_;
    print STDERR "pre_edge $u $v\n";
}

sub call_post_edge {
    my ($u, $v, $traversal) = @_;
    print STDERR "post_edge $u $v: ";

    # Extract current state of this edge, if any
    my $edge_id = "$u--$v";
    my $success = $traversal->get_state($edge_id . "success");

    # If placing the last interface template succeeded, we have partial solution
    if ($success) {
        # Output partial solution
        # TODO also needs to be saved "in the Traversal"
        print STDERR "partial model result\n";
    }

    # TODO
    # If there are any templates left to try, reset traversal state
    # Causes traversal to do this edge again.
    # But counter will cause the next template(s) to be tried now


}

sub call_pre_vertex {
    my ($v, $traversal) = @_;
    print STDERR "pre_vertex $v\n";
}

sub call_post_vertex {
    my ($v, $traversal) = @_;
    print STDERR "post_vertex $v\n";
}

sub traverse {
    my ($g) = @_;

    # NB back_edge identifies potentially novel interfaces

    # Setup callbacks
    my %opt = (
#         'pre_vertex' => \&call_pre_vertex,
        'pre' => \&call_pre_vertex,
#         'post_vertex' => \&call_post_vertex,
        'post' => \&call_post_vertex,
        # tree_edge : an edge actually traversed in traversal tree
        'tree_edge' => \&call_tree_edge,
        # cross_edge : seems to exist only for BFS
        'cross_edge' => \&call_cross_edge,
        # back_edge : reaching a vert already seen in the current traversal
        'back_edge' => \&call_back_edge,
        # down_edge : reaching a vert already seen from a previous traversal
#         'down_edge' => \&call_down_edge,
        # non_tree_edge : back_edge , down_edge , or cross_edge
#         'non_tree_edge' => \&call_non_tree_edge,
#         'pre_edge' => \&call_pre_edge,
        'post_edge' => \&call_post_edge,
        );

#     my $b = Graph::Traversal::BFS->new($g, %opt);
#     $b->bfs; 
    my $b = Graph::Traversal::DFS->new($g, %opt);
    $b->dfs; 


}

sub centre {
    my ($g) = @_;

    foreach my $v ($g->vertices) {
        print STDERR "ecc ", $v, " ", $g->vertex_eccentricity($v), "\n";
    }

    print STDERR "diameter ", join(" ", $g->diameter()), "\n";
    print STDERR "radius ", join(" ", $g->radius()), "\n";

    my @cent = $g->centre_vertices(1.0); # Doesn't do multiedged
#     print STDERR "center: @cent \n";
    return @cent;

}


sub mst {
    my ($g) = @_;


#     print STDERR "Graph:\n$g\n";

    my $mst = $g->MST_Kruskal; # Doesn't do multiedged
#     my $mst = $g->MST_Prim; # Doesn't do multiedged
#     my $mst = $g->MST_Dijkstra; # Doesn't do multiedged

    printg($g, "mygraph.dot");
    printg($mst, "mymst.dot");
}

sub assemble {
    my ($components) = @_;
    print "Components:\n\t";

    # Put proteins as lone vertices into new graph
    my $g = graph($components);

#     my $adj_mat = interactions($components, $g);

    return $g;

}

sub graph {
#     my ($components, $adj_mat) = @_;
    my ($components) = @_;
    my $edges = [];

    my $g = Graph::Undirected->new(
#         'refvertexed'=>1,
#         'unionfind'=>1,
#         'multiedged'=>1,    # Allow mult. instances of an edge (iface template)
#         'multivertexed'=>1, # Allow mult. instances of a vertex (component)
        'vertices'=>$components,
#         'edges'=>...
        );
    return $g;
}


sub network {
    my ($sequences) = @_;
    my $graph = Bio::Network::ProteinNet->new(
        refvertexed => 1,
        vertices => $sequences,
        );
    return $graph;
}


sub keggsequences {
    my ($ids) = @_;

    # Fetch actual sequence records from KEGG
    # Prepend namespace qualifier for KEGG
    my @keggids = map { "mpn:" . $_ } @$ids;
#     print "IDs:\n@keggids\n";
    my $kegg = new Bio::DB::KEGG;
    my @components = map { $kegg->get_Seq_by_id($_) } @keggids;
    
    foreach my $c (@components) {
    #     print $c->primary_id, " ";
#         print $c->accession_number, " ";
    }
    return \@components;
}

sub sequences {
    my ($ids) = @_;
    my @components = map { Bio::Seq->new(-accession_number => $_); } @$ids;
    return \@components;
}


sub interactions {
    my ($components, $g) = @_;

    my @adj_mat;
    for (my $i = 0; $i < @$components; $i++) {
        $adj_mat[$i] ||= [];
        for (my $j = $i+1; $j < @$components; $j++) {
            my $hits = templates($components->[$i], $components->[$j]);

            foreach my $hit (@$hits) {

                # TODO use hashref, rather than arrayref here
                my $weight = $hit->[12];
                my $id = join(" ", $hit->[2],$hit->[3],$hit->[5],$hit->[6]);
#                 print STDERR "\t$id $weight\n";
#                 $g->add_weighted_edge_by_id(
#                     $components->[$i], $components->[$j], $weight, $id);
                $g->add_weighted_edge(
                    $components->[$i], $components->[$j], $weight);

                # TODO use set_edge_attribute set_edge_attributes set_edge_attribute_by_id set_edge_attributes_by_id
#                $g->set_edge_attribute_by_id($u, $v, $id, $name, $value)
#                $g->set_edge_attributes_by_id($u, $v, $id, $attr)
#  $g->set_graph_attribute($name, $value)
            }

            $adj_mat[$i][$j] = $adj_mat[$j][$i] = $hits;
        }
    }

    return \@adj_mat;
}


sub templates {
    my ($a, $b) = @_;
    our $dbh;
    our $stmt;

    $stmt->execute($a,$b,$a,$b);
#     my $res = $dbh->selectall_hashref($stmt, [qw()], 
#     my $res = $dbh->selectall_hashref($stmt, [qw()], 
    my $table = $stmt->fetchall_arrayref;
#     return $stmt->fetchrow_hashref;

#     print Dumper $table;
    my $rows = $stmt->rows;
#     print STDERR "$a <=> $b : $rows\n" if $rows;
    print STDERR "$a <=> $b : $rows\n";
    return $table;
}


sub printg {
    my ($graph, $file) = @_;
    $file ||= "mygraph.dot";
    my $writer = Graph::Writer::Dot->new();
    $writer->write_graph($graph, $file);
}

sub graphviz {
    my ($graph, $file) = @_;
    $file ||= "mygraph.png";
    my ($format) = $file =~ /\.(.*?)$/;
#     print STDERR "$file:$format:\n";
    $format ||= 'png';
    my $writer = Graph::Writer::GraphViz->new(
        -format => $format,
#         -layout => 'twopi',
#         -layout => 'fdp',
        -ranksep => 1.5,
        -fontsize => 8,
        -edge_color => 'grey',
        -node_color => 'black',
        );
    $writer->write_graph($graph, $file);

}

sub read_components {
    my ($file) = @_;
    my $io = Bio::Root::IO->new(-file => $file);
    my @components;
    while (my $l = $io->_readline() ) {
        push @components, split(/\s+/, $l);
    }
    return \@components;
}

sub read_templates {
    my ($file) = @_;

    my $io = Bio::Root::IO->new(-file => $file);
    my $graph = Bio::Network::ProteinNet->new(
        refvertexed => 1,
        );
    
    # Must save the nodes we have already created, so as not to duplicate
    my %nodes;

    while (my $l = $io->_readline() ) {
        # Skip comments/blank lines
        next if ($l =~ /^\s*$/ or $l =~ /^\s*#/);

        my ($comp_a, $comp_b, $templ_a, $templ_b, $score) = split(/\s+/, $l);

        # Create network nodes from sequences. Sequences from accession_number
        $nodes{$comp_a} ||= 
            new Bio::Network::Node(new Bio::Seq(-accession_number=>$comp_a));
        $nodes{$comp_b} ||= 
            new Bio::Network::Node(new Bio::Seq(-accession_number=>$comp_b));

        # create new Interaction object based on an id and weight
        # NB the ID must be unique in the whole graph
        my $interaction = Bio::Network::Interaction->new(
            -id => "${comp_a}~${templ_a}/${templ_b}~${comp_b}",
            -weight => $score,
            );

        # TODO Trying to get GraphViz to display edge labels ...
#         $interaction->{'label'} = $interaction->primary_id;

        print STDERR 
            "Adding: $comp_a, $comp_b via ", $interaction->primary_id, "\n";

        $graph->add_interaction(
#             -nodes => [($prot1,$prot2)],
#             -nodes => [($components{$comp_a}, $components{$comp_b})], 
#             -nodes => [$components{$comp_a}, $components{$comp_b}], 
            -nodes => [$nodes{$comp_a}, $nodes{$comp_b}], 
            -interaction => $interaction,
            );
    }

    return $graph;
}


################################################################################

__END__

# our $dbh = dbconnect("pc-russell12", "mpn_i2");
# our $stmt = $dbh->prepare(
#     "select * from i2 where " . 
#     "((mpn_id1=? and mpn_id2=?) or (mpn_id2=? and mpn_id1=?)) " .
#     "and z > 0 and raw > 0 " .
#     "order by z desc"
#     );
