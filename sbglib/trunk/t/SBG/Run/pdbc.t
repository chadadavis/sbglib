#!/usr/bin/env perl

use Test::More 'no_plan';



use SBG::Run::pdbc qw/pdbc/;
use SBG::Domain;
use Moose::Autobox;

my $pdbid = '2nn6';
my $fields = pdbc($pdbid);

is($fields->{'header'}, 'HYDROLASE/TRANSFERASE', "pdbc 'header' field");
is($fields->{chain}->keys->length, 9, "pdbc 9 chains in $pdbid");

my $chains = 'GH';
my $subset = pdbc($pdbid . $chains);
is($subset->{chain}->keys->length, 2, "pdbc chains subset $chains");

$pdbid = '1g3n';
$fields = pdbc($pdbid);
is($fields->{chain}->keys->length, 6, "pdbc 6 chains in $pdbid");


# Structure with more than 62 chains
$pdbid = '3hfa';
$fields = pdbc($pdbid);
$TODO = "Fix processing of structures with > 62 chains";
is($fields->{chain}->keys->length, 83, "pdbc 83 chains (> 62) in $pdbid");

