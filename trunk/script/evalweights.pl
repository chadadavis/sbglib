#!/usr/bin/env perl

=head1 NAME

B<load-ols.pl> - ordinary least squares variable weighting

=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 OPTIONS

=head2 -h|elp Print this help page

=head2 -l|og Set logging level

In increasing order: TRACE DEBUG INFO WARN ERROR FATAL

I.e. setting B<-l WARN> (the default) will log warnings errors and fatal
messages, but no info or debug messages to the log file (B<log.log>)

=head2 -f|ile Log file

Default: <network name>.log in current directory

=head1 SEE ALSO

L<PDL::Stats::GLM> , L<PDL::Stats::Basic>

=cut

use strict;
use warnings;

use PDL::LiteF;
use PDL::NiceSlice;

# http://search.cpan.org/~maggiexyz/PDL-Stats-0.4.3/
use PDL::Stats::GLM;      # qw/ols/;
use PDL::Stats::Basic;    # qw/corr/;
use PDL::IO::Misc qw/rcols/;
use Statistics::Contingency;

$PDL::IO::Misc::colsep = "\t";

my $csvfile = shift || die;

# Leave undefined to read all lines
my $nlines = shift || '';

# Skip column headers
my $inputlines = "1:$nlines";

#my $inputlines = "0:$nlines";

# 0-based column indexing
my ($rmsd,
    $score,
    $difficulty,
    $pcclashes,

    $mndoms,
    $pcdoms,
    $mniactions,
    $pciactions,
    $mseqlen,
    $pcseqlen,

    $nsources,
    $ncycles,
    $pcburied,
    $glob,

    $scmax,
    $scmed,
    $scmin,

    $idmax,
    $idmed,
    $idmin,

    $ifacelenmax,
    $ifacelenmed,
    $ifacelenmin,

    $iweightmax,
    $iweightmed,
    $iweightmin,

    $seqcovermax,
    $seqcovermed,
    $seqcovermin,

    $olmax,
    $olmed,
    $olmin,

    $tid, $tdesc, $tndoms, $tniactions, $tseqlen, $mid, $homology
    )
    = rcols(
    $csvfile,
    7 .. 38,
    {   PERLCOLS => [ 0 .. 6 ],
        LINES    => $inputlines,
        EXCLUDE  => "/\t(nan|inf)\t/",
    },
    );

# Dependent variable, object measure of similarity of model to known target
# benchmark complex
my $y = $rmsd;
my ($nmodels) = dims($y);

# independent model variables
# NB Can't use any emtpy columns;
my $iv = cat $pcclashes,

    #    $mndoms, # Ruins correlation, why? Too discrete.

    $pcdoms, $mniactions, $pciactions, $mseqlen, $pcseqlen,

    $nsources,

    #    $ncycles, # too often 0
    $pcburied, $glob,

    $scmax, $scmed,

    #    $scmin, # Ruins correlation, why? Too often 0

    $idmax, $idmed, $idmin,

    $ifacelenmax, $ifacelenmed, $ifacelenmin,

    $iweightmax, $iweightmed, $iweightmin,

    $seqcovermax, $seqcovermed, $seqcovermin,

    # Too often 0
    #    $olmax,
    #    $olmed,
    #    $olmin,
    ;

# Ordinary least squares, to the independent variable $y
my %m = $y->ols($iv);

# Don't need this any longer
# delete $m{y_pred};

# Show linear model params
print "$_\t$m{$_}\n" for (sort keys %m);
print "\n";

my $betas = $m{b};

# Because betas contains a constant, add a column of ones to each observation
my $ones = ones($nmodels);

# Append this to the other data, requires splitting it, via dog() first,
# then concatanating again
my $modelvars = cat(dog($iv), $ones);

# print "modelvars:$modelvars\n";

# make a prediction on observations: $obsi
# my $ntestend = 15;
my $ntestend = 0;
my $obsi     = "0:$ntestend";

# my $obsi = "10:19";

my $obs = $modelvars->slice("$obsi,")->transpose;

# print "obs: $obs\n";

# Take a sample to test
# sum over the first dimension, i.e. sum along the rows
# my $preds = sumover $obs * $betas;
# print "preds:$preds\n";
# my $actuals = $y->slice("$obsi");

# Show the raw data
my $actuals = $y;
my $preds   = $m{y_pred};

# print "actuals:$actuals\n";
my $preds_actuals = cat($preds, $actuals)->transpose;
print "pred\tactual\n";

