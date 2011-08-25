#!/usr/bin/env perl

=head1 NAME

SBG::Role::Storable - Moose role for Storable objects

=head1 SYNOPSIS

package MyClass;
use Moose;
with 'SBG::Role::Storable'; 


=head1 DESCRIPTION

If your class uses this role, it will need to define all the methods below.

Note that any data structure containing a L<PDL> cannot be stored in network
order. Any other data is stored in network order by default, using
L<Storable::nstore> .


=head1 SEE ALSO

L<Moose::Role>

=cut

package SBG::Role::Storable;
use Moose::Role;

# Also a functional interface
use base qw/Exporter/;
our @EXPORT    = qw/store retrieve/;
our @EXPORT_OK = qw/retrieve_files/;

use Scalar::Util qw/blessed/;

# Don't bring 'store' into this namespace, since we have that function too
use Storable qw//;

use SBG::U::List qw/flatten/;

# Any contained PDL objects need this to de-serialize
use PDL::IO::Storable;

=head2 store

 Function:
 Example :
 Returns : 
 Args    :

Just a wrapper for OO-style store()

Uses network order to be able to share object files between architectures.

Caveat:Any PDL objects will ignore network order and not be network-transparent.

=cut

sub store {
    my ($self, $file, @args) = @_;

    return Storable::nstore($self, $file);
}    # store

=head2 retrieve

 Function:
 Example :
 Returns : 
 Args    :

NB Due to the overload module not automatically updating the symbol table, this
function will re-bless the object back into its own class. This *may* have other
unintended side effects.

See also L<bless> , L<overload>

=cut

sub retrieve {
    my ($file) = @_;
    return unless -r $file;
    my $obj;
    eval { $obj = Storable::retrieve($file) };
    return if $@;

    # See if the module has been updated since object was stored.
    # TODO add this back in after re-creating all objects
    #    check_version($obj);
    return $obj;
}    # retrieve

=head2 retrieve_files

 Function: Get all the objects from all the Stor'ed arrays in all given files
 Example : my ($objA, $objB) = retrieve_files("filea.stor", "../tmp/fileb.stor");
 Returns : Array or ArrayRef, depending on wantarray
 Args    : Paths to files containing L<Storable> objects

=cut

sub retrieve_files {
    @_ = flatten @_;
    my @a = map { flatten retrieve($_) } @_;
    return wantarray ? @a : \@a;
}

no Moose::Role;
1;

