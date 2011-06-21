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

our @EXPORT_OK = qw(pdl_approx pdl_equiv);


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

