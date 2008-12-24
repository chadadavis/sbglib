#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;

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
use lib '..', "../..";
use EMBL::DB;
use Bio::DB::KEGG; # Not (yet) Bioperl
use EMBL::Seq;
use EMBL::Node;
use EMBL::Interaction;
use EMBL::CofM;
use EMBL::Sphere;
use EMBL::Transform;

use PDL;

# Read IDs from a file, whitespace-separated
# my $ids = read_components(shift);
# Convert to array of Bio::Seq objects
# my $components = sequences($ids);
# A network of components
# my $netcomponents = network($components);
# printg ($netcomponents, "components.dot");

# A network of iaction templates
my $nettemplates = read_templates(shift);

# our $OUT = "./tmp";
our $OUT = "./out";


# graphviz($assembly, "$OUT/assembly.dot");
graphviz($nettemplates, "$OUT/templates.dot");
# stats($nettemplates);

# TODO DOC Traversing:
# MST does not seem to work on multi-edged Bio::Network::ProteinNet
# mst($nettemplates);
# BFS
# traverse($nettemplates);

mytraverse($nettemplates);


exit;

################################################################################


use EMBL::Traversal;
sub mytraverse {
    my ($templategraph) = @_;

    # TODO also need a callback for processing a solution
    my $t = new EMBL::Traversal($templategraph, \&try_edge);
    $t->traverse;

}



sub _stats {
    my ($graph) = @_;

    print "\nStatistics:\n";
    print "\tgraph:\n\t$graph\n";

    print "\tnodes: " . $graph->nodes . "\n";
    print "\tedges: " . $graph->edges . "\n";
    print "\tinteractions: " . $graph->interactions . "\n";

    print "\tis_countedged:", $graph->is_countedged, "\n";
    print "\tis_multiedged:", $graph->is_multiedged, "\n";
    print "\tis_multivertexed:", $graph->is_multivertexed, "\n";
    print "\tis_multi_graph:", $graph->is_multi_graph, "\n";

    print "\tis_tree:", $nettemplates->is_tree, "\n";
    print "\tis_forest:", $nettemplates->is_forest, "\n";

    my @arts = $graph->articulation_points;
    print "\tarticulation_points: @arts\n";
    my @unconn = $graph->unconnected_nodes;
    print "\tunconnected_nodes: @unconn \n";

    my @connected = $graph->connected_components;
    print "\tconnected_components:\n\t";
    print join("; ", map { join(",", @$_) } @connected);
    print "\n";

    print "\n";
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

    # Try to remove edge to successor node from traversal tree
    my $current = $traversal->current;
    $traversal->{tree}->delete_edge( $current, $v );


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
#     my ($u, $v, $traversal, $ix_index) = @_;
    my ($u, $v, $traversal, $assembly) = @_;

#     $ix_index ||= 0;

    print STDERR "\ttry_edge $u $v:\n";
    my $g = $traversal->{graph};

    # IDs of Interaction's (templates) in this Edge
    my @ix_ids = $g->get_edge_attribute_names($u, $v);
    @ix_ids = sort @ix_ids;

    # Extract current state of this edge, if any
    my $edge_id = "$u--$v";
    # Which of the interaction templates, for this edge, to try (next)
    my $ix_index = $traversal->get_state($edge_id . "ix_index") || 0;

    # If no templates (left) to try, cannot use this edge
    unless ($ix_index < @ix_ids) {
        print STDERR "\tNo more templates\n";
        # Now reset, for any subsequent, independent attempts on this edge
        $traversal->set_state($edge_id . "ix_index", 0);
        return undef;
    }

    # Try next interaction template
    my $ix_id = $ix_ids[$ix_index];
    print STDERR "\ttemplate ", 1+$ix_index, "/" . @ix_ids . "\n";
    my $ix = $g->get_interaction_by_id($ix_id);
#     print STDERR "$ix ";

    # Structural compatibility test (backtrack on failure)
#     my $success = try_interaction($ix);
#     my $success = try_interaction2($traversal->assembly, $ix, $u, $v);
#     my $success = try_interaction2($assembly, $ix, $u, $v);
    my $success = try_interaction3($assembly, $ix, $u, $v);


#     $traversal->set_state($edge_id . "success", $success);

    # Next interaction iface to try on this edge
    $ix_index++;
    $traversal->set_state($edge_id . "ix_index", $ix_index);

    print STDERR "\n";

    if ($success) {
        return $ix_id;
    } else {
        # This means failure, 
        # This is not the same as exhausting the templates (that's undef)
        return 0;
        # I.e. do not recurse here
    }

} # try_edge

