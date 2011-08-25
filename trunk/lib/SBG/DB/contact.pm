#!/usr/bin/env perl

=head1 NAME




=head1 SYNOPSIS




=head1 DESCRIPTION


=head1 SEE ALSO


=cut

package SBG::DB::contact;
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
 Returns : 
 Args    : 
           

NB contacts are stored in both directions, so we do not need to check 1<->2 and
2<->1 separately.

Contacts are clustered by iRMSD <= 5.0 via single-linkage clustering

TODO Define cluster_sl_irmsd_5_0_or_same_chains
This is wrong, we want to be using cluster_sl_irmsd_5_0 as the 'or_same_chains' clusters to many things together, just to reduce the number of cluster, but we'd prefer to have more alternatives here ...

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
id_entity1,id_entity2,n_res1,n_res2,
  cluster_sl_irmsd_5_0 as cluster
FROM 
contact
WHERE 
    id_entity1=?
AND id_entity2=?
AND n_res1 > 0
AND n_res2 > 0
AND crystal=0
");

    unless ($sth) {
        $log->error($dbh->errstr);
        return;
    }

    if (!$sth->execute($entity1->{id}, $entity2->{id})) {
        $log->error($sth->errstr);
        return;
    }

    #     $log->debug('select: ', $sth->rows(), ' rows');

    my @hits;
    while (my $row = $sth->fetchrow_hashref()) {

        # Do any necessary result filtering here
        # Link back to original entities
        $row->{entity1} = $entity1;
        $row->{entity2} = $entity2;
        push @hits, $row;
    }
    return @hits;

}    # query

1;
