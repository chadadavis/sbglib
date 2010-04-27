#!/usr/bin/env perl

=head1 NAME

SBG::Search::Bench - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::SearchI> , L<SBG::Network> , L<SBG::Interaction> 

=cut



package SBG::Search::Bench;
use Moose;

extends qw/Moose::Object Exporter/;
our @EXPORT_OK = qw/components pdbids search/;

with 'SBG::SearchI';

use Text::ParseWords; # qw/parse_line/;
use File::Basename;
use Log::Any qw/$log/;

use SBG::Types qw/$re_pdb/;
use SBG::Model;
use SBG::Interaction;

use SBG::DB::scop qw/scopdomain/;
use SBG::U::List qw/uniq/;


our $templatedb = dirname(__FILE__) . "/Bench.csv.gz";


=head2 components

 Function: Returns all domains of a given PDB ID, from benchmark
 Example : my @ids = components('2os7');
 Returns : Array of identifiers like: 2os7F.b.1.11.1-1
 Args    : PDB ID (lowercase)

See L<SBG::DB::scop> to create L<SBG::Domain> objects from these identifiers

=cut
sub components {
    my ($pdbid) = @_;
    $pdbid = lc $pdbid;
    # Grep the lines from database
    my $cmd = "zcat $templatedb | egrep \'^ -- Can model $pdbid (([^[:space:]]+)) (([^[:space:]]+))\'";
    open my $fh, "$cmd|";
    my @components;
    while (my $line = <$fh>) {
        my @fields = split ' ', $line;
        push @components, @fields[4,5];
    }
    return uniq @components;
}



=head2 pdbids

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub pdbids {
    # Grep the lines from database
    my $cmd = "zcat $templatedb | egrep -o \'^ -- Can model (....)\' | sort | uniq";
    open my $fh, "$cmd|";
    my @ids;
    while (my $line = <$fh>) {
        my @fields = split ' ', $line;
        push @ids, $fields[-1];
    }
    return uniq @ids;
}



=head2 search

 Function: 
 Example : 
 Returns : 
 Args    : Two Bio::Seq 

Greps the benchmark text file from Rob for templates.

#  -- 
# Can model 
# 1ir2                #pdb
# 1ir2A.c.1.14.1-1    #true1
# 1ir2A.d.58.9.1-1    #true2
# on 
# 1svdA.c.1.14.1-1    #templ1
# 1svdA.d.58.9.1-1    #templ2
# 1.000e-150          #eval1
# 77.00               #id1
# 1.000e-44           #eval2
# 70.00               #id2
# 64/129              # 1ir2 has 129 components, 1svd has 64 of them
# 0.496               # coverage fraction 64/129
# iRMSD  8.13053      # iRMSD true1--true2/templ1--templ2
# OK 31 40   0.78     # 31 out of 40 (78%) are "OK" (in what sense?)
# I2                  # The following refer to interprets2
# Z   4.188           # i2 z-score
# p 0.005             # i2 p-val
# 

=cut
sub search {
    my ($self, $seq1, $seq2) = @_;
    my ($accno1, $accno2) = map {$_->display_id} ($seq1, $seq2);
    return unless $accno1 && $accno2;

    # Expliciting grepping the $pdb should make this a little faster
    my ($pdb) = $accno1 =~ /^($re_pdb)/;
    my @interactions;
    open my $fh, "zcat $templatedb|";
    while (my $line = <$fh>) {

        next unless $line =~ 
            /^ -- Can model $pdb (($accno1) ($accno2)|($accno2) ($accno1)) on (\S+) (\S+)\s+(.*)/;

        # Could have matched either way around, split the grouped match
        my ($comp1, $comp2) = split ' ', $1;
        my ($templ1, $templ2) = ($6, $7);
        my $scores = $8;
        $log->debug("$comp1($templ1)--$comp2($templ2)");

        # Parse score line
        my ($eval1, $sid1, $eval2, $sid2, 
            $coverage, $coverage_frac, 
            undef, $irmsd,
            undef, $ok_n, $ok_tot, $ok_frac,
            undef, undef, $i2z, undef, $i2p,
            ) = parse_line('\s+', 0, $scores);

        # Now we can create some domain models
        my $model1 = new SBG::Model(query=>$seq1,subject=>scopdomain($templ1),
                                    scores=>{'eval'=>$eval1,'seqid'=>$sid1});
        my $model2 = new SBG::Model(query=>$seq2,subject=>scopdomain($templ2),
                                    scores=>{'eval'=>$eval2,'seqid'=>$sid2});

        # Save interaction-specific scores in the interaction template
        my $iaction = new SBG::Interaction(
            scores=>{irmsd=>$irmsd, zscore=>$i2z, pval=>$i2p}
            );
        # Lookup model based on sequence ID
        $iaction->set($seq1, $model1);
        $iaction->set($seq2, $model2);

        push @interactions, $iaction;

    } # while
    return @interactions;
} # search



__PACKAGE__->meta->make_immutable;
no Moose;
1;
