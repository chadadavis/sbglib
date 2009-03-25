#!/usr/bin/env perl

=head1 NAME

SBG::Test - Tools for testing

=head1 SYNOPSIS

 use SBG::Test;

=head1 DESCRIPTION


=head1 SEE ALSO

L<Test::More>

=cut

################################################################################

package SBG::Test;
use base qw(Exporter);

use feature 'say';
use Data::Dumper;
use Test::More;

# Export a couple global vars
# (Re-)export a few really handy functions

our @EXPORT_OK = qw(float_is);


################################################################################
=head2 float_is

 Function: Like L<Test::More::is> but works for imprecise floating-point numbers
 Example : float_is(3.23434, 3.2341, 3, "These are equal for 3 decimals, not 4");
 Returns : Bool
 Args    : precision: number of significant digits after decimal


=cut
sub float_is ($$;$$) {
   my ($val1, $val2, $precision, $msg) = @_;
   $precision ||= '';
   my $sval1 = sprintf("%.${precision}g",$val1);
   my $sval2 = sprintf("%.${precision}g",$val2);
   $msg ||= "$sval1 ~ $sval2";
   is(sprintf("%.${precision}g",$val1), sprintf("%.${precision}g",$val2), "float_is $msg");
}


################################################################################
1;

