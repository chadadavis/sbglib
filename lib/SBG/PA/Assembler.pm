#!/usr/bin/env perl

=head1 NAME

PA - Peptide assembler callbacks

=head1 SYNOPSIS

use PA;

=head1 DESCRIPTION

=head1 REQUIRES

* Graph
* Graph::Traversal::DFS
* SBG::GeometricHash


=head1 SEE ALSO

L<SBG::Traversal>

=cut

################################################################################

package SBG::PA::Assembler;

use File::Temp qw/tempfile/;

use SBG::GeometricHash;
use PDL::Matrix;

our $gh = new SBG::GeometricHash(binsize=>1);

sub sub_test {
    my ($state, $graph, $src, $dest, $edge_id) = @_;

    # Check that peptides stays linear, no branching
    # Only need to check $src, not $dest, since traversal doesn't do cycles
    return unless $state->{'active'}{$src} < 2;

    # Check spacial clash, AA already present here?
    my $occupied = $state->{'pthash'}{$dest->hash};

    if (! $occupied) {
        $state->{'pthash'}{$dest->hash} = $dest;
        $state->{'pthash'}{$src->hash} = $src;

        $state->{'active'}{$src}++;
        $state->{'active'}{$dest}++;
    } else {
#         print "Clash: $dest on $occupied\n";
    }

    return ! $occupied;
}

# Points and labels, for use with GeometricHash
sub _pl {
    my ($names) = @_;
#     print "names:@$names:\n";
    my @labels = map { substr($_,0,1) } @$names;
#     print "labels:@labels:\n";
    my @strcoords = map { substr($_,1) } @$names;
    my @arrcoords = map { [ split ',', $_ ] } @strcoords;
    my @pdlcoords = map { mpdl($_)->transpose } @arrcoords;
#     print "pdlcoords\n@pdlcoords\n";

    return \@pdlcoords, \@labels;
}


sub sub_solution_gh {
    my ($state, $graph, $nodecover, $edges, $rejects) = @_;
    our $gh;
    our %edgesets;

    my ($points, $labels) = _pl($nodecover);

    my $class = $gh->class($points, $labels);
    my $edgekey = join('', sort @$edges);
    if ($class) {
        print "Dup: @$nodecover\n";
        if ($edgesets{$edgekey}) {
            print "And same edges: $edgekey\n";
            return;
        } else {
            print "But different edges: $edgekey\n";
        }
    }
    $class = $gh->put(undef, $points, $labels);
    $edgesets{$edgekey} = 1;

    # Get the subgraph and find the path from one end to other
    my $sg = _subgraph2($graph, @$edges);
    my @path = _orderedpath($sg);
    print "@path\n";
    return 1;
}


sub sub_solution_pathhash {
    my ($state, $graph, $nodecover, $edges, $rejects) = @_;
    our %paths;

    # Get the subgraph and find the path from one end to other
    my $sg = _subgraph2($graph, @$edges);
    my @path = _orderedpath($sg);

    my $pathid = join(' ', @path);
    if ($paths{$pathid}) {
#         print "Dup path: $pathid\n";
        return;
    }

    $paths{$pathid} = 1;

    print "@path\n";
    return 1;
}


################################################################################



sub graphviz {
    my ($graph, $file) = @_;

    my $fh;
    if ($file) {
        open($fh, ">$file") or
            warn("Cannot write to: ", $file, " ($!)");
    } else {
        ($fh, $file) = tempfile(UNLINK=>0);
    }
    return unless $graph && $file;

    my $str = join("\n",
                   "graph {",
                   "\tnode [fontsize=10];",
                   "\tedge [fontsize=8, color=grey];",
                   ,"");
    # For each connection between two nodes, get all of the templates
    foreach my $e ($graph->edges) {
        # Don't ask me why u and v are reversed here. But it's correct.
        my ($v, $u) = @$e;

             $str .= "\t\"" . $u . "\" -- \"" . $v . "\" [" . 
                join(', ', 
                     "];\n");

    }

    $str .= "}\n";
    print $fh $str;
    return $file;
}


sub _subgraph {
    my ($graph, @vertices) = @_;
    my %vertices = map { $_ => 1 } @vertices;

    my @names = map { substr($_,0,1) } @vertices;
    print "vertices @names\n";

    my $subgraph = new Graph::Undirected;
    
    foreach my $e ($graph->edges) {
        my ($u, $v) = @$e;
        $subgraph->add_edge($u,$v) if $vertices{$u} && $vertices{$v};
#         $subgraph->add_edge($v,$u) if $vertices{$u} && $vertices{$v};
    }
    return $subgraph;

}


sub _subgraph2 {
    my ($graph, @edges) = @_;
#     print "edges:@edges:\n";
    my $subgraph = new Graph::Undirected;
    foreach my $e (@edges) {
        my ($u,$v) = split '--', $e;
        $subgraph->add_edge($u,$v);
    }
    return $subgraph;

}


sub _orderedpath {
    my ($graph) = @_;
    # Find the end nodes of the path
    my @ends;
    foreach my $n ($graph->vertices) {
        push(@ends, $n) unless $graph->neighbors($n) > 1;
    }
    # Two possible orderings, sort by vertex ID
    @ends = sort @ends;
    my @path = $graph->SP_Dijkstra(@ends);
    return @path;
}


###############################################################################

1;

__END__
