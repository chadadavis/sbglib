#!/usr/bin/env perl

=head1 NAME

SBG::U::Test - Tools for testing

=head1 SYNOPSIS

 use SBG::U::Test;

=head1 DESCRIPTION


=head1 SEE ALSO

L<Test::More>

=head1 TODO

Refactor under Test::SBG:: (not part of distribution)

Or incorporate into Test::PDL CPAN modules

=cut


package SBG::U::Test;

use strict;
use warnings;

use base qw(Exporter);
use Test::More;
use PDL::Core qw/approx/;
use PDL::Ufunc qw/all any/;
use Carp qw/carp cluck/;

our @EXPORT_OK = qw(float_is pdl_approx pdl_equiv);


=head2 float_is

 Function: Like L<Test::More::is> but works for imprecise floating-point numbers
 Example : float_is(3.23434, 3.2341, 3, "These are equal for 3 decimals, not 4");
 Returns : Bool
 Args    : precision: number of significant digits after decimal


=cut
sub float_is ($$;$$) {
   my ($val1, $val2, $msg, $tol) = @_;
   return unless defined($val1) && defined($val2);
   $tol = '10%' unless defined $tol;

   my $diff = abs($val1-$val2);
   $msg ||= "float_is: $diff < $tol (from $val1)";

   my $ok;
   if ($tol =~ /(\d+)\%$/) {
       my $perc = $1 / 100.0;
       $ok = ok($diff < $perc * $val1, $msg);
   } else {
       $ok = ok($diff < $tol, $msg);
   }

   if($ok) {
       return 1;
   } else {
       printf STDERR 
           "\t|%g - %g| == %g exceeds tolerance: %s\n", 
           $val1, $val2, $diff, $tol;
   }
}



=head2 pdl_approx

 Function: Approximate matrix equality
 Example : pdl_approx($mat1, $mat2, "These are equal to within +/- 1.5", 1.5);
 Returns : Bool
 Args    : tolerance as a float or a percent (default '1%')


=cut
sub pdl_approx ($$;$$) {
   my ($mat1, $mat2, $msg, $tol) = @_;

   my $equiv = pdl_equiv($mat1, $mat2, $tol);
    
   if (ok($equiv, $msg)) {
       return 1;
   } else {
       print STDERR "\tExpected:\n${mat2}\n\tGot:\n${mat1}\n";
       return 0;
   }
}


# A non-Test::More version
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

