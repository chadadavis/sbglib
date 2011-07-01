#!/usr/bin/env perl
use Modern::Perl;
use Moose::Autobox;
use Algorithm::Cluster qw/treecluster/;

use Algorithm::DistanceMatrix;
use SBG::Superposition::Cache qw/superposition/;
use SBG::DomainIO::stamp;


my $dom_file = shift or die "Gimme a STAMP DOM file\n";

my $io = SBG::DomainIO::stamp->new(file=>$dom_file);
my @doms = $io->read_all;

# Provide a call-back function to measure the distance
my $m = Algorithm::DistanceMatrix->new(metric=>\&mydistance,objects=>\@doms);
my $distmat = $m->distancematrix;

# method=>
# s: pairwise single-linkage clustering
# m: pairwise maximum- (or complete-) linkage clustering
# a: pairwise average-linkage clustering
my $tree = treecluster(data=>$distmat, method=>'a');

# Clustering using a predifined number of clusters
my $cuts = 5; 
my $cut = $tree->cut($cuts);
say "cut into $cuts clusters";
# These are the indexes of your structures
say join ' ', 0..$#doms;
# These are the corresponding cluster IDs for each structure
say "@$cut";


# Clustering using a distance threshold
my $thresh = shift;
$thresh //= 3.5;

# This is the XS (compiled C code) API
my $clusters = $tree->cutthresh($thresh);
say "XS for inter-cluster distance <= $thresh";
say join ' ', 0..$#doms;
say "@$clusters";

# A Pure Perl implementaion of the same thing (verification)
my @clusterids = cutthresh($tree, $thresh);
say "Pure Perl for inter-cluster distance <= $thresh";
say join ' ', 0..$#doms;
say "@clusterids";

exit;
###############################################################################


# We need a distance measure, not a similarity measure
# RMSD would work, but Sc is more reliable, but it's a similarity measure
# It's within [0:10], though, so we'll do 10-Sc as the distance measure
sub mydistance {
    my ($dom1, $dom2) = @_;
    # This is an SBG::Superposition object
    my $superposition = superposition($dom1, $dom2);
    defined($superposition) or return 'Inf';
    # Make sure that the hit covers 75% of the length of the query
    $superposition->coverage > 75 or return 'Inf';
    # The rest of the scores (e.g. 'RMS') are: $superposition->scores->keys
    return 10 - $superposition->scores->at('Sc');
}


# Quick Pure Perl implementation of the clustering by threshold algorithm
# Takes the agglomerative clustering tree from treecluster()
# $thresh is the inter-cluster distance maximum
sub cutthresh {
    my ($tree, $thresh) = @_;   
    my @nodecluster;
    my @leafcluster;
    # Binary tree: number of internal nodes is 1 less than # of leafs
    # Last node is the root, walking down the tree
    my $icluster = 0;
    # Root node belongs to cluster 0
    $nodecluster[@doms-2] = $icluster++;
    for (my $i = @doms-2; $i >= 0; $i--) {        
        my $node = $tree->get($i);
        say sprintf "%3d %3d %.3f", $i,$nodecluster[$i], $node->distance;
        my $left = $node->left;
        # Nodes are numbered -1,-2,... Leafs are numbered 0,1,2,...
        my $leftref = $left < 0 ? \$nodecluster[-$left-1] : \$leafcluster[$left];
        my $assigncluster = $nodecluster[$i];
        # Left is always the same as the parent node's cluster
        $$leftref = $assigncluster;
        say sprintf "\tleft  %3d %3d", $left, $$leftref;
        my $right = $node->right;
        # Put right into a new cluster, when thresh not satisfied
        if ($node->distance > $thresh) { $assigncluster = $icluster++ }
        my $rightref = $right < 0 ? \$nodecluster[-$right-1] : \$leafcluster[$right];
        $$rightref = $assigncluster;
        say sprintf "\tright %3d %3d", $right, $$rightref;
    }
    return @leafcluster;
}

