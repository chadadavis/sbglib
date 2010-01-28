#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 'no_plan';
use SBG::U::Test 'float_is';

use Data::Dumper;
use Data::Dump qw/dump/;
use Carp;
$SIG{__DIE__} = \&confess;

use FindBin qw/$Bin/;
use SBG::U::Log qw/log/;

use Moose::Autobox;

use SBG::Complex;
use SBG::Domain;
use SBG::Domain::Sphere;
use SBG::Run::cofm qw/cofm/;

use SBG::DomainIO::stamp;
use SBG::DomainIO::pdb;
use SBG::U::List qw/flatten/;
use SBG::Run::rasmol;

my $DEBUG;
# $DEBUG = 1;
log()->init('TRACE') if $DEBUG;
$File::Temp::KEEP_ALL = $DEBUG;


# Create Domains to use as templates
# One hexameric ring of 2br2: CHAINS ADCFEB 
# (only unique interfaces: A/B and A/D) (B/D homologs, A/C homologs, etc)

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
my $bdom = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN B');
my $adom = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN A');
my $ddom = new SBG::Domain(pdbid=>'2br2', descriptor=>'CHAIN D');

# Represent as Sphere Domains, having center of mass and radius of gyration
my $bsphere = cofm($bdom);
my $asphere = cofm($adom);
my $dsphere = cofm($ddom);


# Connect Domains to their query component, via a Model
my $mrrp43b = new SBG::Model(query=>'RRP43', subject=>$bsphere);
my $mrrp46a = new SBG::Model(query=>'RRP46', subject=>$asphere);

# RRP45 is modelled on chain B in some interaction, on chain D in others
my $mrrp45d = new SBG::Model(query=>'RRP45', subject=>$dsphere);

my $mrrp45b = new SBG::Model(query=>'RRP45', subject=>$bsphere);
my $mrrp41a = new SBG::Model(query=>'RRP41', subject=>$asphere);

my $mrrp42d = new SBG::Model(query=>'RRP42', subject=>$dsphere);

my $mrrp42b = new SBG::Model(query=>'RRP42', subject=>$bsphere);

my $mmtr3a = new SBG::Model(query=>'MTR3', subject=>$asphere);
my $mrrp43d = new SBG::Model(query=>'RRP43', subject=>$dsphere);

my $complex;
my $iaction;

# Test adding individual models, without Interactions
$complex = new SBG::Complex;
$complex->add_model($mrrp43b);
$complex->add_model($mrrp46a);
# Test retrieval
is($mrrp43b, $complex->get('RRP43'), "Added $mrrp43b to complex");
is($mrrp46a, $complex->get('RRP46'), "Added $mrrp46a to complex");
is($complex->count, 2, "Complex stores SBG::Model's");


# Create an Interaction object from Model objects
$complex = new SBG::Complex;
$iaction = new SBG::Interaction;
$iaction->set('RRP43', $mrrp43b);
$iaction->set('RRP46', $mrrp46a);
# Test retrieval
$complex->add_interaction($iaction, @{$iaction->keys});
my $got_iaction = $complex->interactions->values->head;
is_deeply($got_iaction, $iaction, "add_interaction: $iaction");
rasmol($complex->domains) if $DEBUG;


# First check overlap independently
# should overlap a little with A, should not overlap B
my $res = $complex->check_clash($dsphere);
ok($res > 0 && $res < $complex->overlap_thresh,
   "CHAIN D model in contact (but not clash) with complex");


# Now place an interaction that will require a superposition of domains
# Actually, doesn't really require a superposition, since identity transform
$iaction = new SBG::Interaction;
$iaction->set('RRP46', $mrrp46a);
$iaction->set('RRP45', $mrrp45d);
# Use the existing component as frame of reference: RRP46, to orient RRP45
ok($complex->add_interaction($iaction, 'RRP46', 'RRP45'),
   "Add 2nd Interaction");
is($complex->count, 3, "Got 3rd domain from 2nd interaction");
rasmol($complex->domains) if $DEBUG;


# Use Interaction templates requiring a non-identity transformation
$iaction = new SBG::Interaction;
$iaction->set('RRP45', $mrrp45b);
$iaction->set('RRP41', $mrrp41a);
# Anchor on RRP45 
ok($complex->add_interaction($iaction, 'RRP45', 'RRP41'),
   "Add 3rd Interaction");
is($complex->count, 4, "Got 4th domain from 3rd interaction");
rasmol($complex->domains) if $DEBUG;


# Test chaining of transformations (verfies matrix multiplication)
$iaction = new SBG::Interaction;
$iaction->set('RRP41', $mrrp41a);
$iaction->set('RRP42', $mrrp42d);
# Anchor on RRP41
ok($complex->add_interaction($iaction, 'RRP41', 'RRP42'),
   "Add 4th Interaction");
is($complex->count, 5, "Got 5th domain from 4th interaction");
rasmol($complex->domains) if $DEBUG;


# Verify ring closure doesn't create unacceptable clashes
$iaction = new SBG::Interaction;
$iaction->set('RRP42', $mrrp42b);
$iaction->set('MTR3', $mmtr3a);
# Anchor on RRP42
ok($complex->add_interaction($iaction, 'RRP42', 'MTR3'),
   "Add 5th Interaction");
is($complex->count, 6, "Got 6th domain from 5th interaction");
rasmol($complex->domains) if $DEBUG;


# Close cycle
$iaction = new SBG::Interaction;
$iaction->set('MTR3', $mmtr3a);
$iaction->set('RRP43', $mrrp43d);
my $irmsd = $complex->cycle($iaction);
ok($irmsd < 2, "iRMSD for ring closure: $irmsd");


