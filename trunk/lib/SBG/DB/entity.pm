#!/usr/bin/env perl

=head1 NAME




=head1 SYNOPSIS




=head1 DESCRIPTION


=head1 SEE ALSO



=cut



package SBG::DB::entity;
use base qw/Exporter/;
our @EXPORT_OK = qw/query id2dom/;

use Moose::Autobox;
use PDL::Core qw/pdl zeroes/;
use DBI;
use Data::Dump qw/dump/;
use Log::Any qw/$log/;
use Carp;
use Scalar::Util qw/refaddr/;

use SBG::U::DB qw/chain_case/;
use SBG::U::List qw/interval_overlap/;
use SBG::Domain;
use SBG::Domain::Sphere;
use SBG::Run::PairedBlast qw/gi2pdbid/;

# TODO DES OO
our $database = "trans_3_0";
our $host;


# Query, given a Blast Hit object
sub query_hit {
    my ($hit, %ops) = @_;
    our %hit_cache;
    $ops{cache} = 1 unless defined $ops{cache};

    my ($pdbid_chainid) = gi2pdbid($hit->name);
    my ($pdbid, $chainid) = @$pdbid_chainid;
    return unless $chainid;
    my ($pdbseq0, $pdbseqn) = $hit->range('hit');

#     my $key = $hit->{refaddr};
    my $key = refaddr $hit;
    my $label = $hit->name . " ($pdbseq0-$pdbseqn)";

    if ($ops{cache} && exists $hit_cache{$key}) {
        my $entities = $hit_cache{$key};
#         $log->debug($label, ': ', $entities->length, " entities (cached)");
        $_->{hit} = $hit for @$entities;
        return @$entities;
    }

    $ops{pdbseq} ||= [$pdbseq0,$pdbseqn];
    my $entities = [ query($pdbid, $chainid, %ops) ];

    if ($ops{cache}) { 
        $hit_cache{$key} = $entities;
#         $log->debug($label, ': ', $entities->length, " entities (new)");
    }
    # Save ref to hit in each entity
    $_->{hit} = $hit for @$entities;
    return @$entities;
}


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

    if ($chain =~ /^([a-z])$/) {
        $chain = uc $1 . $1;
    }

    if (defined $ops{resseq}) {
        carp "Converting coordinates not implemented";
        return;
    }
    $ops{overlap} = 0.50 unless defined $ops{overlap};

    $chain = chain_case($chain);
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
    my ($start, $end) = @{$ops{pdbseq}} if defined $ops{pdbseq};
    while (my $row = $querysth->fetchrow_hashref()) {
        $row->{entity} = $row->{id};
        # Save all, if no coordinates given as restraints
        unless ($ops{pdbseq}) {
            push @hits, $row;
            next;
        }

        # How much of structural fragment covered by sequence
        # And how much of sequence covered by structural fragment
        my ($covered_struct, $covered_seq) = 
            interval_overlap($row->{start},$row->{end}, $start, $end);

        if ($covered_struct < $ops{overlap} ||
            $covered_seq < $ops{overlap} ) { 

            $log->debug("covered_struct: $covered_struct");
            $log->debug("covered_seq: $covered_seq");
            next;
        }
        push @hits, $row;
    }
#     $log->debug('rows: ', scalar(@hits));
    return @hits;

} # query



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
        pdbid=>$row->{idcode},
        descriptor=>$row->{dom},
        entity=>$row->{id},
        center=>$center,
        radius=>$row->{Rg},
#         length=>$row->{nres}, # Not in DB
        );

    return $dom;

} # id2dom



1;
