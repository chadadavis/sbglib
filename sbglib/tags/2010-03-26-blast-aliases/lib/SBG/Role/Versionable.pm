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

use base qw(Exporter);
our @EXPORT_OK = qw/check_version/;

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
=head2 check_version

 Function: Confirms that the module version has not changed for stored objects
 Example : 
 Returns : Successful version validation (Bool)
 Args    : 


=cut
sub check_version {
    my ($retrieved) = @_;
    my $type = blessed($retrieved) or return;
    if ($retrieved->can('does') && $retrieved->does("SBG::Role::Versionable")) {
        # The current version of the module
        my $class_ver = eval("\$${type}::VERSION") || $SBG::VERSION;
        # Vs. the version of the module that was saved in the stored object
        if ($class_ver ne $retrieved->version()) {
            warn 
                "Using $type $class_ver on object of version " . 
                $retrieved->version(), "\n";
            return 0;
        }
    }
    return 1;
} # check_version


################################################################################
no Moose::Role;
1;

