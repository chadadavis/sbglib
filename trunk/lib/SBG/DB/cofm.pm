#!/usr/bin/env perl

=head1 NAME

SBG::DB::cofm - Database interface to cached centres-of-mass of PDB chains


=head1 SYNOPSIS

 use SBG::DB::cofm;


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Domain::Sphere> , L<SBG::Run::cofm>

=cut

package SBG::DB::cofm;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT_OK = qw/query/;

use DBI;
use Log::Any qw/$log/;

use SBG::U::Map qw/chain_case/;

# TODO DES OO
my $DATABASE = "trans_3_0";


=head2 query

 Function: Fetches centre-of-mass and radius of gyration of whole PDB chains
 Example : my $hash=SBG::DB::cofm::query('2nn6','A');
 Returns : XYZ of CofM, ATOM lines, radii, PDB file, STAMP descriptor
 Args    : pdbid - string (not case sensitive)
           chainid - character (case sensitive)

Only appropriate for full-chain queries. 
Otherwise, see L<SBG::Run::cofm>

The resulting hashref contains keys: 

 Cx, Cy, Cz, Rg, Rmax, description, file, descriptor

NB: The DB cache stores uppercase PDB IDs.

Checks for PDB chain IDs, but not PQS chain IDs.  It is not feasible to naively
check PQS as the chain ID might differ from the PDB.

=cut

sub query {
    my ($pdbid, $chainid) = @_;

    $chainid = chain_case($chainid);
    my $dsn = SBG::U::DB::dsn(database=>$DATABASE);
    my $dbh = SBG::U::DB::connect($dsn);

    # Static handle, prepare it only once
    my $cofm_sth = $dbh->prepare_cached("
select
Cx, Cy, Cz, Rg, Rmax
from 
entity
where
bad=0 and
type='chain'and
idcode=? and
chain=?
");

    unless ($cofm_sth) {
        $log->error($dbh->errstr);
        return;
    }

    if (!$cofm_sth->execute($pdbid, $chainid)) {
        $log->error($cofm_sth->errstr);
        return;
    }

    # (Cx, Cy, Cz, Rg, Rmax);
    my $res = $cofm_sth->fetchrow_hashref();
    $cofm_sth->finish;
    return $res;
}    # query

1;
