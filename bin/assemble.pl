#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;

use PDL;

use Graph;
use Graph::Writer::Dot;
use Graph::Writer::GraphViz;

use Text::ParseWords;

use Bio::Seq;
use Bio::Network::ProteinNet;
use Bio::Network::Node;
use Bio::Network::Edge;
use Bio::Root::IO;


# Non-CPAN libs

use SBG::DB;
use SBG::Seq;
use SBG::Node;
use SBG::Interaction;
use SBG::CofM;
use SBG::Transform;
use SBG::STAMP; # stampfile

use SBG::Traversal;


################################################################################

# our $OUT = "./tmp";
our $OUT = "./out";

# A L<Bio::Network::ProteinNet> of iaction templates
my $nettemplates = read_templates(shift);

graphviz($nettemplates, "$OUT/templates.dot");

# TODO also need a callback for processing a solution
my $t = new SBG::Traversal($templategraph, \&try_edge);
$t->traverse;


exit;

################################################################################


# TODO belong in another module
# takes any L<Graph> including L<Bio::Network::ProteinNet>
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

} # graphviz




# TODO DES modify to read descriptors
# TODO DES define a common text format for an 'interaction template'
# Returns L<Bio::Network::ProteinNet>
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
} # read_templates





# Callback for attempting to add a new interaction template
# Gets an assembly object as a status object
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
        
        my $srccofm = new SBG::CofM();
        $srccofm->label($src);
        $srccofm->fetch($srcdom);
        $assembly->transform($src, new SBG::Transform);
        $assembly->cofm($src, $srccofm);
        
        # Do the same for the $dest, as it's in the same frame of reference
        my $destcofm = new SBG::CofM();
        $destcofm->label($dest);
        $destcofm->fetch($destdom);
        $assembly->transform($dest, new SBG::Transform);
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
    my $destcofm = new SBG::CofM();
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
        $srccofm = new SBG::CofM($src, $srcdom);
        # Save CofM object for src component in assembly, indexed by $src
        $assembly->cofm($src, $srccofm);
        my $destcofm =  new SBG::CofM($dest, $destdom);
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
    my $destcofm =  new SBG::CofM($dest, $destdom);

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





################################################################################

__END__

