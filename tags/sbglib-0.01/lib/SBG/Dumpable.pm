#!/usr/bin/env perl

=head1 NAME

SBG::Dumpable - 

=head1 SYNOPSIS

with 'SBG::Dumpable';

=head1 DESCRIPTION


=head1 SEE ALSO

L<Moose>

=cut

################################################################################

package SBG::Dumpable;
use Moose::Role;
use Data::Dumper;

$Data::Dumper::Indent = 1;

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


