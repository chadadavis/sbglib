#!/usr/bin/env perl

=head1 NAME

SBG::DB - Simple database utilities

=head1 SYNOPSIS

 use SBG::DB;

Connect to DB (This is the actual DBI handle)

 my $dbh = dbconnect(-host=>"pc-russell12", -db=>"database_name");

=head1 DESCRIPTION

Simply utility for getting, and reusing, a database handle

=head1 SEE ALSO

L<DBI>

=cut

################################################################################

package SBG::DB;
use base qw/Exporter/;
our @EXPORT_OK = qw(dbconnect);

use DBI;
use Carp;

# Singleton
# Dictionary of connections, indexed by host/db name
our %dbh;


################################################################################
=head2 dbconnect

 Title   : dbconnect
 Usage   : dbconnect(host=>"dbhost.organisation.org", db=>"your_database_name");
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
    unless ($o{db}) {
        carp "No db=>'database' given";
        return;
    }
    $o{driver} ||= "mysql";
    $o{host} ||= "localhost";

    # Use cached connection to this database on this host
    our %dbh;
    $dbh{ $o{host} } ||= {};
    my $dbh = $dbh{ $o{host} }{ $o{db} };
    return $dbh if defined($dbh) && ! defined($o{reconnect});

    my $dbistr = "dbi:$o{driver}:dbname=$o{db}";
    $dbistr .= ";host=$o{host}" if $o{host};
    $dbh = DBI->connect($dbistr);
    unless ($dbh) {
        carp "Cannot connect via: $dbistr";
        return;
    }
    $dbh{ $o{host} }{ $o{db} } = $dbh;
    return $dbh;

} # dbconnect




###############################################################################

1;

__END__
