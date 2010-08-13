#!/usr/bin/env perl

=head1 NAME

B<load-ols.pl> - ordinary least squares variable weighting

=head1 SYNOPSIS



=head1 DESCRIPTION

Need to remove NaN or nan 


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
use PDL::Stats::GLM;   # qw/ols/;
use PDL::Stats::Basic; # qw/corr/;
use PDL::IO::Misc qw/rcols/;

$PDL::IO::Misc::colsep = "\t";


my $csvfile = shift || die;

# Leave undefined to read all lines
my $nlines = shift;

# Skip column headers
 my $inputlines = "1:$nlines";
#my $inputlines = "0:$nlines";

# 0-based column indexing
my (
    $rmsd, 
    
    $score, 
    $difficulty,
    
    $pcclashes,
    
    $mndoms, 
    $pdoms,
    $mseqlen, 
    $pseqlen, 
    $mnias, 
    
    $nsources, 
    $ncycles, 
    $homology, # Non-numeric, belongs right after target
     
    $scmax, 
    $scmed,
    $scmin,
     
    $glob,
    $pcburied,
     
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
    
    $tid, $tdesc, $tndoms, $tseqlen, $tnias, $mid
    ) = 
    rcols($csvfile, 
          6..37,
          {
              PERLCOLS => [0..5],
              LINES => $inputlines,
              EXCLUDE => "/nan/",
          },
    );


# Dependent variable, object measure of similarity of model to known target
# benchmark complex
my $y = $rmsd;
my ($nmodels) = dims($y);

# independent model variables
# NB Can't use any emtpy columns;
my $iv = cat 
    $pcclashes,
#    $mndoms, # Ruins correlation, why? 
    $pdoms,
    $mseqlen, 
    $pseqlen,
    $mnias,
    
    $nsources, 
#    $ncycles, # too often 0
     
    $scmax, 
    $scmed,
    $scmin,
     
    $glob,
    $pcburied,
     
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
   
# Too often 0    
#    $olmax, 
#    $olmed,
#    $olmin, 
    ;


# Ordinary least squares, to the independent variable $y
my %m  = $y->ols( $iv );


# Don't need this any longer
# delete $m{'y_pred'};

# Show linear model params
print "$_\t$m{$_}\n" for (sort keys %m);
print "\n";

my $betas = $m{'b'};
print "Variable weights (last is the constant):\n$betas\n";

# Because betas contains a constant, add a column of ones to each observation
my $ones = ones($nmodels);
# Append this to the other data, requires splitting it, via dog() first, 
# then concatanating again
my $modelvars = cat(dog($iv), $ones);
# print "modelvars:$modelvars\n";


# make a prediction on observations: $obsi
# my $ntestend = 15;
my $ntestend = 0;
my $obsi = "0:$ntestend";
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
my $preds = $m{'y_pred'};

# print "actuals:$actuals\n";
my $preds_actuals = cat($preds, $actuals)->transpose;
print "pred\tactual\n";
# print $preds_actuals->slice(':,10:50');
print $preds_actuals;

my $diffs = abs($actuals-$preds);
# print "diffs:$diffs\n";
print "nmodels: $nmodels\n";
print "ntests: ", ($ntestend-1), "\n";
print "mean error: ", sum($diffs)/($ntestend-1), "\n";
print "\n";

# Now correlate $m->{y_pred} and $y
my $corr = $y->corr($m{'y_pred'});
print "corr: $corr\n";
