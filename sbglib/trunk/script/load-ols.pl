#!/usr/bin/env perl

use strict;
use warnings;

use PDL::LiteF;
use PDL::NiceSlice;
use PDL::Stats::GLM;
use PDL::IO::Misc qw/rcols/;

# do a multiple linear regression and plot the residuals

my $csvfile = shift || '/usr/local/home/davis/work/presentations/2010-04-21-group-ca/eval-100-Mscore.csv';


$PDL::IO::Misc::colsep = "\t";

# Leave undefined to get all lines
my $nlines = shift;
# my $nlines = 20;

my $inputlines = "1:$nlines";
my ($Mcomps, $pcComps, $nIacts, $nSources, $pcSeqLen, $avgIactCons, $avgSc,
# With MscoreLess
    $Mscore, $MscoreLess, $RMSDcofm, $Target, $Description, $Tcomps, $TseqLen) =
    rcols($csvfile, 5..14, 
# Without MscoreLess
#     $Mscore, $RMSDcofm, $Target, $Description, $Tcomps, $TseqLen) =
#     rcols($csvfile, 5..13, 
          {
              PERLCOLS => [0..4],
              LINES => $inputlines,
              EXCLUDE => "/\tNaN\t/",
          },
    );


# Dependent variable, object measure of similarity of model to known target benchmark complex
my $y = $RMSDcofm;
my ($nmodels) = dims($y);
# print "RMSDcofm:$y\n";

# independent model variables
my $iv = cat $pcComps, $nIacts, $nSources, $pcSeqLen, $avgIactCons, $avgSc;

# Ordinary least squares, to the independent variable $y
my %m  = $y->ols( $iv );

# Don't need this any longer
delete $m{'y_pred'};

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
my $ntestend = 1000;
my $obsi = "0:$ntestend";

my $obs = $modelvars->slice("$obsi,")->transpose;
# print "obs: $obs\n";
# sum over the first dimension, i.e. sum along the rows
my $preds = sumover $obs * $betas;
# print "preds:$preds\n";
my $actuals = $y->slice("$obsi");
# print "actuals:$actuals\n";
my $preds_actuals = cat($preds, $actuals)->transpose;
print "pred\tactual\n";
print $preds_actuals;

my $diffs = abs($actuals-$preds);
# print "diffs:$diffs\n";
print "nmodels: $nmodels\n";
print "ntests: ", ($ntestend-1), "\n";
print "mean error: ", sum($diffs)/($ntestend-1), "\n";
print "\n";


# use PDL::Graphics::PGPLOT::Window;
# my $win = pgwin( 'xs' );
# $win->points( $y - $m{y_pred} );
