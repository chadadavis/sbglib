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



package SBG::IOI;
use Moose::Role;
use Moose::Util::TypeConstraints;

use File::Temp qw/tempfile/;
use IO::String;
use IO::File;
use IO::Compress::Gzip;
use IO::Uncompress::Gunzip;
use Module::Load;
use Log::Any qw/$log/;



# Accessors

=head2 fh

Needs to be a file handle, e.g. L<IO::String>, L<File::Temp>, or any native Perl
file handle, e.g.

 $io = new SBG::IO(fh=>\*STDOUT, objtype=>'My::Class');
 $io->write($some_object);

 $io = new SBG::IO(fh=>\*STDIN);
 $some_object = $io->read; # Should be an instance of My::Class

=cut
has 'fh' => (
    is => 'rw',
    # Cannot delegate, as we might just have a GLOB sometimes
#     handles => [qw/flush close/],
    default => sub { \*STDOUT },
    );



=head2 compressed

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has 'compressed' => (
    is => 'rw',
    isa => 'Bool',
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
    return unless $val;
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


=head2 objtype

The sub-objtype to use for any objects dynamically created by B<read>

=cut
has 'objtype' => (
    is => 'rw',
    isa => 'ClassName',
    );

# ClassName does not validate if the class isn't already loaded. Preload it here
before 'objtype' => sub {
    my ($self, $classname) = @_;
    return unless $classname;
    Module::Load::load($classname);
};



=head2 flush

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub flush {
    my ($self,) = @_;
    $self->fh->flush if $self->fh->can('flush');
} # flush



=head2 close

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub close {
    my ($self,) = @_;
    close $self->fh;
} # close



=head2 read

 Function: Reads the next object from the stream.
 Example : my $obj = $io->read();
 Returns : new instance of subclass defined by B<objtype>
 Args    : NA

=cut
requires 'read';



=head2 read_all

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub read_all {
    my ($self,) = @_;
    my @results;
    while (my $res = $self->read) {
        push @results, $res;
    }
    return wantarray? @results : \@results;

} # read_all



=head2 write

 Function: Writes given object/string to the output stream
 Example : $io->write($object);
 Returns : $self
 Args    : 

=cut
requires 'write';



=head2 rewind

 Function: Rewinds a read-file handle to the beginnnig of its stream
 Example : 
 Returns : 
 Args    : 


=cut
sub rewind {
    my ($self,) = @_;
    my $fh = $self->fh or return;
    return seek($fh, 0, 0);

} # rewind
sub reset {
    return rewind(@_);
}

        


=head2 _file

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub _file {
    my ($self, $file) = @_;
    # $file contains mode characters here still
    $file =~ s/^\+//;
    
    if ($self->compressed || $file =~ /\.gz$/) {
    	if ($file =~ /^>/) {
    		# Write to a gzip compressed stream
            $file =~ s/^[>]+//;
            $self->fh(IO::Compress::Gzip->new($file));
    	} else {
    		# Read from gunzip uncompressed stream
    		$file =~ s/^[<]+//g;
    		$self->fh(IO::Uncompress::Gunzip->new($file));
    	}
    } else {
        $self->fh(IO::File->new($file));
    }

    unless ($self->fh) {
        $log->error("Cannot open: $file");
        return;
    }
    return $self;
}



=head2 _string

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub _string { 
    my ($self) = @_;
    $self->fh(IO::String->new($self->string));
    return $self;
}




=head2 _tempfile

 Function: Sets the output to be a tempfile, whose path can also be retrieved
 Example : 
 Returns : 
 Args    : 


=cut
sub _tempfile {
    my ($self,) = @_;

    my ($tfh, $tpath) = tempfile('sbg_XXXXX', TMPDIR=>1);
    # Silly to re-open this, but $self->file() opens it anyway
    $tfh->close();
    $self->file('>' . $tpath);
    $log->debug($self->file);
    return $self;
} # _tempfile




no Moose::Role;
1;