sub try_interaction {
    my ($ix) = @_;

    # Structural compatibility test (backtrack on failure)
    # Simulate clash here, backtrack?
    my $success = rand() < .50;
    return $success;
}

# TODO should be member function of Assembly module
sub try_interaction2 {
    my ($assembly, $iaction, $src, $dest) = @_;
    my $success = 0;

    # Lookup $src in $iaction to identify its monomeric template domain
    # Uses the hash saved in the interation object (set when templates loaded)
    my $srcdom = $iaction->{template}{$src};
    my $destdom = $iaction->{template}{$dest};

    print STDERR "\t$src($srcdom)->$dest($destdom)\n";

    # Get reference domain of $src 
    # (base case: no previous structural constraint, implicitly sterically OK)
    # This should only happen on the first edge processed
    if (! defined $assembly->transform($src)) {
        
        my $srccofm = new EMBL::CofM();
        $srccofm->label($src);
        $srccofm->fetch($srcdom);
        $assembly->transform($src, new EMBL::Transform);
        $assembly->cofm($src, $srccofm);
        
        # Do the same for the $dest, as it's in the same frame of reference
        my $destcofm = new EMBL::CofM();
        $destcofm->label($dest);
        $destcofm->fetch($destdom);
        $assembly->transform($dest, new EMBL::Transform);
        $assembly->cofm($dest, $destcofm);
        
        print STDERR 
            "\n\tInitial FoR CofMs: $srccofm; $destcofm\n";

        return $success = 1;
    } else {

    }

    # Get the transformation and reference domain for the source node

    # TODO just save CofM, it should have handle to it's own Transform

    # Find the frame of reference for the source
    my $reftrans = $assembly->transform($src);
    my $refcofm = $assembly->cofm($src);
    # STAMP dom identifier (PDBID/CHAINID)
    my $refdom = $refcofm->id;

    print STDERR "\trefcofm: $refcofm\n";
#     print STDERR "\treftrans: $reftrans\n";

    # Use local file-cache of STAMP results
    # TODO abstract this into a DB cache as well
    my $nexttrans = stampfile($srcdom, $refdom);
    if (! defined $nexttrans) { 
        return $success = 0; 
    }

    # Product of relative with absolute transformation
    # TODO DOC order of mat. mult.

#     my $next_ref = $nexttrans * $reftrans;
    my $ref_next = $reftrans * $nexttrans;

    # Then apply that transformation to the interaction partner $dest
    # Get CofM of dest template domain (the one to be transformed)
    my $destcofm = new EMBL::CofM();
    $destcofm->label($dest);
    $destcofm->fetch($destdom);
    # Apply transform(s) to cofm of $dest
    $destcofm->ttransform($ref_next);
#     $destcofm->ttransform($next_ref);


    # Successfully transformed $dest template into current FoR
#     print STDERR "\t$destdom cofm next*ref after : $destcofm\n";

    # Check new coords of dest for clashes across currently assembly
    # TODO
    $success = ! $assembly->clashes($destcofm);


    # if success, update FoR of dest
    if ($success) {
        $assembly->transform($dest, $ref_next);
#         $assembly->transform($dest, $next_ref);

        $assembly->cofm($dest, $destcofm);
    }

    print STDERR "\ttry_interaction ", $success ? "succeeded" : "failed", "\n";
    return $success;

} # try_interaction2