# Load Complex from a PDB, for benchmarking
# 2nn6, exosome from Hs.
my @names =  qw/RRP43 RRP46 RRP45 RRP41 RRP42 MTR3/;
my @chains = qw/    C     D     A     B     E    F/;
my $dict = { map { $names[$_] => $chains[$_] } (0..$#names) };
my $models = $dict->kv->map(sub { _mkmodel(@$_) });
my $true_complex = new SBG::Complex;
$true_complex->add_model($_) for @$models;


sub _mkmodel {
    my ($name, $chain) = @_;
    my $dom = new SBG::Domain(pdbid=>'2nn6', descriptor=>"CHAIN $chain");
    my $sphere = cofm($dom);
    my $model = new SBG::Model(query=>$name, subject=>$sphere);
    return $model;
}


# Test coverage
my @cover = $complex->coverage($true_complex);
my $coverage = @cover / $true_complex->count;
float_is($coverage, 1.00, "coverage: $coverage", 0.01);


# Test merging of complexes
my $complex1 = new SBG::Complex;
# First interaction of first complex
$iaction = new SBG::Interaction;
$iaction->set('RRP43', $mrrp43b);
$iaction->set('RRP46', $mrrp46a);
# Order doesn't matter for the first interaction added
# Generally, the first domain label is the reference domain
$complex1->add_interaction($iaction, @{$iaction->keys});

# Now place an interaction that will require a superposition of domains
# Actually, doesn't really require a superposition, since identity transform
$iaction = new SBG::Interaction;
$iaction->set('RRP46', $mrrp46a);
$iaction->set('RRP45', $mrrp45d);
# Use the existing protein as frame of reference: RRP46 to orient partner RRP45
ok($complex1->add_interaction($iaction, 'RRP46', 'RRP45'),
   "2nd Interaction of 1st Complex");
is($complex1->count, 3, "Got 3rd domain from 2nd interaction");
rasmol($complex1->domains) if $DEBUG;

# Create second complex (later we will merge them on RRP45, which will be based
# on superposing 2br2/B and 2br2/D
my $complex2 = new SBG::Complex;
$iaction = new SBG::Interaction;
$iaction->set('RRP41', $mrrp41a);
$iaction->set('RRP42', $mrrp42d);
$complex2->add_interaction($iaction, 'RRP41', 'RRP42');


$iaction = new SBG::Interaction;
$iaction->set('RRP42', $mrrp42b);
$iaction->set('MTR3', $mmtr3a);
ok($complex2->add_interaction($iaction, 'RRP42', 'MTR3'),
   "2nd Interaction of 2nd Complex");
is($complex2->count, 3, "Got 3rd domain from 2nd interaction");
rasmol($complex2->domains) if $DEBUG;


# Merge
$iaction = new SBG::Interaction;
$iaction->set('RRP45', $mrrp45b);
$iaction->set('RRP41', $mrrp41a);
ok($complex1->merge_interaction($complex2, $iaction),
   "Merging two trimers");
is($complex1->count, 6, "Merged complex is a hexamer");
rasmol($complex1->domains) if $DEBUG;


# Close cycle, implicitly by adding the last interaction, cycle is detected
$iaction = new SBG::Interaction;
$iaction->set('MTR3', $mmtr3a);
$iaction->set('RRP43', $mrrp43d);
my $cycle_score = $complex1->merge_interaction($complex1, $iaction);
ok($cycle_score > 8, 
   "Merging within a complex to close cycle: $cycle_score");


################################################################################

# Test RMSD of crosshairs of (matching) components of complexes
# TODO DES assuming Domain::Sphere implementation

use SBG::DomainIO::cofm;
use SBG::DomainIO::pdbcofm;
my $iocofm;
my $file;
my ($rmsd, $transmat);
my (@mdoms, @tdoms);

$iocofm = new SBG::DomainIO::cofm(tempfile=>1);
$file = $iocofm->file;
@mdoms = map { $complex->get($_)->subject } @names;
@tdoms = map { $true_complex->get($_)->subject } @names;
$iocofm->write(@mdoms, @tdoms);


# Looks like this is commutative too!
# ($transmat, $rmsd) = $complex->rmsd($true_complex);
my ($transmat1, $rmsd1) = $true_complex->rmsd($complex);
$true_complex->transform($transmat1);
rasmol($complex->domains, $true_complex->domains) if $DEBUG;
# Revert
$true_complex->transform($transmat1->inv);

my ($transmat2, $rmsd2) = $complex->rmsd($true_complex);
$complex->transform($transmat2);
rasmol($complex->domains, $true_complex->domains) if $DEBUG;
# Revert
$complex->transform($transmat2->inv);

float_is($rmsd1, $rmsd2, "rmsd() is commutative");


$TODO = "Verify cofm result";
ok(0);

__END__

$iocofm = new SBG::DomainIO::cofm(tempfile=>1);
$file = $iocofm->file;
@mdoms = map { $complex->get($_)->subject } @names;
@tdoms = map { $true_complex->get($_)->subject } @names;
$iocofm->write(@mdoms, @tdoms);




__END__


# Test superposing complexes
my ($avgmat, $rmsd) = $complex->superposition($true_complex);
float_is($rmsd, 1.6, "mean rmsd over components: $rmsd", 0.1);

$complex->transform($avgmat);
rasmol [@{$complex->domains}, @{$true_complex->domains} ] if $DEBUG;





# Test clone()
ok($complex->does('SBG::Role::Clonable'), "consumes Role::Clonable");
my $clone = $complex->clone;
is($clone->count, 6, "Complex->clone");
$TODO = "Verify clone depth, using refaddr on HashRef attrs";
ok 0;


# Test globularity()
$TODO = "Verify globularity() value";
ok 0;
# $globularity = $complex->globularity;
# ok($globularity, "globularity()");



