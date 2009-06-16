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

our @EXPORT_OK = qw(float_is pdl_approx);


################################################################################
=head2 float_is

 Function: Like L<Test::More::is> but works for imprecise floating-point numbers
 Example : float_is(3.23434, 3.2341, 3, "These are equal for 3 decimals, not 4");
 Returns : Bool
 Args    : precision: number of significant digits after decimal


=cut
sub float_is ($$;$$) {
   my ($val1, $val2, $precision, $msg) = @_;
   return unless defined($val1) && defined($val2);
   $precision ||= '';
   my $sval1 = sprintf("%.${precision}g",$val1);
   my $sval2 = sprintf("%.${precision}g",$val2);
   $msg ||= "$sval1 ~ $sval2";
   is(sprintf("%.${precision}g",$val1), sprintf("%.${precision}g",$val2), "float_is $msg");
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
   $tol ||= 1.0;
   $msg = "approx (+/- $tol) $msg";

   if (ok(all(approx($mat1, $mat2, $tol)),$msg)) {
       return 1;
   } else {
       carp "Expected:${mat2}Got:${mat1}";
       return 0;
   }
}


################################################################################
1;

