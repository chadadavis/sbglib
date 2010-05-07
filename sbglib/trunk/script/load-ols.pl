#!/usr/bin/env perl

use PDL::LiteF;
use PDL::NiceSlice;
use PDL::Stats::GLM;
use PDL::IO::Misc qw/rcols/;

# do a multiple linear regression and plot the residuals

my $csvfile = shift || '/usr/local/home/davis/work/presentations/2010-04-21-group-ca/eval-100-Mscore.csv';


$PDL::IO::Misc::colsep = "\t";

my $inputlines = '1:';
my ($Mcomps, $pcComps, $nIacts, $nSources, $pcSeqLen, $avgIactCons, $avgSc,
    $Mscore, $RMSDcofm, $Target, $Description, $Tcomps, $TseqLen) =
#     rcols($csvfile, 5..14, 
    rcols($csvfile, 5..13, 
          {
              PERLCOLS => [0..4],
              LINES => $inputlines,
              EXCLUDE => "/\tNaN\t/",
          },
    );


my $y = $RMSDcofm;
my ($nmodels) = dims($y);

# independent model variables
my $iv = cat $avgIactCons, $avgSc;

# Ordinary least squares, to the independent variable $y
my %m  = $y->ols( $iv );

# Don't need this
delete $m{'y_pred'};

# Show linear model params
print "$_\t$m{$_}\n" for (sort keys %m);
print "\n";

my $betas = $m{'b'};
print "Variable weights (last is constant) : $betas\n";

# Because betas contains a constant, add a column of ones to each observation
my $ones = ones($nmodels);
# Append this to the other data, requires splitting it, via dog() first, 
# then concatanating again
my $modelvars = cat(dog($iv), $ones);

# make a prediction on observations: $obsi
# my $obsi = 2;
# my $obsi = ":"; # all
my $obsi = "1:20";
my $obs = $modelvars->slice("$obsi,")->transpose;
# print "obs: $obs\n";
# sum over the first dimension, i.e. sum along the rows
my $preds = sumover $obs * $betas;
# print "preds:$preds\n";
my $actuals = $y->slice("$obsi");
# print "actuals:$actuals\n";
my $diffs = abs($actuals-$preds);
# print "diffs:$diffs\n";
print "nmodels: $nmodels\n";
print "mean error: ", sum($diffs)/$nmodels, "\n";
print "\n";


# use PDL::Graphics::PGPLOT::Window;
# my $win = pgwin( 'xs' );
# $win->points( $y - $m{y_pred} );
