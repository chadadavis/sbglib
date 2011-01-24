#!/usr/bin/env perl

=head1 NAME

B<randomsample> - Randomly sample N items from the names on the command line

=head1 SYNOPSIS

 randomsample 5 alpa beta gamma delta epsilon zeta eta theta

Will return a random five elements from the given list.

 randomsample 0.33 alpa beta gamma delta epsilon zeta eta theta

Will return a random third of the elements.

Note that N must be <= the number of items that you provide. I.e. the sampling is without replacement.


=head1 SEE ALSO

L<Algorithm::Numerical::Sample>

=cut 

use strict;
use warnings;

use Algorithm::Numerical::Sample  qw /sample/;
use Data::Dump qw/dump/;
use POSIX qw/ceil/;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::U::Run qw/frac_of/;

my $sample = sample_it(@ARGV);
print "@$sample\n";
exit;

sub sample_it {
	my ($size, @args) = @_;

    $size = @args if $size > @args;
    # $size can be a fraction of @args as well
    $size = ceil frac_of($size, scalar(@args));
        
    my @sample = sample(-set => \@args,-sample_size => $size);
    return \@sample;

}

                                   
