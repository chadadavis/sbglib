#!/usr/bin/env perl

=head1 NAME

SBG::U::DB - DB tools

=head1 SYNOPSIS

 use SBG::U::DB qw(connect dsn)
 my $db_handle = connect(dsn(database=>"mydb"));
 my $db_handle = connect(dsn(database=>"mydb", host=>"myhost"));


=head1 DESCRIPTION

Convenience wrapper for MySQL for people in the SBG group

Does connection caching. Note, this is probably not thread-safe or
fork-safe. For that, you might want to look at L<DBIx::Connector>

To simplify frequent connections, create a C<~/.my.cnf> file with your default
dtabase host. E.g.

 [client]
 host=server.company.com
 user=jake
 database=sales_reports
 password=ilikecake

For documentation, see

 http://dev.mysql.com/doc/refman/5.1/en/option-files.html

Caching is disabled with SBGDEBUG is defined in the environment. See
L<SBG::Debug> .

=head1 SEE ALSO

=over

=item * L<DBI>

=item * L<DBD::mysql>

=back

=cut

package SBG::U::DB;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT_OK = qw(connect dsn ping);

use English qw(-no_match_vars);
use Log::Any qw/$log/;
use DBI;
# Simply for documenting the dependency
use DBD::mysql;
# For testing the port before connecting;
use Net::Ping;
# For reading passwords
use IO::Prompt;

use SBG::Debug qw(debug);

our $DEFAULT_SERVER = 'russelllab.org';
# Upon max_connections, idle time doubles each try, this is the max
# The sum up to this point amounts to about 4.5 hours, before an exception
my  $MAX_WAIT       = 2**16;


=head2 connect

Returns DB handle, using connection caching, sleeps if overloaded

 # Use defaults from my ~/.my.cnf
 my $db_handle = connect();

 my $db_handle = SBG::U::DB::connect(
     dsn(database=>"my_db_name", host=>"my_host_name")
     $my_user_name, #
 );

If the return value is not defined, check L<DBI>C<errstr()>

Enables C<RaiseError> (see L<DBD::mysql> ) unless you explicitly disable it:

 my $dbh = connect(
     dsn(database => 'my_db'),
     $my_user, $my_pass, { RaiseError => 0, },
 );

=cut

sub connect {
    my ($dsn, $user, $password, $dbi_ops) = @_;
    $dsn ||= dsn();
    $dbi_ops ||= {};
    $dbi_ops->{RaiseError} = 1 unless defined $dbi_ops->{RaiseError};

    my $dbh;
    # Seconds to wait when max_connections has been reached, doubled each time
    my $wait = 1;
    do {
        $dbh = eval {
            debug() ? DBI->connect(       $dsn, $user, $password, $dbi_ops) :
                      DBI->connect_cached($dsn, $user, $password, $dbi_ops) ;
        };
        if ($EVAL_ERROR) {
            $log->error(join ':', $DBI::err, $DBI::errstr) if $DBI::err;
            # 1040: max_connections, 1203: max_user_connections
            # http://dev.mysql.com/doc/refman/5.1/en/too-many-connections.ht
            if ($DBI::err == 1203 || $DBI::err == 1040) {
                # Give up, and rethrow the exception
                die $EVAL_ERROR if $wait > $MAX_WAIT;
                $log->warn("max_connections. Sleeping $wait seconds ...");
                sleep $wait;
                $wait *= 2;
            } else {
                # Some other connection failure, not handled here
                die $EVAL_ERROR;
            }
        }
    } while (! $dbh);

    return $dbh;
}


=head2

Check if a MySQL server is listing at the given host

 unless (SBG::U::DB::ping('server.com')) { 
     die "server.com is down";
 }

=cut

sub ping {
    my ($host) = @_;
    my $ping = Net::Ping->new;
    $ping->{port_num} = 3306;
    $host ||= $DEFAULT_SERVER;
    return $ping->ping($host);
}


=head2 

Returns the MySQL connection string with useful default options

 my $dsn = dsn(database=>'mydb', host=>'ourserver.com');

Note, 'database' and 'dbname' are equivalent. 

Other options:

 mysql_connect_timeout

Timeout in seconds for creating the connection (default 10)

 mysql_read_default_file

Config file to use, default C<~/.my.cnf>

 mysql_read_default_group

Group in the INI file to read, no default

See L<DBD::mysql> for more options

=cut

sub dsn {
    my %ops = @_;

    $ops{mysql_connect_timeout} ||= 10;
#     $ops{mysql_read_default_group} ||= 'backup'; # Set before default_file
    $ops{mysql_read_default_file} = '~/.my.cnf';

    my $dsn = 'dbi:mysql:' . join ';', map { "$_=$ops{$_}" } keys %ops;
    $log->debug('DSN ' . $dsn);
    return $dsn;
}


1;
__END__


