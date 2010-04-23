#!/usr/bin/env perl

=head1 NAME




=head1 SYNOPSIS




=head1 DESCRIPTION


=head1 SEE ALSO


=cut



package SBG::DB::trans;
use base qw/Exporter/;
our @EXPORT_OK = qw/superposition/;

use Moose::Autobox;

use DBI;
use PDL qw/pdl/;
use Log::Any qw/$log/;

use SBG::U::DB;
use SBG::Superposition;
use SBG::Transform::Affine;



# TODO DES OO
our $database = "trans_3_0";
our $host;



=head2 query

 Function: 
 Example : 
 Returns : 
 Args    : 
           

=cut
sub superposition {
    my ($fromdom, $ontodom) = @_;

    my $superpos = superposition_native($fromdom, $ontodom);
    return unless defined $superpos;

    return $superpos unless ($fromdom->transformation->has_matrix || 
                             $ontodom->transformation->has_matrix);

    # Right-to-left application of transformations to get fromdom=>ontodom
    # First, inverse $fromdom back to it's native transform
    # Then, apply the transform between the native domains
    # Last, apply the transform stored in $ontodom, if any
    my $prod = 
        $ontodom->transformation x 
        $superpos->transformation x 
        $fromdom->transformation->inverse;

    $superpos->transformation($prod);
    return $superpos;

} # superposition



=head2 superposition_native

 Function: 
 Example : 
 Returns : 
 Args    : 

The Domain objects must have the 'entity' field set. I.e. these objects must
have come from the entity database in the first place.

=cut
sub superposition_native {
    my ($dom1, $dom2) = @_;
    return unless $dom1->entity && $dom2->entity;
    our $database;
    our $host;
    my $dbh = SBG::U::DB::connect($database, $host);
    # Static handle, prepare it only once
    our $sth;

    $log->debug("$dom1(",$dom1->entity,")=>$dom2(", $dom2->entity, ")");

    $sth ||= $dbh->prepare("
SELECT
sc,rmsd,seqid,secid,
r11,r12,r13,v1,
r21,r22,r23,v2,
r31,r32,r33,v3
FROM 
trans
WHERE (id_entity1=? AND id_entity2=?)
");
    unless ($sth) {
        $log->error($dbh->errstr);
        return;
    }
    if (! $sth->execute($dom1->entity, $dom2->entity)) {
        $log->error($sth->errstr);
        return;
    }
    my $row = $sth->fetchrow_hashref();
    if (defined $row) {
        $log->debug("DB hit (positive) $dom1=>$dom2");
    } else {
        $log->debug("DB miss $dom1=>$dom2");
        return;
    }

    my $mat = [ 
        $row->slice([qw/r11 r12 r13 v1/]),
        $row->slice([qw/r21 r22 r23 v2/]),
        $row->slice([qw/r31 r32 r33 v3/]),
        [ 0, 0, 0, 1 ],
        ];
    # Create Transform object
    my $trans = SBG::Transform::Affine->new(matrix=>pdl($mat));
    
    # Dont' modify original Domain, make a copy
    my $sup = SBG::Superposition->new(
        from=>$dom1->clone,
        to=>$dom2->clone,
        transformation=>$trans,
        scores=>{
            Sc=>$row->{sc},
            RMS=>$row->{rmsd},
            seq_id=>$row->{seqid},
            sec_id=>$row->{secid},
        },
        );

    return $sup;

} # superposition_native




1;
