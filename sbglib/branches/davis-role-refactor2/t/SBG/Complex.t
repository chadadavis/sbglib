#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::U::Test 'float_is';

use Data::Dumper;
use Data::Dump qw/dump/;
use Carp;
$SIG{__DIE__} = \&confess;

use FindBin qw/$Bin/;
use SBG::U::Log qw/log/;
log()->init('TRACE');

use Moose::Autobox;

use SBG::Complex;
use SBG::Domain;
use SBG::Domain::Sphere;
use SBG::Run::cofm qw/cofm/;


# Create Domains to use as templates
# One hexameric ring of 2br2: CHAINS ADCFEB 
# (only unique interfaces: A/B and A/D)

# One hexameric ring of 2nn6: CHAINS EFCDAB 
# E RRP42
# F MTR3
# C RRP43
# D RRP46
# A RRP45
# B RRP41
# And: 
# I CSL4  (sits on FCD)
# G RRP40 (sits on DA)
# H RRP4  (sits on BEF)


# Create template Domains (generic, no coordinates)
my $b = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN B');
my $a = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN A');
my $d = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN D');

# Represent as Sphere Domains, having center of mass and radius of gyration
my $bsphere = cofm($b);
my $asphere = cofm($a);
my $dsphere = cofm($d);


# Connect Domains to their query component, via a Model
my $bmodel = new SBG::Model(query=>'RRP43', subject=>$bsphere);
my $amodel = new SBG::Model(query=>'RRP46', subject=>$asphere);
my $dmodel = new SBG::Model(query=>'RRP45', subject=>$dsphere);

my $complex = new SBG::Complex;
$complex->add_model($bmodel);
$complex->add_model($amodel);


# Test retrieval
is($bmodel, $complex->get('RRP43'), "Added $bmodel to complex");
is($amodel, $complex->get('RRP46'), "Added $dmodel to complex");
is($complex->count, 2, "Complex stores SBG::Model's");


# Test clone()
ok($complex->does('SBG::Role::Clonable'), "consumes Role::Clonable");
my $clone = $complex->clone;
is($clone->count, 2, "Complex->clone");


# Create an Interaction object from Model objects
$iaction = new SBG::Interaction;
$iaction->set('RRP43', $bmodel);
$iaction->set('RRP46', $amodel);
$complex = new SBG::Complex;


# Test retrieval
$complex->add_interaction($iaction, @{$iaction->keys});
$got_iaction = $complex->interactions->values->head;
is_deeply($got_iaction, $iaction, "add_interaction: $iaction");


# First check overlap independently
# D should overlap a little with A, should not overlap B
my $res = $complex->check_clash($dsphere);
ok($res > 0 && $res < $complex->overlap_thresh,
   "CHAIN D model in contact (no clash) with complex");


# Now place an interaction that will require a superposition of domains
# Actually, doesn't really require a superposition, since identity
$iaction = new SBG::Interaction;
$iaction->set('RRP46', $amodel);
$iaction->set('RRP45', $dmodel);
# Use the existing component as frame of reference: RRP46, to orient RRP45
$complex->add_interaction($iaction, 'RRP46', 'RRP45');

is($complex->interactions->keys->length, 2, "2nd interaction");
is($complex->count, 3, "3rd domain from 2nd interaction");



$TODO = "Use Interaction templates requiring a transformation";
ok 0;


$TODO = 'Load Complex from a PDB, for benchmarking';
# Want to be able to specify subset of doms
# Can just define the dom objects, add to complex (as Models)
# Here the query and subject of the models will be the same
ok 0;


$TODO = 'Test Complex::coverage()';
ok 0;


$TODO = 'Test Complex::rmsd()';
ok 0;




