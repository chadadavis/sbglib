#!/usr/bin/env perl

=head1 NAME

SBG::DB - DB tools

=head1 SYNOPSIS

 use SBG::DB;
 my $db_handle = SBG::DB::connect("mydb");
 my $db_handle = SBG::DB::connect("mydb", "myhost");


=head1 DESCRIPTION


=head1 SEE ALSO

L<DBI>

=cut

################################################################################

package SBG::DB;
use base qw/Exporter/;
our @EXPORT_OK = qw(connect);

use strict;
use warnings;
use DBI;

# Connection cache (by hostname/dbname)
our %connections;

our $sleep = 10;


################################################################################
=head2 connect

 Function: Returns DB handle, using connection caching, sleeps if overloaded
 Example : my $db_handle = SBG::DB::connect("my_db_name", "my_host_name");
 Returns : Database handle (L<DBI::db>) or undef 
 Args    : Str database name
           Str host name (default "localhost")

Connections are cached. I.e. feel free to call this as often as you like, it
will return the previous connection if you ask for the same database name,
without incurring any overhead.

If the return value is not defined, check L<DBI>C<errstr()>

=cut
sub connect {
    my ($dbname, $host) = @_;
    our $sleep;
    our %connections;
    # This is also OK, if $host is not defined
    my $dbh = $connections{$host}{$dbname};
    return $dbh if $dbh;
    my $dbistr = "dbi:mysql:dbname=$dbname";
    $dbistr .= ";host=$host" if $host;
    $dbh = DBI->connect($dbistr);
    unless ($dbh) {
        while (DBI->errstr =~ /too many connections/i) {
            sleep int(rand*$sleep);            
            # Try again
            $dbh = DBI->connect($dbistr);
        }
        unless ($dbh) {
            # Some other error
            warn ("Could not connect to database:" . DBI->errstr . "\n");
            return;
        }
    }
    return $dbh;
}


################################################################################
1;
__END__


