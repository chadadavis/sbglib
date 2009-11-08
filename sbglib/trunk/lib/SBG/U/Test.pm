#!/usr/bin/env perl

=head1 NAME

SBG::U::Test - Tools for testing

=head1 SYNOPSIS

 use SBG::U::Test;

=head1 DESCRIPTION


=head1 SEE ALSO

L<Test::More>

=cut

################################################################################

package SBG::U::Test;
use base qw(Exporter);
use Test::More;
use PDL::Ufunc qw/all/;
use PDL::Core qw/approx/;
use Carp qw/carp cluck/;

our @EXPORT_OK = qw(float_is pdl_approx pdl_percent);


################################################################################
=head2 float_is

 Function: Like L<Test::More::is> but works for imprecise floating-point numbers
 Example : float_is(3.23434, 3.2341, 3, "These are equal for 3 decimals, not 4");
 Returns : Bool
 Args    : precision: number of significant digits after decimal


=cut
sub float_is ($$;$$) {
   my ($val1, $val2, $msg, $tol) = @_;
   return unless defined($val1) && defined($val2);
   $tol = 1.0 unless defined $tol;
   my $diff = abs($val1-$val2);
   $msg ||= "float_is: $diff < $tol";
   if(ok($diff < $tol, $msg)) {
       return 1;
   } else {
       printf STDERR 
           "\t|%g - %g| == %g exceeds tolerance: %g\n", 
           $val1, $val2, $diff, $tol;
   }
}


################################################################################
=head2 pdl_approx

 Function: Approximate matrix equality
 Example : pdl_approx($mat1, $mat2, 1.5, "These are equal to within +/- 1.5");
 Returns : Bool
 Args    : tolerance (default 1.0)


=cut
sub pdl_approx ($$;$$) {
   my ($mat1, $mat2, $msg, $tol) = @_;
   $tol = 1.0 unless defined $tol;
   $msg ||= "pdl approx (+/- $tol)";

   if (ok(all(approx($mat1, $mat2, $tol)),$msg)) {
       return 1;
   } else {
       print STDERR "\tExpected:\n${mat2}\n\tGot:\n${mat1}\n";
       return 0;
   }
}

sub pdl_percent ($$;$$) {
   my ($mat1, $mat2, $msg, $tol) = @_;
   $tol = '10%' unless defined $tol;

   if ($tol =~ /(\d+)\%$/) {
       $tol = $1 / 100.0;
   }

   $msg ||= "pdl percent (+/- $tol\%)";

   if (ok(all(abs($mat1-$mat2)/$mat1 < $tol), $msg)) {
       return 1;
   } else {
       print STDERR "\tExpected:\n${mat2}\n\tGot:\n${mat1}\n";
       return 0;
   }
}


################################################################################
1;