# TODO DOC:
# Uses the hash saved in the interation object (set when templates loaded) to find out what templates used by which components on and edge in the interaction graph
sub try_interaction3 {
    my ($assembly, $iaction, $src, $dest) = @_;
    my $success = 0;

    # Lookup $src in $iaction to identify its monomeric template domain
    my $srcdom = $iaction->{template}{$src};
    my $destdom = $iaction->{template}{$dest};
    print STDERR "\t$src($srcdom)->$dest($destdom)\n";

    # Get reference domain of $src 
    my $srccofm = $assembly->cofm($src);

    unless (defined $srccofm) {
        # base case: no previous structural constraint, implicitly sterically OK
        $srccofm = new EMBL::CofM($src, $srcdom);
        # Save CofM object for src component in assembly, indexed by $src
        $assembly->cofm($src, $srccofm);
        my $destcofm =  new EMBL::CofM($dest, $destdom);
        $assembly->cofm($dest, $destcofm);
        return $success = 1;
    }

    # Find the frame of reference for the source
    # STAMP dom identifier (PDBID/CHAINID), TODO should be a descriptor
    my $refdom = $srccofm->id;

    # Superpose this template dom of the src component onto the reference dom
    # TODO abstract this into a DB cache as well
    my $nexttrans = stampfile($srcdom, $refdom);
    if (! defined $nexttrans) { 
        return $success = 0; 
    }

    # Then apply that transformation to the interaction partner $dest
    # Get CofM of dest template domain (the one to be transformed)
    # NB Any previous $assembly->cofm($dest) gets overwritten
    my $destcofm =  new EMBL::CofM($dest, $destdom);

    # Product of relative with absolute transformation
    # TODO DOC order of mat. mult.
    $destcofm->apply($srccofm->cumulative * $nexttrans);

    # Check new coords of dest for clashes across currently assembly
    $success = ! $assembly->clashes($destcofm);
    if ($success) {
        # Update frame-of-reference of interaction partner
        $assembly->cofm($dest, $destcofm);
    }

    print STDERR "\ttry_interaction ", $success ? "succeeded" : "failed", "\n";
    return $success;

} # try_interaction3


# Transformation will be relative to fram of reference of destdom
sub stampfile {
    my ($srcdom, $destdom) = @_;

    # STAMP uses lowercase chain IDs
    $srcdom = lc $srcdom;
    $destdom = lc $destdom;

    if ($srcdom eq $destdom) {
        # Return identity
        return new EMBL::Transform;
    }

    print STDERR "\tSTAMP ${srcdom}->${destdom}\n";
    my $dir = "/tmp/stampcache";
#     my $file = "$dir/$srcdom-$destdom-FoR.csv";
    my $file = "$dir/$srcdom-$destdom-FoR-s.csv";

    if (-r $file) {
        print STDERR "\t\tCached: ";
        if (-s $file) {
            print STDERR "positive\n";
        } else {
            print STDERR "negative\n";
            return undef;
        }
    } else {
        my $cmd = "./transform.sh $srcdom $destdom $dir";
        $file = `$cmd`;
    }

    my $trans = new EMBL::Transform();
    unless ($trans->loadfile($file)) {
        print STDERR "\tSTAMP failed: ${srcdom}->${destdom}\n";
        return undef;
    }
    return $trans;
} 

# Check DB cache first
sub transform {
    my ($srcdom, $refdom) = @_;
    print STDERR "\tSuperposing $srcdom onto $refdom\n";

    # TODO DOC STAMP uses lowercase chain IDs in domain identifiers



}


sub print_seeing {
    my ($traversal) = @_;

    my $seen = $traversal->{'seen'};
    my $unseen = $traversal->{'unseen'};
    my $order = $traversal->{'order'};

    print STDERR "\tseen:", join(",", keys %$seen), "\n";
    print STDERR "\tseeing:", join(",", @$order), "\n";
    print STDERR "\tunseen:", join(",", keys %$unseen), "\n";
#     print STDERR "\torder:", join(",", @{$traversal->{'order'}}), "\n";

}

