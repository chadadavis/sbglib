#!/usr/bin/env perl

use Test::More 'no_plan';

use Graph::UnionFind;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use Graph::Traversal::GreedyEdges;
use SBG::NetworkIO::csv;

use SBG::U::Log;
$SIG{__DIE__} = \&confess;
my $DEBUG;
$DEBUG = 1;
SBG::U::Log::init(undef, loglevel=>'DEBUG') if $DEBUG;
$File::Temp::KEEP_ALL = $DEBUG;


# Load up a network
my $file = "$Bin/data/simple_network.csv";
my $io = SBG::NetworkIO::csv->new(file=>$file);
my $net = $io->read;

# Set of sets of templates
my $uf = new Graph::UnionFind; 
# In this simple example, each template has a numeric index
my @templ;
foreach my $e ($net->edges) {
    my ($u, $v) = @$e;
    # Names of templates for this edge
    my @templ_ids = sort $net->get_edge_attribute_names($u, $v);
    # Assign a numeric ID to each template (extracted from name), for simplicity
    foreach my $t (@templ_ids) {
        my ($id) = $t =~ /(\d+)/;
        $templ[$id] = $id;
        # Put each template into the union-find data structure. 
        # Initially each is in its own set, i.e. no incompatibilities yet
        $uf->add($id);
    }
}

# For the sake of testing, define some incompatible sets of templates.  Anything
# in the same set is all not compatible.  NB alternative templates for a single
# edge are implicitly mutually incompatible.
# Define some arbitrary incompatibilities by putting templates into same set
$uf->union($templ[1], $templ[2]); 

$uf->union($templ[5], $templ[6]); 

$uf->union($templ[7], $templ[8]);
$uf->union($templ[8], $templ[9]);

$uf->union($templ[1], $templ[5]); 
$uf->union($templ[1], $templ[6]);
$uf->union($templ[2], $templ[5]);
$uf->union($templ[2], $templ[6]);

$uf->union($templ[4], $templ[7]);
$uf->union($templ[4], $templ[8]); 
$uf->union($templ[4], $templ[9]); 
$uf->union($templ[3], $templ[9]); 

# Track answers
my %answers;

my %expected = (
    "A B 1" => 1,
    "A B 2" => 1,
    "A C 3" => 1,
    "A B C 1 3" => 1,
    "A B C 2 3" => 1,
    "A B C 3 5" => 1,
    "A B C 3 6" => 1,
    "A B D 1 4" => 1,
    "A B D 2 4" => 1,
    "B C 5" => 1,
    "B C 6" => 1,
    "B C D 4 5" => 1,
    "B C D 4 6" => 1,
    "B C D 5 7" => 1, 
    "B C D 5 8" => 1,
    "B C D 5 9" => 1,
    "B C D 6 7" => 1,
    "B C D 6 8" => 1,
    "B C D 6 9" => 1,
    "B D 4" => 1,
    "C D 7" => 1,
    "C D 8" => 1,
    "C D 9" => 1,
    );

# Create a traversal
my $trav = Graph::Traversal::GreedyEdges->new(net=>$net, 
                                              assembler=>TestAssembler->new,
    );

$trav->traverse;

is(scalar(keys %answers), scalar(keys %expected), 
   "All covering solutions from traversal");

foreach (sort keys %answers) {
    ok($expected{$_}, "Solution was expected?: $_");
    delete $expected{$_};
}
is(scalar(keys %expected), 0,
   "Missing solutions? " . join(',', keys %expected));

exit;


################################################################################

package TestAssembler;
use Moose;

# with 'SBG::AssemblerI';

# In these callbacks, the default $state will just be a HashRef
sub solution {
    my ($self, $state, $partition) = @_;


    my $net = $state->{'net'};
    my $ccid = $net->connected_component_by_vertex($partition);
    my @nodecover = sort $net->connected_component_by_index($ccid);
    my $templates = $state->{'models'}->{$partition};
    my @ids = sort map {ex_id($_)} @$templates;

    # Append this solution to total answers
    $answers{"@nodecover @ids"} = 1;
} # solution


sub stats {
    my ($self) = @_;
    my $total = scalar keys %answers;
    return 'total', $total;
}


# Just extracts numeric id of interaction template string label
sub ex_id {
    my $name = shift;
    $name =~ /(\d+)/;
    my $id = $1;
}


sub test {
    my ($self, $state, $iaction) = @_;
    if ($state->{'net'}->has_edge($iaction->nodes)) {
        return;
    }
    # Our test index of this template
    my $altid = ex_id("$iaction");
    
    # Make sure that $iaction is compat with src and dest partitions
    # Also that src and dest are compat with one another

    my ($src, $dest) = $iaction->nodes;
    my $src_part = $state->{'uf'}->find($src);
    my $dest_part = $state->{'uf'}->find($dest);
    my $src_comp = $src_part ? $state->{'models'}->{$src_part} : [];
    my $dest_comp = $dest_part ? $state->{'models'}->{$dest_part} : [];


    # What other templates already being used, and are they compat
    # But only in the partition(s) of interest
    foreach my $scomp (@$src_comp) {
        foreach my $dcomp (@$dest_comp) {
            return if $uf->same($dcomp, $scomp);
        }
    }

    foreach my $comp (@$src_comp, @$dest_comp) {
        return if $uf->same($comp, $altid);
    }

    # Add this template to progressive solution (list of templates used)
    my $solution = [ @$src_comp, $altid, @$dest_comp ];
    # There is no complex model, but return a positive score
    return ($solution, 1);
}

