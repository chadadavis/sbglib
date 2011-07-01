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
use Log::Any qw/$log/;
use Carp;
use Scalar::Util qw/refaddr/;

use SBG::U::DB;
use SBG::U::List qw/interval_overlap/;
use SBG::Domain;
use SBG::Domain::Sphere;


# TODO DES OO
our $database = "trans_3_0";
our $host = "wilee.embl.de";


# Query, given a Blast Hit object
sub query_hit {
    my ($hit, %ops) = @_;
    our %hit_cache;
    my $key = refaddr $hit;
    $ops{'cache'} = 1 unless defined $ops{'cache'};
    if ($ops{'cache'} && exists $hit_cache{$key}) {
        return @{$hit_cache{$key}};
    }

    my ($pdbid,$chain) = _gi2pdbid($hit->name);
    my ($pdbseq0, $pdbseqn) = $hit->range('hit');
    $ops{'pdbseq'} ||= [$pdbseq0,$pdbseqn];
    my @entities = query($pdbid, $chain, %ops);
    $_->{'hit'} = $hit for @entities;
    if ($ops{'cache'}) { $hit_cache{$key} = \@entities }
    return @entities;
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
           

using 1-based sequence coordinates:
query('2ATC', 'A', pdbseq=>[1,234]);
using IDs from PDB residue counter
(not necessarily 1-based, not necessarily contiguous)
query('2ATC', 'A', resseq=>[-1,233]);

NB not querying PQS here, just PDB

=cut
sub query {
    my ($pdbid, $chain, %ops) = @_;
    our $database;
    our $host;

    if (defined $ops{'resseq'}) {
        carp "Converting coordinates not implemented";
        return;
    }
    $ops{'overlap'} = 0.50 unless defined $ops{'overlap'};

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
        $log->error($dbh->errstr);
        return;
    }

    if (! $querysth->execute($pdbid, $chain)) {
        $log->error($querysth->errstr);
        return;
    }

    # Check sequence overlap
    my @hits;
    my ($start, $end) = @{$ops{'pdbseq'}};
    while (my $row = $querysth->fetchrow_hashref()) {
        $row->{'entity'} = $row->{'id'};
        # Save all, if no coordinates given as restraints
        unless ($ops{'pdbseq'}) {
            push @hits, $row;
            next;
        }

        # How much of structural fragment covered by sequence
        # And how much of sequence covered by structural fragment
        my ($covered_struct, $covered_seq) = 
            interval_overlap($row->{'start'},$row->{'end'}, $start, $end);
        $log->debug("covered_struct: $covered_struct");
        $log->debug("covered_seq: $covered_seq");
        # NB could also verify that sequence is covered enough
        if ($covered_struct < $ops{'overlap'}) {
            next;
        }
        push @hits, $row;
    }
#     $log->debug('rows: ', scalar(@hits));
    return @hits;

} # query


################################################################################
=head2 id2dom

 Function: 
 Example : 
 Returns : 
 Args    : 

TODO should be done by DBIx::Class or equivalent

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
        $log->error($dbh->errstr);
        return;
    }
    if (! $id2domsth->execute($id)) {
        $log->error($id2domsth->errstr);
        return;
    }

    my $row = $id2domsth->fetchrow_hashref;
    unless (defined $row) {
        $log->warn("No entity $id found");
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