sub call_tree_edge {
    my ($u, $v, $traversal) = @_;

    print STDERR "tree_edge:\n";
    print_seeing($traversal);

    try_edge($u,$v,$traversal);
    print STDERR "\n";
}

sub call_non_tree_edge {
    my ($u, $v, $traversal) = @_;
    print STDERR "non_tree_edge $u $v\n";
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
    print STDERR "pre_edge: $u $v\n";
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
    # Though, counter will cause the next template(s) to be tried next


}

sub call_pre_vertex {
    my ($v, $traversal) = @_;
    print STDERR "pre_vertex $v\n";
}

sub call_post_vertex {
    my ($v, $traversal) = @_;
    print STDERR "post_vertex $v\n";
}


sub call_next_successor {
    my ($traversal, $next) = @_;

    # next is has of vertices that we could visit. Choose one.
    my @keys = keys %$next;
    print STDERR 
        "next_successors: ", join(",", keys %$next), "\n";
    my $successor_node;
    my $success = 0;
    foreach my $key (keys %$next) {
        my $v = $next->{$key};
        my $success = try_edge($traversal->current, $v, $traversal);
        last if $success;
    }

    print STDERR "\tsuccessor: $successor_node\n";
    return $successor_node;
    
}


sub traverse {
    my ($g) = @_;

    # NB back_edge identifies potentially novel interfaces

    # Setup callbacks
    my %opt = (
        # pre_edge is the same as tree_edge
        'pre_edge' => \&call_pre_edge,
#         'pre_vertex' => \&call_pre_vertex,
        'pre' => \&call_pre_vertex,
#         'post_vertex' => \&call_post_vertex,
        'post' => \&call_post_vertex,
        # tree_edge : an edge actually traversed in traversal tree
#         'tree_edge' => \&call_tree_edge,
        # cross_edge : seems to exist only for BFS
        'cross_edge' => \&call_cross_edge,
        # back_edge : reaching a vert already seen in the current traversal
        'back_edge' => \&call_back_edge,
        # down_edge : reaching a vert already seen from a previous traversal
#         'down_edge' => \&call_down_edge,
        # non_tree_edge : back_edge , down_edge , or cross_edge
#         'non_tree_edge' => \&call_non_tree_edge,
        'post_edge' => \&call_post_edge,
        'next_successor' => \&call_next_successor,
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
    # File extension (everything after last . )
    my ($format) = $file =~ /\.([^\/]+?)$/;
    $format ||= 'png';
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

        print STDERR "iaction:", join(",", $comp_a, $comp_b, $templ_a, $templ_b, $score), "\n";
        
        # TODO could also be other templates (+score) on this line, for
        # modelling this interaction. Could loop over these too.

        # Create network nodes from sequences. Sequences from accession_number
        $nodes{$comp_a} ||= 
            new Bio::Network::Node(new Bio::Seq(-accession_number=>$comp_a));
        $nodes{$comp_b} ||= 
            new Bio::Network::Node(new Bio::Seq(-accession_number=>$comp_b));

        # TODO save a Template obj in Interaction?
        # Since that's exactly what it represents

        # create new Interaction object based on an id and weight
        # NB the ID must be unique in the whole graph
        my $interaction = Bio::Network::Interaction->new(
            -id => "${comp_a}-${comp_b}(${templ_a}-${templ_b})",
            -weight => $score,
            );

        # Add a dictionary to lookup which domain is model for which component
        $interaction->{template} = { 
            $comp_a => $templ_a, $comp_b => $templ_b,
        };

        # TODO Trying to get GraphViz to display edge labels ...
#         $interaction->{'label'} = $interaction->primary_id;

#         print STDERR 
#             "Adding: $comp_a, $comp_b via ", $interaction->primary_id, "\n";

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
