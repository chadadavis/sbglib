#!/usr/bin/env perl

=head1 NAME

SBG::Storable - Moose role for Storable objects

=head1 SYNOPSIS

package MyClass;
use Moose;
with 'SBG::Storable'; 


=head1 DESCRIPTION

If your class uses this role, it will need to define all the methods below.

=head1 SEE ALSO

L<Moose::Role>

=cut

################################################################################

package SBG::Storable;
use Moose::Role;

use Storable qw();
use Scalar::Util qw(blessed);
use Carp;

# Also a functional interface
use base qw(Exporter);
our @EXPORT = qw(store retrieve);
our @EXPORT_OK = qw(module_for);


################################################################################
=head2 store

 Function:
 Example :
 Returns : 
 Args    :

Just a wrapper for OO-style store()

=cut
sub store {
   my ($self,$file,@args) = @_;
   return Storable::store($self, $file);
} # store


################################################################################
=head2 retrieve

 Function:
 Example :
 Returns : 
 Args    :


=cut
sub retrieve {
   my ($self, $file,@args) = @_;
   # Not called as an object/package method?
   $file = $self if -r $self;
   my $obj = Storable::retrieve($file);
   # Load required module
   module_for($obj);
   return $obj;
} # retrieve


################################################################################
=head2 module_for

 Function: Loads the module for an object of a given class
 Example : my $obj = retrieve("file.stor"); module_for($obj); $obj->a_method();
 Returns : Whether module was loaded successfully
 Args    : $obj : an object

Why does Perl not do this automatically?

=cut
sub module_for {
    my ($obj) = @_;
    my $class = blessed $obj;
    $class =~ s|::|/|g;
    $class .= '.pm';
    eval { require $class; };
    if ($@) {
        carp("Could not load module: $class");
        return 0;
    }
    return 1;
}


################################################################################
1;

