#!/usr/bin/env perl

use lib '..';
use EMBL::DB;
use Bio::DB::KEGG; 
use Graph;
use Graph::Writer::Dot;
use Graph::Traversal::BFS;

use Data::Dumper;
use Text::ParseWords;

my @lines = <>;
chomp for @lines;
my @ids = quotewords('\s+', 0, @lines);
# Prepend namespace qualifier for KEGG
@ids = map { "mpn:" . $_ } @ids;
my $kegg = new Bio::DB::KEGG;
my @components = map { $kegg->get_Seq_by_id($_) } @ids;

# my $seq = $kegg->get_Seq_by_id($ids[0]);
# print Dumper($seq), "\n";
# __END__

foreach my $seq (@components) {
    print $seq->display_id, "\n";
}

__END__





our $dbh = dbconnect();
our $stmt = $dbh->prepare(
    "select * from i2 where " . 
    "((mpn_id1=? and mpn_id2=?) or (mpn_id2=? and mpn_id1=?)) " .
    "and z > 0 and raw > 0 " .
    "order by z desc"
    );

my $g = assemble(\@components);

printg($g, "file.dot");

traverse($g);

misc($g);

# TODO destructor
# $dbh->close();
exit;

################################################################################

sub misc {
    my ($g) = @_;
}

sub call_tree_edge {
    my ($u, $v, $self) = @_;
    print STDERR "BFS $u $v\n"
}

sub traverse {
    my ($g) = @_;

    # Use BFS, starting with vertex with most edges
    # Just pick one of the vertices with most partners
    my ($cent) = centre($g);

    my %opt = (
        'tree_edge' => \&call_tree_edge,
        );
    my $b = Graph::Traversal::BFS->new($g, %opt);
    $b->bfs; # Do the traversal.


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
    print STDERR "Components:\n\t@$components\n";

   
#     my $g = graph($components, $adj_mat);
    my $g = graph($components);

    my $adj_mat = interactions($components, $g);

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
