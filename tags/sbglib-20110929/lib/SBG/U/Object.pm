#!/usr/bin/env perl

=head1 NAME

SBG::Role::Object -

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::Role::Storable> , L<SBG::Role::Dumpable>

=cut

package SBG::U::Object;
use strict;
use warnings;
use base qw/Exporter/;
our @EXPORT_OK = qw/module_for methods load_object/;

use Scalar::Util qw/blessed/;
use Module::Load qw/load/;
use Log::Any qw/$log/;

use SBG::Role::Storable qw/retrieve/;
use SBG::Role::Dumpable qw/undump/;

use Class::MOP::Class;

# Shouldn't need to explicitly load this, but overloading is not restored if not
use SBG::Seq;

=head2 module_for

 Function: Loads the module for an object of a given class
 Example : my $obj = retrieve("file.stor"); module_for($obj); $obj->a_method();
 Returns : NA
 Args    : $obj : an object or a class name (Str)

Recursively traverses the data structure, loading any needed modules along the
way.

BUGS: Why does Perl not do this automatically when deserializing an object?

=cut

sub module_for {
    my ($obj) = @_;
    my $class = blessed($obj) or return;

    # Load the required class dynamically
    Module::Load::load($class);

    # Bless back into own class (restores 'overload' functionality)
    bless $obj, $class if $class;

    # Process all contained objects recursively
    if (UNIVERSAL::isa($obj, 'HASH')) {
        foreach my $k (keys %$obj) {
            module_for($obj->{$k});
        }
    }
    if (UNIVERSAL::isa($obj, 'ARRAY')) {
        foreach my $val (@$obj) {
            module_for($val);
        }
    }
}

=head2 load_object

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub load_object {
    my ($path) = @_;
    my $obj = retrieve($path);
    $obj = undump($path) unless defined $obj;
    if (defined $obj) {
        $log->debug("Loaded: ", $path);
    }
    else {
        $log->error("Failed to load: ", $path);
    }
    return unless defined $obj;

    # Load the module definition for the type of object
    module_for($obj);

    # See if the module has been updated since object was stored.
    # TODO add this back in after re-creating all objects
    #    check_version($obj);

    return $obj;
}

=head2 methods

 Function: 
 Example : 
 Returns : 
 Args    : 

Assumes we're dealing with MOP::Class, e.g. Moose, objects here

=cut

sub methods {
    my ($obj) = @_;
    return unless defined($obj);
    my $pkg         = blessed $obj;
    my @methods     = $obj->meta->get_all_methods;
    my @pkg_methods = grep { $_->package_name =~ /^$pkg$/ } @methods;
    my @public      = grep { $_->name !~ /^_/ } @pkg_methods;
    my @names       = map { $_->original_fully_qualified_name } @public;
    my @sorted      = sort @names;
    return @sorted;

}

1;

