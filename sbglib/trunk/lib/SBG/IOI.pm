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



has 'overwrite' => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
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
    isa => 'Maybe[Str]',
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


=head2 _file

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub _file {
    my ($self, $file) = @_;
    $log->debug($file);
    # $file contains mode characters here still
    $file =~ s/^\+//;
    
    my $filename = $file;
    $filename =~ s/^[+<>]*//g;
    # If in write mode, but not overwrite mode, check for existing file
    if ($file =~ /^>/ && -e $filename && ! $self->overwrite) {
        $log->info("Not overwriting existing: ", $filename);
        $self->fh(undef);
        return;
    }
    
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


=head2 tempfile

Set this true to just start writing to a tempfile.

Use L<file> to later fetch the name of the created file.

=cut
has 'tempfile' => (
    is => 'rw',
    isa => 'Bool',
    trigger => \&_tempfile,
    );

=head2 pattern

Pattern to be used for tempfile, e.g.

  myprog_XXXXXX
  myprot_XXXXXX.pdb
  XXXXXXX.png
  
=cut
has 'pattern' => (
    is => 'rw',
    isa => 'Str',
    default => 'sbg_XXXXX',
    );


=head2 suffix

Suffix for a temp file, if necessary
=cut
has 'suffix' => (
    is => 'rw',
    isa => 'Str',
    default => '',
    );
    

=head2 autocleaen

Whether previously created tempfiles should automatically be cleaned up on startup

=cut
has 'autoclean' => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
);


=head2 string

Use IO::String to read/write to/from a string as an input/output stream

Accepts a ScalarRef

=cut
has 'string' => (
    is => 'rw',
    isa => 'ScalarRef',
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
    return unless defined $self->fh && $self->fh->can('flush');
    $self->fh->flush; 
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

Rewinds a read-file handle to the beginnnig of its stream

Fails when the stream is not seekable, e.g. on a pipe, in which case you may 
want to consider L<buffer>

=cut
sub rewind {
    my ($self,) = @_;
    my $fh = $self->fh or return;
    return seek($fh, 0, 0);

} # rewind

=head2
Alias for L<rewind>
=cut
sub reset {
    return rewind(@_);
}


=head2 buffer

If a stream is not seekable, e.g. a pipe, buffer it to make it seekable.

Returns true on success.

=cut
sub buffer {
    my ($self) = @_;
    # Stream is already seekable?
    return 1 if $self->rewind;
    my $fh = $self->fh or return;
    # Suck everything into an in-memory string stream
    my $str = join '', <$fh>;
    $self->string(\$str);
    # Test it
    return $self->rewind;
}


=head2 tell
See perldoc -f tell
=cut
sub tell {
    tell shift->fh;
}


=head2 seek
See perldoc -f seek
=cut
sub seek {
    my ($self, $pos, $whence) = @_;
    my $fh = $self->fh;
    seek $fh, $pos || 0, $whence || 0;
    
}


=head2 index

Track starting position of objects in file.
 
  $io->index;
or
  my $index = $io->index;
  
To then read an object at index $n later:

 for (my $i = 0; $i < @$index; $i++) {
     my $pos = $io->index->[$i];
     $io->seek($pos);
     my $thing = $io->read;
     # ...
 }
  

=cut
has 'index' => (
    is => 'rw',
    isa => 'ArrayRef[Int]',
    lazy_build => 1,
);
sub _build_index {
    my ($self) = @_;
    my $index = [];
    my $i = 0;
    my $tell = $self->tell;
    while (defined(my $thing = $self->read)) {
        $index->[$i] = $tell;
        $tell = $self->tell;
        $i++; 
    }
    return $index;
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
    
    # Whether autoclean has already been run
    our $_autocleaned;
    _clean_tmp($self->pattern) if ! $_autocleaned && $self->autoclean;

    my $pattern = $self->pattern;
    my $suffix = $self->suffix;
    my ($tfh, $tpath) = tempfile($pattern, TMPDIR=>1, SUFFIX=>$suffix);
    # Silly to re-open this, but $self->file() opens it anyway
    $tfh->close();
    $self->file('>' . $tpath);
    $log->debug($self->file);
    return $self;
} # _tempfile


# Clean previously created tmp files
sub _clean_tmp {
    my ($pattern, $ndays) = @_;
    our $_autocleaned;
    $ndays = 7 unless defined($ndays);
    # Remove trailing 'X' mask
    $pattern =~ s/X//g if $pattern;
    # Not using File::Spec->tmpdir() as that might return the current directory
    my $tmpdir = $ENV{TMPDIR} || '/tmp/';
    my $user = $ENV{USER};
    my $cmd = "find $tmpdir";
    $cmd .= " -mtime +$ndays" if $ndays;
    $cmd .= " -user $user" if $user;
    $cmd .= " -name '${pattern}*'" if $pattern;
    $cmd .= " -exec /bin/rm -rf '{}' \\;";
#    $cmd .= " -exec /bin/ls -l '{}' \\;";
    $log->debug($cmd);
    unless(system("$cmd 2>/dev/null") == 0) {
        $log->error("Failed ($?): $cmd");
    }
    $_autocleaned = 1;
}


no Moose::Role;
1;
