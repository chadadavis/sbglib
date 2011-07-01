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



package SBG::Role::Dumpable;
use Moose::Role;
use base qw/Exporter/;
our @EXPORT_OK = qw/dumper dump undump/;

use Scalar::Util qw/blessed/;
use Data::Dump;
use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Purity = 1;

# Any contained PDL objects need this to de-serialize, 
# but probably not via Dumper and Dump, which probably don't even work with PDL
use PDL::IO::Storable;

use File::Slurp qw/slurp/;



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
   print $fh Data::Dump::dump $self;
   return;
} # dump


sub dumper {
   my ($self,$fh) = @_;
   $fh ||= \*STDOUT;
   print $fh Data::Dumper::Dumper $self;
   return;
} # dump


sub undump {
    my ($path) = @_;
    my $str = slurp($path);
    my $obj;
    $obj = eval $str;
    return if $@;
    return $obj;
}



no Moose::Role;
1;


