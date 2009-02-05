#!/usr/bin/env perl

=head1 NAME

SBG::DumperI - 

=head1 SYNOPSIS

with 'SBG::DumperI';

=head1 DESCRIPTION


=head1 SEE ALSO

L<Moose>

=cut

################################################################################

package SBG::DumperI;
use Moose::Role;
use Data::Dumper;

our @EXPORT = qw(Dumper);

################################################################################
=head2 dump

 Function: prints $self to given file handle, or STDOUT, via L<Data::Dumper>
 Example :
 Returns : 
 Args    :

Intended to be able to use $obj->dump as a method

=cut
sub dump {
   my ($self,$fh) = @_;
   $fh ||= \*STDOUT;
   print $fh Dumper $self;
} # dump


################################################################################
1;


