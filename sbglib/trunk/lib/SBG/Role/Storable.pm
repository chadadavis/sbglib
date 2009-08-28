#!/usr/bin/env perl

=head1 NAME

SBG::Role::Storable - Moose role for Storable objects

=head1 SYNOPSIS

package MyClass;
use Moose;
with 'SBG::Role::Storable'; 


=head1 DESCRIPTION

If your class uses this role, it will need to define all the methods below.

=head1 SEE ALSO

L<Moose::Role>

=cut

################################################################################

package SBG::Role::Storable;
use Moose::Role;

# Also a functional interface
use base qw(Exporter);
our @EXPORT = qw(store retrieve);
our @EXPORT_OK = qw(module_for can_do retrieve_files);

# Don't bring 'store' into this namespace, since we have that function too
use Storable qw//;
# Any contained PDL objects need this to de-serialize
use PDL::IO::Storable;

use Scalar::Util qw/blessed/;
use SBG::U::List qw/flatten/;
use Module::Load qw/load/;

use Class::MOP::Class;



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
#    return Storable::store($self, $file);
   # Use network order to be able to share object files between architectures
   return Storable::nstore($self, $file);
} # store


################################################################################
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
   my $obj = Storable::retrieve($file);
   # Load the module definition for the type of object
   module_for($obj);
   my $class = blessed($obj);
   # Bless back into own class (restores 'overload' functionality)
   bless $obj, $class if $class;
   # See if the module has been updated since object was stored.
   
   # TODO add this back in after re-creating all objects
#    check_version($obj);

   return $obj;
} # retrieve


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


################################################################################
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
    Module::Load::load($class);
    UNIVERSAL::isa($obj, 'HASH') or return;
    foreach my $k (%$obj) {
        module_for($obj->{$k});
    }
}


################################################################################
=head2 can_do

 Function: Figures out what methods an object supports
 Example : my $methods = SBG::Role::Storable::can_do($obj);
 Returns : HashRef of method names, keyed by module name
 Args    : An Object

E.g.
$VAR1 = {
          'SBG::Domain::CofM' => [
                                   'transform',
                                   'radius',
                                   'asarray',
                                 ],
          'SBG::Domain' => [
                             'pdbid',
                             'descriptor',
                             'uniqueid',
                             'transformation',
                           ]
        };


=cut

sub can_do {
    my ($obj) = @_;
    my $class = blessed $obj;
    my $meta = Class::MOP::Class->initialize($class);
    my @names = $meta->compute_all_applicable_methods;
    my @sbgnames = grep { $_->{'class'} =~ /^SBG/ } @names;
    my %methods;
    foreach (@sbgnames) {
        my ($class, $name) = ($_->{class}, $_->{name});
        next if $name =~ /^_/;
        $methods{$class} ||= [];
        push(@{$methods{$class}}, $name);
    }
    return \%methods;
} # can_do


################################################################################
no Moose::Role;
1;