# print $preds_actuals->slice(':,10:50');
print $preds_actuals;

my $diffs = abs($actuals - $preds);

# print "diffs:$diffs\n";
print "nmodels: $nmodels\n";
print "ntests: ", ($ntestend - 1), "\n";
print "mean error: ", sum($diffs) / ($ntestend - 1), "\n";
print "\n";

# Now correlate $m->{y_pred} and $y
my $corr = $y->corr($m{y_pred});
print "corr on subset test: $corr\n";

$corr = $rmsd->corr($score);
print "corr rmsd:score : $corr\n";

print "Variable weights (last is the constant):\n$betas\n";

my @predicted = ($score <= 10)->list;
my @correct   = ($rmsd <= 10)->list;

#print "predicted:\n@predicted\n";
#print "correct:\n@correct\n";

# ROC
# 1 -sp = 1-tn/falses
# sn = tp/trues

my $rthresh = 10;
my $sthresh = 10;
my $tp      = (($rmsd <= $rthresh) & ($score <= $sthresh))->sum;
my $fp      = (($rmsd > $rthresh) & ($score <= $sthresh))->sum;
my $fn      = (($rmsd <= $rthresh) & ($score > $sthresh))->sum;
my $tn      = (($rmsd > $rthresh) & ($score > $sthresh))->sum;
my $sp      = $tn / ($fp + $tn);
my $sn      = $tp / ($fn + $tp);
my $ppv     = $tp / ($tp + $fp);
my $acc     = ($tp + $tn) / ($tp + $tn + $fp + $fn);
print "sp: $sp sn: $sn acc $acc\n";

my @sp_1;
my @sn;
for (my $i = 1; $i <= 30; $i += .5) {
    $sthresh = $i;
    my $tp = (($rmsd <= $rthresh) & ($score <= $sthresh))->sum;
    my $fp = (($rmsd > $rthresh) & ($score <= $sthresh))->sum;
    my $fn = (($rmsd <= $rthresh) & ($score > $sthresh))->sum;
    my $tn = (($rmsd > $rthresh) & ($score > $sthresh))->sum;
    my $sp = $tn / ($fp + $tn);
    my $sn = $tp / ($fn + $tp);

    #push @sp_1, int 100*( 1-$sp);
    #push @sn, int 100* $sn;
    push @sp_1, (1 - $sp);
    push @sn, $sn;
}
use List::MoreUtils qw/mesh/;
for (my $i = 0; $i < @sn; $i++) {
    print $sp_1[$i], "\t", $sn[$i], "\n";
}

#print join(',', @sp_1), '|', join(',',@sn), "\n\n";

use SBG::U::List qw/mapcolors/;

my @r;
my @s;
my @sum;
for (my $i = 5; $i <= 20; $i += 1.5) {
    my $rthresh = $i;
    for (my $j = 5; $j <= 20; $j += 1.5) {
        my $sthresh = $j;

        my $tp = (($rmsd <= $rthresh) & ($score <= $sthresh))->sum;
        my $fp = (($rmsd > $rthresh) & ($score <= $sthresh))->sum;
        my $fn = (($rmsd <= $rthresh) & ($score > $sthresh))->sum;
        my $tn = (($rmsd > $rthresh) & ($score > $sthresh))->sum;
        my $sp  = $tn / ($fp + $tn);
        my $sn  = $tp / ($fn + $tp);
        my $ppv = $tp / ($tp + $fp);
        my $acc = ($tp + $tn) / ($tp + $tn + $fp + $fn);
        push @r, $i;
        push @s, $j;

        # Map the value [0:2] somewhere between red (0) and green (2)
        my $color = mapcolors($sp + $sn, 0, 2, '#ff0000', '#00ff00');
        $color =~ s/#//;

        #push @sum, $color;
        #push @sum, int 500 *($sp+$sn-1);
        #push @sum, int 100 *($ppv);
        push @sum, int 100 * ($acc);
    }
}

#print join(',', @r), '|', join(',',@s), '|', join(',', @sum), "\n";

#my $cont = Statistics::Contingency->new(categories=>[0,1]);
#$cont->set_entries($tp, $fp, $fn, $tn);
##$cont->add_result(\@predicted, \@correct);

#print $cont->stats_table; # Show several stats in table form
#my $stats = $cont->category_stats;
#use Data::Dump qw/dump/;
#dump $stats;

