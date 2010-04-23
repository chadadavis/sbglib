#!/usr/bin/env perl

=head1 NAME




=head1 SYNOPSIS




=head1 DESCRIPTION


=head1 SEE ALSO


=cut



package SBG::DB::irmsd;
use base qw/Exporter/;
our @EXPORT_OK = qw/query/;

use DBI;
use List::Util qw/min/;
use Log::Any qw/$log/;

use SBG::U::DB;


# TODO DES OO
our $database = "trans_3_0";
our $host;



=head2 query

 Function: 
 Example : 
 Returns : 
 Args    : 
           

=cut
sub query {
    my ($contact1, $contact2) = @_;
    our $database;
    our $host;
    my $dbh = SBG::U::DB::connect($database, $host);
    # Static handle, prepare it only once
    our $sth;

    my ($a1, $b1, $a2, $b2) = _order($contact1, $contact2);

    $sth ||= $dbh->prepare("
SELECT
*
FROM 
irmsd_reordered
WHERE (a1=? AND b1=? AND a2=? AND b2=?)
");
    unless ($sth) {
        $log->error($dbh->errstr);
        return;
    }

    if (! $sth->execute($a1, $b1, $a2, $b2,)) {
        $log->error($sth->errstr);
        return;
    }

    my $row = $sth->fetchrow_hashref() or return;
    return $row->{irmsd};

} # query


sub _order {
    my ($contact1, $contact2) = @_;

    my $a1 = $contact1->{id_entity1};
    my $b1 = $contact1->{id_entity2};
    my $a2 = $contact2->{id_entity1};
    my $b2 = $contact2->{id_entity2};

    # Sort uniquely:
    my %partner = ( $a1 => $b1, $b1 => $a1, $a2 => $b2, $b2 => $a2);
    my %homolog = ( $a1 => $a2, $a2 => $a1, $b2 => $b1, $b1 => $b2);
    $a1 = min($a1,$a2,$b1,$b2);
    $b1 = $partner{$a1};
    $a2 = $homolog{$a1};
    $b2 = $homolog{$b1};
    return ($a1, $b1, $a2, $b2);
}



1;
