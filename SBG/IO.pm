#!/usr/bin/env perl

=head1 NAME

SBG::IO - Generic I/O (input/output) interface, based off L<Bio::Root::IO>

=head1 SYNOPSIS

 package SpecificKindOfIO;
 use base qw(SBG::IO);

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainIO> , L<SBG::AssemblyIO>

=cut

################################################################################

package SBG::IO;
use Moose;
use Moose::Util::TypeConstraints;

use SBG::Types;

use File::Temp;
use IO::String;
use IO::File;

################################################################################
# Accessors

=head2 fh

=cut
has 'fh' => (
    is => 'rw',
    isa => 'Maybe[FileHandle]',
    handles => [qw/flush close/],
    );


=head2 file

Do I/O on the given file. 
For input: prepend with <
For output prepend with >
For append prepend with >>
See L<IO::File>
=cut
has 'file' => (
    is => 'rw',
    isa => 'Str',
    );


=head2 tempfile

Set this true to just start writing to a tempfile.
Use L<file> to later fetch the name of the created file

=cut
has 'tempfile' => (
    is => 'rw',
    isa => 'Bool',
    trigger => sub { 
        my(undef, $f) = File::Temp::tempfile(); 
        (shift)->file(">$f")
    },
    );


=head2 string

Use IO::String to read/write to/from a string as an input/output stream
=cut
has 'string' => (
    is => 'rw',
    isa => 'Str',
    # When set, open the string as a file handle
    trigger => sub { my $self=shift; $self->fh(new IO::String($self->string)) },
    );


################################################################################
=head2 BUILD

 Function: L<Moose> constructor
 Example :
 Returns : 
 Args    :


=cut
sub BUILD {
    my ($self) = @_;
    my $file = $self->file or return;
    $self->fh(new IO::File($file));
    # Clean file name
    $file =~ s/^[+<>]*//g;
    $self->file($file);
}


################################################################################
=head2 read

 Function: Reads the next object from the stream.
 Example : my $dom = $io->read();
 Returns : 
 Args    : NA

Should generally be overriden by sub-classes.

This simple implementation reads line by line, chomp'ing them as well.

 # Read all lines from a file
 my @lines;
 while (my $l = $io->read) {
     push @lines, $l;
 }
 print "Read in " . scalar(@lines) . " lines\n";

=cut
sub read {
    my ($self) = @_;
    my $fh = $self->fh or return;
    my $l = <$fh>;
    return unless defined $l;
    chomp $l;
    return $l;
} # read


################################################################################
=head2 write

 Function: Writes given object/string to the output stream
 Example : $output->write($object);
 Returns : $self
 Args    : 

Generally this method should be overriden by sub-classes.

A generic implementation is provided here, prints lines, with newline

 my $outfile = "results.txt";
 my $ioout = new SBG::IO(file=>">$outfile");
 foreach my $o (@objects) {
     $ioout->write($o);
 }

=cut
sub write {
    my ($self, @a) = @_;
    @a or return;
    my $fh = $self->fh or return;
    print $fh @a;
    return $self;
} # write


################################################################################
__PACKAGE__->meta->make_immutable;
1;
