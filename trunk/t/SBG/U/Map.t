#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Debug;

use Test::More;
use Carp;
use File::Temp qw/tempfile/;

use SBG::U::Map qw/pdb_chain2uniprot_acc chain_case gi2pdbid/;

is(pdb_chain2uniprot_acc('3jqo.a'), 'Q46702');


my $chain;
$chain = 'a';
is(chain_case($chain), 'AA', 'chain_case to uc');
$chain = 'AA';
is(chain_case($chain), 'a', 'chain_case to lc');

{
# Convert upper to lower case chain names:
my $pdbgi     = 'pdb|1g3n|BB pdb|1tim|AA';
my @res       = gi2pdbid($pdbgi);
my @gi_expect = ([qw/1g3n b/], [qw/1tim a/]);
is_deeply(\@res, \@gi_expect,
    "gi2pdbid(): Blast double uppercase chain to lowercase");
}

{
# Lowercase retained?
my $pdbgi     = 'pdb|1g3n|0';
my @res       = gi2pdbid($pdbgi);
my @gi_expect = ([qw/1g3n 0/]);
is_deeply(\@res, \@gi_expect, "gi2pdbid(): CHAIN 0 respected");
}

done_testing;
