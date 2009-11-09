#!/usr/bin/env perl

=head1 NAME




=head1 SYNOPSIS




=head1 DESCRIPTION


=head1 SEE ALSO



=cut

################################################################################

package SBG::DB::entity;
use base qw/Exporter/;
our @EXPORT_OK = qw/query id2dom/;

use PDL::Core qw/pdl zeroes/;

use DBI;
use Data::Dump qw/dump/;
use SBG::U::DB;
use SBG::U::Log qw/log/;
use SBG::U::List qw/interval_overlap/;
use SBG::Domain;
use SBG::Domain::Sphere;


# TODO DES OO
our $database = "trans_3_0";
our $host = "wilee";


# Query, given a Blast Hit object
sub query_hit {
    my ($hit, %ops) = @_;
    my ($pdbid,$chain) = _gi2pdbid($hit->name);
    my ($pdbseq0, $pdbseqn) = $hit->range('hit');
    $ops{'pdbseq'} = [$pdbseq0,$pdbseqn];
    return query($pdbid, $chain, %ops);
}


# Extract PDB ID and chain
sub _gi2pdbid {
    my ($gi) = @_;
    my ($pdbid, $chain) = $gi =~ /pdb\|(.{4})\|(.*)/;
    return unless $pdbid;
    return $pdbid unless $chain && wantarray;
    return $pdbid, $chain;


}


################################################################################
=head2 query

 Function: 
 Example : 
 Returns : 
 Args    : 
           

e.g. (using 1-based sequence coordinates
query('2ATC', 'A', pdbseq=>[1,234]);
or (using IDs from PDB residue counter, not necessarily 1-based)
query('2ATC', 'A', resseq=>[-1,233]);

=cut
sub query {
    my ($pdbid, $chain, %ops) = @_;
    our $database;
    our $host;

    if (defined $ops{'resseq'}) {
        warn "Converting coordinates";
    }
    $ops{'overlap'} = 0.75 unless defined $ops{'overlap'};

    $pdbid = uc $pdbid;
    my $dbh = SBG::U::DB::connect($database, $host);
    # Static handle, prepare it only once
    our $querysth;

    $querysth ||= $dbh->prepare("
SELECT
id, idcode, chain, dom, start, end, len
FROM entity
WHERE 
    bad != 1 
AND Rg != 0
AND (type = 'chain' OR type = 'fragment')
AND source = 'pdb'
AND idcode = ?
AND chain = ?
");

    unless ($querysth) {
        log()->error($dbh->errstr);
        return;
    }

    if (! $querysth->execute($pdbid, $chain)) {
        log()->error($querysth->errstr);
        return;
    }

    # Check sequence overlap
    my @hits;
    my ($start, $end) = @{$ops{'pdbseq'}};
    while (my $row = $querysth->fetchrow_hashref()) {
        # Save all, if no coordinates given as restraints
        unless ($ops{'pdbseq'}) {
            push @hits, $row;
            next;
        }
        # Skip unless 75% of DB entity is covered by Blast hit
        my $overlap = interval_overlap(
            $row->{'start'},$row->{'end'},
            $start, $end,
            );

        next unless $overlap >= $ops{'overlap'};
        push @hits, $row;
    }
#     log->trace('rows: ', scalar(@hits));
    return @hits;

} # query


################################################################################
=head2 id2dom

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub id2dom {
    my ($id) = @_;
    our $database;
    our $host;
    my $dbh = SBG::U::DB::connect($database, $host);
    # Static handle, prepare it only once
    our $id2domsth;
    $id2domsth ||= $dbh->prepare("
SELECT 
idcode,dom,id,Cx,Cy,Cz,Rg,Rmax
FROM entity
WHERE 
    bad != 1
AND Rg != 0
AND id = ?
");

    unless ($id2domsth) {
        log()->error($dbh->errstr);
        return;
    }
    if (! $id2domsth->execute($id)) {
        log()->error($id2domsth->errstr);
        return;
    }

    my $row = $id2domsth->fetchrow_hashref;
    unless (defined $row) {
        log()->warn("No entity $id found");
        return;
    }

    # Append 1 for homogenous coordinates
    my $center = pdl($row->{Cx}, $row->{Cy}, $row->{Cz}, 1);

    my $dom = SBG::Domain::Sphere->new(
        pdbid=>$row->{'idcode'},
        descriptor=>$row->{'dom'},
        entity=>$row->{'id'},
        center=>$center,
        radius=>$row->{'Rg'},
#         length=>$row->{'nres'}, # Not in DB
        );

    return $dom;

} # id2dom


################################################################################
1;
