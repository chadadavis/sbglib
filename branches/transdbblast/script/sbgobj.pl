#!/usr/bin/env perl

=head1 NAME

B<sbgobj> - Interface to serialized objects 

=head1 SYNOPSIS

sbgobj myfile.stor <object-method> <parameters> ...

=head1 DESCRIPTION

Calls the given method on the object stored in myfile.stor

If no method is given, the object is printed.


Uses bash autocomplete:
 
 complete -o default -C 'sbgobj -options' sbgobj


=head1 OPTIONS

=head2 -k Keep temporary files

For debugging

=head2 -l loglevel

One of:

 DEBUG INFO WARN ERROR

=head2 -h Help

=head1 SEE ALSO

L<SBG::Role::Storable>

=cut

# CPAN

use strict;
use warnings;
use Pod::Usage;
use File::Temp;
use Scalar::Util qw/blessed/;
use Moose::Autobox;
use Data::Dump qw/dump/;
use Carp;
use Log::Any qw/$log/;

# Local libraries
use FindBin qw/$Bin/;
use lib "$Bin/../lib/";

use SBG::U::Log;
use SBG::U::Object qw/load_object methods/;

# NB requires bash cmd: complete  -o default -C scriptname scriptname
use SBG::U::Complete qw/complete_methods/;
use Getopt::Complete (
    'keep!'      => undef,
    'help!'      => undef,
    'debug!'     => undef,
    'loglevel=s' => [qw/DEBUG INFO WARN ERROR/],

    # For everything else that's not a file, try object method name completion
    '<>' => \&complete_methods,
);

$SIG{__DIE__} = \&confess if $ARGS{debug};
$File::Temp::KEEP_ALL = 1 if $ARGS{keep};

# Non-option arguments
my (@params) = @{ $ARGS{'<>'} };

# Expect an object file first
my $objfile = $params[0];
pod2usage(-exitval => 2, -verbose => 2) unless -s $objfile;

# Convert filenames to objects, others params remain unchanged
my @oparams = map { -s $_ ? load_object($_) : $_ } @params;

# Subject-verb-object(s) syntax
my ($obj, $method, @objparams) = @oparams;
pod2usage(-exitval => 2, -verbose => 2) unless defined $obj;

# Help on the given object? Produces list of methods
# Same as what tab-completion from the shell would do
exit(_obj_help($obj)) if $ARGS{help};

# Get result of given method call, or just stringify the object
my @res = $method ? $obj->$method(@objparams) : ("$obj");

# If any of the return value(s) didn't stringify, dump() them instead
my @stringified = map { my $s = "$_"; $s =~ /0x/ ? dump($_) : $s } @res;

# All results of method call, either self-stringified, or dump()ed
print "@stringified";

# Add a newline, if one was not already printed by the given method
print "\n" unless $stringified[-1] =~ /\n$/;

exit;

sub _obj_help {
    my ($obj) = @_;

    # Show the POD page for the packge of the object
    my $pkg = blessed $obj;
    system("perldoc $pkg");

    print "$pkg methods:\n";
    print join("\n", methods($obj)), "\n";

}

