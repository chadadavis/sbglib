#!/usr/bin/env perl

use strict;
use warnings;
use Test::More 'no_plan';
use Data::Dumper;
use Data::Dump qw/dump/;
use Carp;

use Moose::Autobox;
use List::MoreUtils qw/mesh/;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";

use SBG::U::Log qw/log/;
use SBG::Seq;
use SBG::Node;
use SBG::Domain;
use SBG::Interaction;
use SBG::Network;
use SBG::Complex;
use SBG::CA::Assembler; # qw(linker);
use SBG::Run::cofm qw/cofm/;
use SBG::Run::rasmol;


my $DEBUG;
# $DEBUG= 1;
SBG::U::Log::init(undef, loglevel=>'DEBUG') if $DEBUG;
$SIG{__DIE__} = \&confess if $DEBUG;

# Similar to example in STAMP.t but use at least two chained superpositions
# Do not simply multiply transform twice, rather: chain them

# Based on archael exosome (2br2: one ring: Chains DABEFC )
# 2 unique chains: A (and every 2nd), B (and every 2nd)
# Templates: D-A(and A-D), A-B(and B-A)
# Linker superpositions b<=>d or a<=>e or a<=>a or b<=>b


my $components = [ qw/c1 c2 c3 c4 c5 c6/ ];
my $seqs = $components->map(sub{new SBG::Seq(-display_id=>$_)});
my $seqmap = { mesh @$components, @$seqs };
my $nodes = $seqs->map(sub{new SBG::Node($_)});
my $nodemap = { mesh @$components, @$nodes };
my $doms = [ qw/A B D/ ];
my $dommap = { map {$_ => _mkdom($_)} @$doms };

my $net = new SBG::Network;
$net->add_node($_) for @$nodes;

my $interactions = [
    _mkia($nodemap->{c1}, $dommap->{D}, $nodemap->{c2}, $dommap->{A}),
    _mkia($nodemap->{c2}, $dommap->{A}, $nodemap->{c3}, $dommap->{B}),
    _mkia($nodemap->{c3}, $dommap->{D}, $nodemap->{c4}, $dommap->{A}),
    _mkia($nodemap->{c4}, $dommap->{A}, $nodemap->{c5}, $dommap->{B}),
    _mkia($nodemap->{c5}, $dommap->{D}, $nodemap->{c6}, $dommap->{A}),
    # Could also make an iteration from c6 to c1 to close the ring ...
    ];

# State holder
my $complex = new SBG::Complex(id=>'2br2test');

my $assembler = new SBG::CA::Assembler;


ok($assembler->test($complex, $net, 'c1', 'c2', $interactions->[0]),'Add interaction');
ok($assembler->test($complex, $net, 'c2', 'c3', $interactions->[1]),'Add interaction');
ok($assembler->test($complex, $net, 'c3', 'c4', $interactions->[2]),'Add interaction');
ok($assembler->test($complex, $net, 'c4', 'c5', $interactions->[3]),'Add interaction');
ok($assembler->test($complex, $net, 'c5', 'c6', $interactions->[4]),'Add interaction');

rasmol($complex->domains) if $DEBUG;

my $solutionfile = 
    $assembler->solution($complex, $net, [$net->nodes], $interactions, 0);
ok($solutionfile && -e $solutionfile, 'Checking solution file');
unlink $solutionfile;

my $dup = $assembler->solution($complex, $net, [$net->nodes], $interactions, 0);
# Now try to save the same solution, verify rejection of duplicate
ok(! $dup, 'Duplicate detection');


sub _mkia {
    my ($nodea, $doma, $nodeb, $domb) = @_;
    my $i = new SBG::Interaction;
    $i->set($nodea, new SBG::Model(query=>$nodea, subject=>$doma));
    $i->set($nodeb, new SBG::Model(query=>$nodeb, subject=>$domb));
    $net->add_interaction(-interaction=>$i,
                          -nodes=>[$nodea, $nodeb]);
    return $i;
}

sub _mkdom {
    my ($chain) = @_;
    my $dom = new SBG::Domain(pdbid=>'2br2', descriptor=>"CHAIN $chain");
    my $sphere = cofm($dom);
    return $sphere;
}





