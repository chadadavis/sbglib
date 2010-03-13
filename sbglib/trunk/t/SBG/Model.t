#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';
use Data::Dumper;
use Data::Dump qw/dump/;

use SBG::Model;
use SBG::Node;
use SBG::Seq;
use SBG::Domain;
use Moose::Autobox;


# RRP45 and RRP41
my @accnos = qw/Q86Y41 Q9NPD3/;
# Bio::Seq objects
my @seqs = map { new SBG::Seq(-display_id=>$_) } @accnos;
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


# stringify
is("$models[0]", "Q86Y41(2nn6A)", 'stringify');

is("$models[1]", "Q9NPD3(2nn6B)", 'stringify');

