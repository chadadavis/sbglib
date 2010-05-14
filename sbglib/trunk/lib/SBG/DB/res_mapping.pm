#!/usr/bin/env perl

=head1 NAME




=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 SEE ALSO



=cut



package SBG::DB::res_mapping;
use base qw/Exporter/;
our @EXPORT_OK = qw/query/;

use DBI;
use Log::Any qw/$log/;

use SBG::U::DB;


# TODO DES OO
our $database = "trans_3_0";
our $host;


=head2 query

 Function: 
 Example : 
 Returns : L<SBG::DomainI>
 Args    : 
    
TODO BUG check for exactly two result rows
       
=cut
sub query {
    my ($pdbid, $chainid, $start, $end) = @_;
    our $database;
    our $host;

    $pdbid = uc $pdbid;
    my $dbh = SBG::U::DB::connect($database, $host);
    # Static handle, prepare it only once
    our $sth;

    $sth ||= $dbh->prepare("
SELECT
resseq, idcode
FROM 
res_mapping
WHERE idcode=?
AND chain=?
AND pdbseq=?
");

    unless ($sth) {
        $log->error($dbh->errstr);
        return;
    }

    if (! $sth->execute($pdbid, $chainid, $start)) {
        $log->error($sth->errstr);
        return;
    }
    log->trace('select start: ', $sth->rows() , ' rows');
    my $dstart = $sth->fetchrow_hashref();

    if (! $sth->execute($pdbid, $chainid, $end)) {
        $log->error($sth->errstr);
        return;
    }
    log->trace('select end: ', $sth->rows() , ' rows');
    my $dend = $sth->fetchrow_hashref();

    return $dstart, $dend;

} # query




1;
