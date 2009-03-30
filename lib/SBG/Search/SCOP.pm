#!/usr/bin/env perl

=head1 NAME

SBG::SCOPSearch - 

=head1 SYNOPSIS

 use SBG::SCOPSearch;

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Search> , L<SBG::Network> , L<SBG::Interaction> 

=cut

################################################################################

package SBG::Search::SCOP;
use Moose;

extends qw/Moose::Object Exporter/;
our @EXPORT_OK = qw/domains complex parse_scopid/;

with 'SBG::SearchI';

use Text::ParseWords;

use Bio::Seq;
use SBG::Types qw/$re_pdb/;
use SBG::Domain;
use SBG::Template;
use SBG::Interaction;
use SBG::List qw/uniq/;
use SBG::Log;
use SBG::Complex;

# TODO Needs to be in a DB
# Maps e.g. 2hz1A.a.1.1.1-1 to { A 2 _ to A 124 _ }
our $scopdb = "~/p/ca/benchmark/scop_1.73.dom.gz";
# Maps e.g. 1ir2B.c.1.14.1-1 to:
# 1rlcL.c.1.14.1-1 1.000e-177 89.00 
our $templatedb = "~/p/ca/benchmark/search_bench_part8.out-robs.gz";


################################################################################
=head2 search

 Function:
 Example :
 Returns : 
 Args    :

=cut
sub search {
   my ($self, $seq1, $seq2) = @_;

   my @templates = $self->_grep_db($seq1, $seq2);

   return @templates;

} # search


################################################################################
=head2 domains

 Function: Returns all domains of a given PDB ID, from benchmark
 Example : my @ids = SBG::SCOPSearch::domain('2os7');
 Returns : Array of identifiers like: 2os7F.b.1.11.1-1
 Args    : PDB ID (not case-sensitive)


=cut
sub domains {
    my ($pdbid) = @_;
    $pdbid = lc $pdbid;
    # Grep the lines from database
    my $cmd = "zgrep -P \'^Can model $pdbid (\\S+) (\\S+)\' $templatedb";
    my @lines = `$cmd`;
    my @components;
    my @a;
    for (@lines) {
        @a = split;
        push @components, $a[3], $a[4];
    }
    return uniq @components;
}


# For a given PDB ID, build the complex containing only the domains for which
# interaction templates exist.
# NB this graph might not be connected
sub complex {
    my ($pdbid, $type) = @_;
    $type ||= 'SBG::Domain';
    my @components = domains($pdbid);
    my $complex = new SBG::Complex;
    $complex->model($_, $type->new(parse_scopid($_))) for @components;
    return $complex;
}


################################################################################
=head2 _grep_db

 Function: 
 Example : 
 Returns : 
 Args    : 

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
sub _grep_db {
    my ($self, $seq1, $seq2) = @_;
    my ($comp1, $comp2) = map {$_->accession_number} ($seq1, $seq2);
    my ($pdb) = $comp1 =~ /^($re_pdb)/;

    # Grep the lines from database
    my $cmd = 
        "zgrep -E \'^ -- Can model $pdb ($comp1 $comp2|$comp2 $comp1) on\' " . 
        $templatedb;
    my @lines = `$cmd`;
    return unless @lines > 0;
    $logger->trace(sprintf "pair: %s: %3d hits: %s -- %s",
                   $pdb, scalar(@lines), $comp1, $comp2);
    my @interactions;
    foreach (@lines) {
        unless (/^( -- )?Can model $pdb (\S+) (\S+) on (\S+) (\S+)\s+(.*)$/) {
            $logger->warn("Couldn't parse:\n$_");
            next;
        }
        # Update these, in case they are reversed
        ($comp1, $comp2) = ($2, $3);

        my ($templ1, $templ2) = ($4, $5);
        my $scores = $6;

        # Now we can create some domains
        my $dom1 = $self->type->new(parse_scopid($templ1));
        my $dom2 = $self->type->new(parse_scopid($templ2));
        my $template1 = new SBG::Template(seq=>$seq1,domain=>$dom1);
        my $template2 = new SBG::Template(seq=>$seq2,domain=>$dom2);

        # Parse scores
        my ($eval1, $sid1, $eval2, $sid2, 
            $coverage, $coverage_f, 
            undef, $irmsd,
            undef, $ok_n, $ok_tot, $ok_f,
            undef, undef, $i2z, undef, $i2p,
            ) = parse_line('\s+', 0, $scores);


        $template1->score('eval', $eval1);
        $template2->score('eval', $eval2);
        $template1->score('seqid', $sid1);
        $template2->score('seqid', $sid2);

        # Save interaction-specific scores in the interaction template
        my $iactionid = "$template1--$template2";
        my $iaction = new SBG::Interaction(-id=>$iactionid);
        $iaction->template($seq1, $template1);
        $iaction->template($seq2, $template2);
        $iaction->score('irmsd',  $irmsd);
        $iaction->score('zscore', $i2z);
        $iaction->score('pval',   $i2p);

        push @interactions, $iaction;
    } # foreach
    return @interactions;
} # _grep_db



# Given: 2hz1A.a.1.1.1-1, returns hash:
# (pdbid=>$pdbid, descriptor=>$descriptor, scopid=>$sccs, file=>$file);
# (pdbid=>'2hz1', descriptor=>"A 2 _ to A 124 _",
#  scopid=>'a.1.1.1-1', file=>"/data/pdb/2hz1.brk")
# TODO BUG file is bogus here, ignore it
sub parse_scopid {
    my ($longid) = @_;
    unless ($longid =~ /^(\d.{3})(.*?)\.(.*?)$/) {
        $logger->error("Couldn't parse SCOP ID: $longid");
        return;
    }
    my ($pdbid, $chainid, $sccs) = ($1, $2, $3);
    
    # Given: 2hz1A.a.1.1.1-1, this matches:
    # ("/data/pdb/2hz1.brk","2hz1A.a.1.1.1-1","A 2 _ to A 124 _")
    my $match = `zgrep $longid $scopdb`;
    unless ($match =~ /^(\S+) ($longid) { (.*?) }$/) {
        $logger->error("SCOP ID not found: $longid");
        return;
    }
    my ($file, $descriptor) = ($1, $3);
    my %fields = (pdbid=>$pdbid, descriptor=>$descriptor, scopid=>$sccs);
    return wantarray ? %fields : \%fields;
}


################################################################################
__PACKAGE__->meta->make_immutable;
1;
