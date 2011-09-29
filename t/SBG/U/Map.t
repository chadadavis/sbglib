#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Debug;

use Test::More;
use Carp;
use File::Temp qw/tempfile/;

use SBG::U::Map qw/pdb_chain2uniprot_acc chain_case/;

is(pdb_chain2uniprot_acc('3jqo.a'), 'Q46702');


my $chain;
$chain = 'a';
is(chain_case($chain), 'AA', 'chain_case to uc');
$chain = 'AA';
is(chain_case($chain), 'a', 'chain_case to lc');

done_testing;
