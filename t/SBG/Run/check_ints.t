#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";
use SBG::Run::check_ints qw/check_ints/;
use SBG::Domain;

# In contact
{
    my $doma = SBG::Domain->new(pdbid => '1tim', descriptor => 'CHAIN A');
    my $domb = SBG::Domain->new(pdbid => '1tim', descriptor => 'CHAIN B');
    my $contacts = check_ints([$doma, $domb], min_dist => 10, N => 5); 
    ok $contacts, 'Residue contacts';
    note $contacts;
}


# Not in contact
{
    my $doma = SBG::Domain->new(pdbid => '1g3n', descriptor => 'CHAIN B');
    my $domb = SBG::Domain->new(pdbid => '1g3n', descriptor => 'CHAIN C');
    my $contacts = check_ints([$doma, $domb], min_dist => 10, N => 5); 
    ok ! $contacts, 'Residue contacts';
    note $contacts;
}

done_testing;
