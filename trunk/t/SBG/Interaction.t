#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";
use SBG::Debug;

use Test::More;

use Moose::Autobox;

use SBG::Interaction;
use SBG::Model;
use SBG::Node;
use SBG::Seq;
use SBG::Domain;

# Setup a Network Interaction object
# RRP45 and RRP41
my @accnos = qw/Q86Y41 Q9NPD3/;

# Bio::Seq objects
my @seqs = map { new SBG::Seq(-display_id => $_) } @accnos;

# Bio::Network::Node objects
my @nodes = map { new SBG::Node($seqs[$_]) } (0 .. $#seqs);

# The corresponding template domains
my @templates =
    map { new SBG::Domain(pdbid => '2nn6', descriptor => "CHAIN $_") }
    qw/A B/;

# Store each in a Model container
my @models =
    map { new SBG::Model(query => $nodes[$_], subject => $templates[$_]) }
    (0 .. $#seqs);

# An interaction (model) connects two nodes, each has a model
my $interaction = new SBG::Interaction;

# Note which nodes have which models, for this interaction
$interaction->set($nodes[$_], $models[$_]) for (0 .. $#seqs);

# Stringification (which comes from ->primary_id
my $alt0 = "$models[0]--$models[1]";
my $alt1 = "$models[1]--$models[0]";
ok("$interaction" eq $alt0 || "$interaction" eq $alt1, "stringify");

# Sanity test
my @gotmodels = map { $interaction->get($_) } @nodes;

is($gotmodels[$_], $models[$_], "Storing models in Interaction by Node")
    for (0 .. $#nodes);

$TODO = "Test equality, should be independent of Node endpoints";
ok 0;

done_testing;
