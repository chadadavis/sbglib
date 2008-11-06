#!/usr/bin/env perl

use PDL;
use PDL::Math;
use PDL::Matrix;

# Points

my $a = pdl (1,1);
my $b = pdl (3,3);

print "a:$a, b:$b\n";

print "dist: ", dist($a,$b);

sub dist {
    my ($a, $b) = @_;
    # square root of: sum of: differences squared
    return sqrt sumover(($a - $b) ** 2);
}

__END__

# Add 1 for affine computation
my $pcofm = mpdl (@cofm, 1);
# Transpose row to a column vector
$pcofm = transpose($pcofm);


