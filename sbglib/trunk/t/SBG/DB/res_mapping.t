#!/usr/bin/env perl

use Test::More 'no_plan';
use Data::Dumper;

use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";

use SBG::U::DB;
my $dbh = SBG::U::DB::connect();
unless($dbh) {
    diag "Could not connect to database. Skipping database tests\n";
    exit;
}

use SBG::DB::res_mapping;

$, = ' ';

my $prec = 4;


$TODO = 'Test boundary cases';
ok(0);

$TODO = 'Test negatives residue IDs';
ok(0);

$TODO = 'Test ranges, verify ordering';
ok(0);



__END__


