#!/usr/bin/env perl

use Test::More 'no_plan';
use Moose::Autobox;

use FindBin qw/$Bin/;
use lib "$Bin/../../lib/";
use SBG::Model;
use SBG::Node;
use SBG::Seq;
use SBG::Domain;

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

# stringify
is("$models[0]", "Q86Y41(2nn6A)", 'stringify');

is("$models[1]", "Q9NPD3(2nn6B)", 'stringify');

$TODO = 'Distinguish "subject" from "structure"';
ok(0);

