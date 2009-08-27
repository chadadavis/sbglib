#!/usr/bin/env perl

=head1 NAME

SBG::DB::cofm - Database interface to cached centres-of-mass of PDB chains


=head1 SYNOPSIS

 use SBG::DB::cofm;


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Domain::Sphere> , L<SBG::Run::cofm>

=cut

################################################################################

package SBG::DB::cofm;
use base qw/Exporter/;
our @EXPORT_OK = qw/query/;

use DBI;

use SBG::U::DB;
use SBG::U::Config qw/config/;
use SBG::U::Log qw/log/;


################################################################################
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
    $pdbid = uc $pdbid;
    my $pdbstr = "pdb|$pdbid|$chainid";
    my $db = config()->val(qw/cofm db/) || "trans_1_6";
    my $host = config()->val(qw/cofm host/);
    my $dbh = SBG::U::DB::connect($db, $host);
    # Static handle, prepare it only once
    our $cofm_sth;

    $cofm_sth ||= $dbh->prepare(join(' ',
                                     'select',
                                     'Cx, Cy, Cz, Rg, Rmax, file,',
                                     'description as descriptor',
                                     'from entity',
                                     'where',
                                     'bad=0 and',
                                     'chain=? and',
                                     'description=?',
                                ));

    unless ($cofm_sth) {
        log()->error($dbh->errstr);
        return;
    }

    if (! $cofm_sth->execute($pdbstr, "CHAIN $chainid")) {

        log()->error($cofm_sth->errstr);
        return;
    }
    # (Cx, Cy, Cz, Rg, Rmax, file, descriptor);
    return $cofm_sth->fetchrow_hashref();
} # query



################################################################################
1;
