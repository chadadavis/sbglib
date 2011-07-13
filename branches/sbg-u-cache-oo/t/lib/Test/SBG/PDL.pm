#!/usr/bin/env perl

=head1 NAME

Test::SBG::PDL - Tools for testing PDLs

=head1 SYNOPSIS

    use Test::SBG::PDL qw/pdl_approx/;
    
    # Test::More test on PDL matrices, to within a certain rounding threshold
    pdl_approx($pdl_1, $pdl2, "transformations equal", '5%');   

=head1 DESCRIPTION

Most tests are discrete. With transformations and atomic data, there are 
deviations, due to rounding and imperfect floating point representations. This
answers the question: are the matrices basically the same, withing a few percent.

It does in a way that fits into a regular test harness, so that C<make test>
works the same. If you want the general function, it's

    my $are_the_same = pdl_equiv($pdl_1, $pdl_2, '5%');
    

=head1 SEE ALSO

=over

=item L<Test::More>

=item L<PDL::Core>

=item L<PDL::Ufunc>

=back

=cut


package SBG::U::Test;
use strict;
use warnings;

use base qw(Exporter);
use Test::More;
use PDL::Core qw/approx/;
use PDL::Ufunc qw/all any/;

our @EXPORT_OK = qw(pdl_approx pdl_equiv);


=head2 pdl_approx

Approximate matrix equality

    my $bool = pdl_approx($mat1, $mat2, "These are equal to within +/- 1.5", 1.5);

Tolerance is a float or a percent (default '1%')

This uses L<Test::More> so that it works nicely in your existing test framework

=cut
sub pdl_approx ($$;$$) {
   my ($mat1, $mat2, $msg, $tol) = @_;

   my $equiv = pdl_equiv($mat1, $mat2, $tol);
    
   if (ok($equiv, $msg)) {
       return 1;
   } else {
       diag "\tExpected:\n${mat2}\n\tGot:\n${mat1}\n";
       return 0;
   }
}


=head2 pdl_equiv

This is not a L<Test::More> function. It simply returns a boolean. There is no
message argument.

    my $bool = pdl_equiv($mat1, $mat2, 1.5);

=cut
sub pdl_equiv {
    my ($mat1, $mat2, $tol) = @_;
    $tol = '1%' unless defined $tol;
        
    my $diff = abs($mat1-$mat2);
    
    if ($tol =~ /(\d+)\%$/) {
        $tol = $1 / 100.0;
        $diff /= abs($mat1);
    }
    return ! any($diff > $tol);
}

1;

