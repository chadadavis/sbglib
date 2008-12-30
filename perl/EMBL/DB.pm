#!/usr/bin/env perl

=head1 NAME

EMBL::DB - Simple database utilities

=head1 SYNOPSIS

 use EMBL::DB;

Connect to DB (This is the actual DBI handle)

 my $dbh = dbconnect(-host=>"pc-russell12", -db=>"database_name");

=head1 DESCRIPTION

Simply utility for getting, and reusing, a database handle

=head1 SEE ALSO

L<DBI>

=cut

################################################################################

package EMBL::DB;
use EMBL::Root -base, -XXX;

our @EXPORT = qw(dbconnect);

use warnings;
use DBI;
use Carp;


################################################################################
=head2 dbconnect

 Title   : dbconnect
 Usage   : dbconnect(-host=>"dbhost.organisation.org", -db=>"your_database_name");
 Function: 
 Returns : Reference to a L<DBI> handle or B<undef>
 Args    : host String name of the database host, otherwise B<localhost>
           db String name of the database to connect to
           driver L<DBI> driver to use, default "mysql"
           reconnect Bybasses cached connection, returns a fresh connection

Assumes that no username or password are necessary.

When finished, remember to:
 $dbh->disconnect();

Set reconnect=1 when you need to be connected to more than one DB at a time.
This does not invalidate any open handles to any other databases.

=cut
sub dbconnect {
    my %o = @_;
    EMBL::Root::_undash(%o);
    $o{host} ||= $config->val("database", "host") || "localhost";
    $o{db} ||= $config->val("database", "db");
    $o{driver} ||= $config->val("database", "driver") || "mysql";

    # Use cached connection to this database on this host
    our %dbh;
    $dbh{ $o{host} } ||= {};
    my $dbh = $dbh{ $o{host} }{ $o{db} };
    if ($dbh && ! $o{reconnect}) { return $dbh; }

    $dbh = DBI->connect("dbi:$o{driver}:dbname=$o{db};host=$o{host}");
    if ($dbh) {
        $dbh{ $o{host} }{ $o{db} } = $dbh;
    } else {
        carp "Cannot connect to DB '$o{db}' on host '$o{host}'";
    }
    return $dbh;

} # dbconnect




###############################################################################

1;

__END__
