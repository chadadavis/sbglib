#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../../../lib/";

use Test::More;
use Carp;
use Scalar::Util qw/refaddr/;

use SBG::Debug qw(debug);
use SBG::U::DB qw/connect dsn ping/;

use English qw(-no_match_vars);
use DBI;

unless (ping()) {
    ok warn "skip : no database\n";
    exit;
}

{
    my $dsn = dsn();
    like $dsn, qr/^dbi:mysql:/, 'Default DSN';
}

{
    my $dbh = connect();
    ok defined $dbh, 'connect() with defaults from ~/.my.cnf'
}


# Test connection caching
SKIP: {
    skip "No connection caching when in debug() mode", 1 if debug();

    my $dsn = dsn(database=>'trans_3_0', host=>'russelllab.org');
    # Same DSN should fetch same DB handle
    my $dbh1 = connect($dsn);
    my $dbh2 = connect($dsn);
    is(refaddr($dbh1), refaddr($dbh2), "connect() caching");
}


# Test invalid host exception
{
    eval {
        my $dbh = connect(dsn(host=>'dfasdijgfigihfddfdf'));
    };
    ok $@, "Invalid host should throw exception";
}

# Invalid database exception
{
    my $dsn = dsn(host => 'russelllab.org', database => 'dkajgkucgljngaga');
    eval {
        my $dbh = connect($dsn);
    };
    ok $@, "Invalid database should throw exception";
}

# Test timeout exception
{
    my $dsn = dsn(mysql_connect_timeout => 1, host => 'google.com');
    eval {
        my $dbh = connect($dsn);
    };
    ok $@, "Connection timeout should throw exception";
}

# Test max connections and retry
# In order to test this, you need to reduce MySQL max connections to e.g. N=10
# echo "SET GLOBAL max_connections = 10;" | mysql
# And run with SBGDEBUG enabled (to disable caching)
# And with TEST_MAX_CONNECTIONS enabled
# Once the connections are maxed out, you will need to kill one on the server.
# This will allow you to see when it picks back up again.

SKIP: {
    skip "Read code docs to test max_connections", 1 
        unless $ENV{TEST_MAX_CONNECTIONS};
    my @connections;
    my $n = 20;
    for (1..$n) {
        # Here there is no connection caching
        eval {
            $connections[$_] = DBI->connect(
                'dbi:mysql:trans_3_0;host=russelllab.org',
                'anonymous', undef, {RaiseError=>1});
        };
        if ($EVAL_ERROR && ($DBI::err == 1203 || $DBI::err == 1040) ) {
            diag "OK, max_connections reached. Now, you go kill one of them, so I can continue ...";
            last;
        }
    }
    # Now use our function to try to connect anew
    my $conn_max = connect();
    ok $conn_max, 'Retry when max_connections';
}

done_testing();
