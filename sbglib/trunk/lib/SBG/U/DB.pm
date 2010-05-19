#!/usr/bin/env perl

=head1 NAME

SBG::U::DB - DB tools

=head1 SYNOPSIS

 use SBG::U::DB;
 my $db_handle = SBG::U::DB::connect("mydb");
 my $db_handle = SBG::U::DB::connect("mydb", "myhost");


=head1 DESCRIPTION


=head1 SEE ALSO

L<DBI>

=cut



package SBG::U::DB;
use base qw/Exporter/;
our @EXPORT_OK = qw(connect chain_case);

use strict;
use warnings;
use DBI;

# Simply for documenting the dependency
#use DBD::mysql;

# Connection cache (by hostname/dbname)
our %connections;

our $sleep = 10;

our $default_db = 'trans_3_0';


=head2 connect

 Function: Returns DB handle, using connection caching, sleeps if overloaded
 Example : my $db_handle = SBG::U::DB::connect("my_db_name", "my_host_name");
 Returns : Database handle (L<DBI::db>) or undef 
 Args    : Str database name
           Str host name (default "localhost")

Connections are cached. I.e. feel free to call this as often as you like, it
will return the previous connection if you ask for the same database name,
without incurring any overhead.

If the return value is not defined, check L<DBI>C<errstr()>

Host name is optional. If not given, uses the same rules as mysql to determine
which database host to connect to. Specified in ~/.my.cnf otherwise B<localhost>

TODO this can be replaced by L<DBI::connect_cached>

=cut
sub connect {
    my ($dbname, $host, $timeout, $user) = @_;
    our $sleep;
    our %connections;
    $dbname ||= $default_db;
    $host ||= _default_host();
    # This is also OK, if $host is not defined
    my $dbh = $connections{$host}{$dbname};
    return $dbh if $dbh;

    my $dbistr = "dbi:mysql:dbname=$dbname";
    $dbistr .= ";host=$host" if $host;
    $timeout ||= defined($DB::sub) ? 100: 5;
    $user ||= '%';
    
    $dbh = eval { 
        local $SIG{ALRM} = sub { 
            die "DBI::connect timed out: $dbname@$host\n"; 
        };
        alarm($timeout);
        my $success = DBI->connect($dbistr, $user) or die;
        return $success;
    };
    alarm(0);

    unless (defined $dbh) {
        while (defined($DBI::errstr) && 
               $DBI::errstr =~ /too many connections/i) {
            sleep int(rand*$sleep);            
            # Try again
            $dbh = DBI->connect($dbistr, $user);
        }
        unless ($dbh) {
            # Some other error
            # warn ("Could not connect to database:" . $DBI::errstr . "\n");
            return;
        }
    }
    # Update cache
    $connections{$host}{$dbname} = $dbh;
    return $dbh;
}


use Config::IniFiles;
sub _default_host {
    our $host;
    return $host if $host;
    my $cnf = "$ENV{HOME}/.my.cnf";
    return '' unless -r $cnf;
    my $cfg = Config::IniFiles->new(-file=>$cnf);
    $host = $cfg->val('client', 'host') || '';
    return $host;
}


use Socket;
# http://www.macosxhints.com/dlfiles/is_tcp_port_listening_pl.txt
sub _port_listening {
    my ($host, $port, $timeout) = @_;
    $port ||= 3306;
    $timeout ||= 5;

    my $proto = getprotobyname('tcp');
    my $iaddr = inet_aton($host);
    my $paddr = sockaddr_in($port, $iaddr);
    my $socket;
    socket($socket, PF_INET, SOCK_STREAM, $proto) or return;

    eval {
        local $SIG{ALRM} = sub { die "SIGALRM\n"; };
        alarm($timeout);
        my $success = CORE::connect($socket, $paddr);
        alarm(0);
        die "$!\n" unless $success;
    };
    close $socket;
    
    return if $@;
    return 1;
}




=head2 chain_case

 Function: Converts between e.g. 'a' and 'AA'
 Example : $chain = chain_case('a'); $chain = chain_case('AA');
 Returns : lowercase converted to double uppercase, or vice versa
 Args    : 

The NCBI Blast standard uses a double uppercase to represent a lower case chain identifier from the PDB. I.e. when a structure has more than 36 chains, the first 26 are named [A-Z] the next 10 are named [0-9], and the next next 26 are named [a-z]. The NCBI Blast is not case-sensitive, so it converts the latter to double uppercase, i.e. 'a' becomes 'AA'.

Given 'a', returns 'AA';

Given 'AA', returns 'a';

Else, returns the identity;

=cut
sub chain_case {
    my ($chainid) = @_;

    # Convert lowercase chain id 'a' to uppercase double 'AA'
    if ($chainid =~ /^([a-z])$/) {
        $chainid = uc $1 . $1;
    } elsif ($chainid =~ /^([A-Z])\1$/) {
        $chainid = lc $1;
    }

    return $chainid;

} # chain_case



1;
__END__


