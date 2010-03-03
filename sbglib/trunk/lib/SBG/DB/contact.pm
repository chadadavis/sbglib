#!/usr/bin/env perl

=head1 NAME




=head1 SYNOPSIS




=head1 DESCRIPTION


=head1 SEE ALSO


=cut

################################################################################

package SBG::DB::contact;
use base qw/Exporter/;
our @EXPORT_OK = qw/query/;

use DBI;
use Log::Any qw/$log/;

use SBG::U::DB;



# TODO DES OO
our $database = "trans_3_0";
our $host = "wilee";


################################################################################
=head2 query

 Function: 
 Example : 
 Returns : 
 Args    : 
           

NB contacts are stored in both directions, so we don't need to check 1<->2 and
2<->1 separately.

=cut
sub query {
    my ($entity1, $entity2) = @_;
    our $database;
    our $host;
    my $dbh = SBG::U::DB::connect($database, $host);
    # Static handle, prepare it only once
    our $sth;

    $sth ||= $dbh->prepare("
SELECT
id_entity1,id_entity2,n_res1,n_res2
FROM 
contact
WHERE id_entity1=?
AND id_entity2=?
AND crystal=0
");

    unless ($sth) {
        $log->error($dbh->errstr);
        return;
    }

    if (! $sth->execute($entity1->{id}, $entity2->{id})) {
        $log->error($sth->errstr);
        return;
    }
#     $log->debug('select: ', $sth->rows(), ' rows');

    my @hits;
    while (my $row = $sth->fetchrow_hashref()) {
        # Do any necessary result filtering here
        push @hits, $row;

    }
    return @hits;

} # query



################################################################################
1;
