#!/usr/bin/env perl

=head1 NAME



=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::STAMP> , L<Cache::File>

=cut

################################################################################

package SBG::STAMP::Cache::File;
use base qw/Exporter/;

use strict;
use warnings;

our @EXPORT_OK = qw/
do_stamp
sorttrans
stamp
pickframe
superpose
pdbc
gtransform
/;

use DBI;

# Takes two domain objects
# TODO DOC
# TODO support segments
# TODO should be a method of SBG::Transform (think ORM)
sub superpose_query {
    my ($fromdom, $ontodom) = @_;
    log()->trace("$fromdom onto $ontodom");
    return unless 
        $fromdom && $fromdom->wholechain &&
        $ontodom && $ontodom->wholechain;

    my $db = config()->val('trans', 'db') || "trans_1_6";
    my $host = config()->val(qw/trans host/);
    my $dbh = SBG::U::DB::connect($db, $host);

    # Static handle, prepare it only once
    our $trans_sth;
    # Transformations are unidirectional, i.e. need to query A->B and B->A
    # Fields: Domain1 Domain2 Sc RMS Len1 Len2 Align Fit Eq Secs I S P
    my $query = 
        join(' ',
             'select',
             't.id_entity1 as tid1,',
             'e1.id as eid1,',

             'concat_ws(" ", ',
             '"\n", r11, r12, r13, v1, ',
             '"\n", r21, r22, r23, v2, ',
             '"\n", r31, r32, r33, v3) as string,', 

             't.sc as Sc,',
             'rmsd as RMS,',
             'alen as Align,',
             'nfit as Fit,',
             'nequiv as Eq,',
             '100*seqid/len as I,',
             '100*secid/len as S,',
             'p as P',

             'from',
             'entity e1, entity e2,',
             'trans t',

             'where',
             '(e1.chain=? and e1.description=?) and',
             '(e2.chain=? and e2.description=?) and',
             '((t.id_entity1=e1.id and t.id_entity2=e2.id) or',
             '(t.id_entity1=e2.id and t.id_entity2=e1.id))',
        );

    $trans_sth ||= $dbh->prepare($query);
    unless ($trans_sth) {
        log()->error($dbh->errstr);
        return;
    }

    my $c1 = $fromdom->wholechain();
    my $c2 = $ontodom->wholechain();
    my $pdbstr1 = 'pdb|' . uc($fromdom->pdbid) . '|' . $c1;
    my $pdbstr2 = 'pdb|' . uc($ontodom->pdbid) . '|' . $c2;

    my @params = ($pdbstr1, "CHAIN $c1", $pdbstr2, "CHAIN $c2");

    if (! $trans_sth->execute(@params)) {
        log()->error($trans_sth->errstr);
        return;
    }

    my $metadata = $trans_sth->fetchrow_hashref();
    my $trans = new SBG::Transform(%$metadata);

    # Need to figure out if it was A->B (as requested) or B->A (reversed)
    unless ($metadata->{'tid1'} eq $metadata->{'eid1'}) {
        log()->trace("Found inverse transform");
        $trans = $trans->inverse();
    }
    return $trans;

} # superpose_query


################################################################################
1;


