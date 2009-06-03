#!/usr/bin/env perl

=head1 NAME

SBG::IOI - Generic I/O (input/output) interface, inspired by L<Bio::Root::IO>

=head1 SYNOPSIS

 package SpecificKindOfIO;
 use Moose;
 with 'SBG::IOI';

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::IO> generic implementation

=cut

################################################################################

package SBG::IOI;
use Moose::Role;
use Moose::Util::TypeConstraints;

use File::Temp qw/tempfile/;
use IO::String;
use IO::File;
use Module::Load;

use SBG::U::Log;
use SBG::U::Config qw/config/;


################################################################################
# Accessors

=head2 fh

Needs to be a file handle, e.g. L<IO::String>, L<File::Temp>, or any native Perl
file handle, e.g.

 $io = new SBG::IO(fh=>\*STDOUT, type=>'My::Class');
 $io->write($some_object);

 $io = new SBG::IO(fh=>\*STDIN);
 $some_object = $io->read; # Should be an instance of My::Class

=cut
has 'fh' => (
    is => 'rw',
    handles => [qw/close eof flush print printf say autoflush opened /],
    default => sub { \*STDOUT },
    );


=head2 file

Do I/O on the given file. 
For input: prepend with < (default, i.e. optional)
For output prepend with >
For append prepend with >>

See L<IO::File>

Existing files are overwritten (truncated) by the > modifier.

=cut
has 'file' => (
    is => 'rw',
    isa => 'Str',
    trigger => \&_file,
    );

# Parameter cleansing, store the raw value, but return the clean value
# Remove mode operators from file path prefix
around 'file' => sub {
    my ($orig, $self, @args) = @_;
    # Call original method, opening the file, if requested
    my $val = $self->$orig(@args);
    # Remove mode modifiers, to get just the path back
    $val =~ s/^[+<>]*//g;
    return $val;
};


=head2 tempfile

Set this true to just start writing to a tempfile.

Use L<file> to later fetch the name of the created file.

=cut
has 'tempfile' => (
    is => 'rw',
    isa => 'Bool',
    trigger => \&_tempfile,
    );


=head2 string

Use IO::String to read/write to/from a string as an input/output stream

=cut
has 'string' => (
    is => 'rw',
    isa => 'Str',
    trigger => \&_string,
    );


=head2 type

The sub-type to use for any objects dynamically created by B<read>

=cut
has 'type' => (
    is => 'rw',
    isa => 'ClassName',
    );

# ClassName does not validate if the class isn't already loaded. Preload it here
before 'type' => sub {
    my ($self, $classname) = @_;
    return unless $classname;
    Module::Load::load($classname);
};


################################################################################
=head2 read

 Function: Reads the next object from the stream.
 Example : my $obj = $io->read();
 Returns : new instance of subclass defined by B<type>
 Args    : NA

=cut
requires 'read';


################################################################################
=head2 write

 Function: Writes given object/string to the output stream
 Example : $io->write($object);
 Returns : $self
 Args    : 

=cut
requires 'write';


################################################################################
=head2 _file

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub _file {
    my ($self, $file) = @_;
    # $file contains mode characters here still
    $self->fh(new IO::File($file));
    unless ($self->fh) {
        log()->error("Cannot open: $file");
        return;
    }
    return $self;
}


################################################################################
=head2 _string

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub _string { 
    my ($self) = @_;
    $self->fh(new IO::String($self->string));
    return $self;
}



################################################################################
=head2 _tempfile

 Function: Sets the output to be a tempfile, whose path can also be retrieved
 Example : 
 Returns : 
 Args    : 


=cut
sub _tempfile {
    my ($self,) = @_;

    my $tmpdir = config->val(qw/tmp tmpdir/) || $ENV{TMPDIR} || '/tmp';
    my ($tfh, $tpath) = tempfile(DIR=>$tmpdir);
    # Silly to re-open this, but $self->file() opens it anyway
    $tfh->close();
    $self->file('>' . $tpath);
    log()->trace($self->file);
    return $self;
} # _tempfile



################################################################################
no Moose::Role;
1;
