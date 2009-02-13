#!/usr/bin/env perl

=head1 NAME

SBG::DB::cofm - Database interface to cached centres-of-mass of PDB chains


=head1 SYNOPSIS

 use SBG::DB::COFM;


=head1 DESCRIPTION

You do not need to use this module directly. Use L<SBG::Run::cofm> instead.


=head1 SEE ALSO

L<SBG::Domain::CofM> , L<SBG::Run::cofm>

=cut

################################################################################

package SBG::DB::cofm;
use base qw/Exporter/;
our @EXPORT_OK = qw/query/;

use DBI;
use SBG::Config;

################################################################################
=head2 query

 Function: Fetches centre-of-mass and radius of gyration of known PDB chains
 Example : ($x,$y,$z,$rg,$rmax,$file,$descr)=SBG::DB::cofm::query('2nn6','A');
 Returns : XYZ coordinates, radii, path to file, STAMP descriptor
 Args    : pdbid - string (not case sensitive)
           chainid - character (case sensitive)

Looks for cached results in database (defined in B<embl.ini>).

Only appropriate for full-chain queries. 
Otherwise, see L<SBG::Run::cofm>

NB: The DB cache stores uppercase PDB IDs.

=cut
sub query {
    my ($pdbid, $chainid) = @_;
    my $db = SBG::Config::val(qw/cofm db/) || "trans_1_5";

    # Static handle, prepare it only once
    our $dbh;
    our $cofm_sth;

    my $host = SBG::Config::val(qw/cofm host/);
    my $dbistr = "dbi:mysql:dbname=$db";
    $dbistr .= ";host=$host" if $host;
    $dbh = DBI->connect($dbistr);
    $cofm_sth ||= $dbh->prepare("select " .
                                "cofm.Cx, cofm.Cy, cofm.Cz," .
                                "cofm.Rg,cofm.Rmax," .
                                "entity.file," . 
                                "entity.description as descriptor " .
                                "from cofm, entity " .
                                "where " .
                                "bad = 0 and " .
                                "cofm.id_entity=entity.id and " .
# NB don't naively check PQS as the chain ID might be different
#                                 "(entity.acc=? or entity.acc=?)"
                                "(entity.acc=?)"
        );
    unless ($cofm_sth) {
        carp $dbh->errstr;
        return;
    }

    $pdbid = uc $pdbid;

    my $pdbstr = "pdb|$pdbid|$chainid";
    my $pqsstr = "pdb|$pdbid|$chainid";
    # NB don't naively check PQS as the chain ID might be different
#     if (! $cofm_sth->execute($pdbstr, $pqsstr)) {
    if (! $cofm_sth->execute($pdbstr)) {
        carp $cofm_sth->errstr;
        return;
    }

    # ($x, $y, $z, $rg, $rmax, $file, $descriptor);
    return $cofm_sth->fetchrow_hashref();
} # query



################################################################################
1;
