#!/usr/bin/env perl

=head1 NAME

SBG::Role::Writable - 

=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 SEE ALSO

L<Moose::Role>

=cut

################################################################################

package SBG::Role::Writable;
use Moose::Role;

use Scalar::Util qw/blessed/;
use Module::Load qw/load/;

use SBG::IO;

################################################################################
=head2 write

 Function:
 Example :
 Returns : 
 Args    :

=cut

sub write {
   my ($self,$format,%ops) = @_;

   my $io;
   if  ($format) {
       my $class = blessed $self;
       my $format_module = "${class}IO::${format}";
       eval { load $format_module; };
       if ($@) {
           warn "Could not load format: $format_module\n";
           return;
       }
       $io = $format_module->new(%ops);
   } else {
       $io = SBG::IO->new(%ops);
   }
   $io->write($self);
   return $io->file;

} 


################################################################################
no Moose::Role;
1;

