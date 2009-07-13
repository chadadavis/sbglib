#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Data::Dumper;
use Data::Dump qw/dump/;

use SBG::Interaction;
use SBG::Model;
use SBG::Node;
use SBG::Seq;
use SBG::Domain;


# Setup a Network Interaction object
# RRP45 and RRP41
my @accnos = qw/Q86Y41 Q9NPD3/;
# Bio::Seq objects
my @seqs = map { new SBG::Seq(-accession_number=>$_) } @accnos;
# Bio::Network::Node objects
my @nodes = map { new SBG::Node($seqs[$_]) } (0..$#seqs);
# The corresponding template domains
my @templates = map { 
    new SBG::Domain(pdbid=>'2nn6',descriptor=>"CHAIN $_") 
} qw/A B/;
# Store each in a Model container
my @models = map { 
    new SBG::Model(query=>$nodes[$_], subject=>$templates[$_]) 
} (0..$#seqs);
# An interaction (model) connects two nodes, each has a model
# my $interaction = new SBG::Interaction(-nodes=>[@nodes]);
my $interaction = new SBG::Interaction(-nodes=>[@nodes]);
# Note which nodes have which models, for this interaction
$interaction->set($nodes[$_],$models[$_]) for (0..$#seqs);

# Sanity test
my @gotmodels = map { $interaction->get($_) } @nodes;

is($gotmodels[$_], $models[$_], "Storing models in Interaction by Node") 
    for (0..$#nodes);


