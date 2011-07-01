#!/usr/bin/env perl

=head1 NAME

SBG::Role::Versionable - Adds an object attribute to store its original VERSION

=head1 SYNOPSIS

package MyClass;
use Moose;
with 'SBG::Role::Versionable'; 

my $obj = MyClass->new;
print $obj->version;

=head1 DESCRIPTION



=head1 SEE ALSO

L<Moose::Role>

=cut

################################################################################

package SBG::Role::Versionable;
use Moose::Role;

# The default version for the whole sbglib package 
use SBG;


################################################################################
=head2 version

 Function: Returns the version of the module that created the object
 Example :
 Returns : 
 Args    :

Can be used to check if an object was created with an older version of a module

=cut

has version => ( 
    is => 'ro',
    default => sub { 
        my $type = ref shift; 
        my $version = eval("\$${type}::VERSION") || $SBG::VERSION;
    }
    );




################################################################################
no Moose::Role;
1;

