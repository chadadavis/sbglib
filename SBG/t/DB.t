#!/usr/bin/env perl

use Test::More 'no_plan';
use SBG::DB qw/dbconnect/;

my $host = "pc-russell12";
my $db = "trans_1_5";

my $dbh1 = dbconnect(host=>$host, db=>$db);
ok(defined $dbh1, "Connect to $db on $host");

my $dbh2 = dbconnect(host=>$host, db=>$db);
is($dbh1, $dbh2, "DB handle caching");

my $dbh3 = dbconnect(host=>$host, db=>$db, reconnect=>1);
isnt($dbh2, $dbh3, "Explicit reconnecting");

$dbh1->disconnect();
$dbh2->disconnect();
$dbh3->disconnect();

__END__
