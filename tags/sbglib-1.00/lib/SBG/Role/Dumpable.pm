#!/usr/bin/env perl

=head1 NAME

SBG::Role::Dumpable - Role for objects providing dump() via e.g. Data::Dumper

=head1 SYNOPSIS

with 'SBG::Role::Dumpable';

=head1 DESCRIPTION

NB All Moose object already provide a L<dump> method.

=head1 SEE ALSO

L<Moose>

=cut

################################################################################

package SBG::Role::Dumpable;
use Moose::Role;


# Based on Data::Dumper::Dumper :
# use Data::Dumper;
# $Data::Dumper::Indent = 1;
# our @EXPORT = qw(Dumper);

# Based on Data::Dump::dump
use Data::Dump;
our @EXPORT = qw(dump);


################################################################################
=head2 dump

 Function: dumps $self to given file handle, or STDOUT
 Example :
 Returns : 
 Args    :

Intended to be able to use $obj->dump as a method

=cut
sub dump {
   my ($self,$fh) = @_;
   $fh ||= \*STDOUT;
#    print $fh Data::Dumper::Dumper $self;
   print $fh Data::Dump::dump $self;
} # dump


################################################################################
no Moose::Role;
1;


