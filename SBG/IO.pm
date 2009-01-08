#!/usr/bin/env perl

=head1 NAME

SBG::IO - Generic I/O (input/output) interface, similar to L<Bio::Root::IO>

=head1 SYNOPSIS

 package SpecificKindOfIO;
 use base qw(SBG::IO);

=head1 DESCRIPTION


=head1 SEE ALSO

L<SBG::DomainIO> , L<SBG::AssemblyIO>

=cut

################################################################################

package SBG::IO;
use SBG::Root -base, -XXX;

field 'fh';
field 'file';

use warnings;
use File::Temp qw(tempfile);
use Carp;


################################################################################
=head2 new

 Title   : new
 Usage   : my $input = new SBG::IO(-file=>"<file.dom");
           my $input = new SBG::IO(-fh=>\*STDIN);
 Function: Open a new input stream to a STAMP domain file
 Example : my $input = new SBG::IO(-file=>"<file.dom");
           my $output = new SBG::IO(-file=>">file.dom");
           my $append = new SBG::IO(-file=>">>file.dom");
 Returns : Instance of L<SBG::IO>
 Args    : -file - Path to file to open, including preceeding "<" or ">"
           -fh - An already opened file handle to read from

 
=cut
sub new () {
    my ($class, %o) = @_;
    my $self = { %o };
    bless $self, $class;
    $self->_undash;

    if ($self->file) {
        $self->_open() or return undef;
    }

    return $self;
} # new


################################################################################
=head2 _open

 Title   : _open
 Usage   : $self->_open("<file.dom");
 Function: Opens the internal file handle on the file path given
 Example : $self->_open("<file.dom");
 Returns : $self
 Args    : file - Path to file to open for reading, including the  "<" or ">"

=cut
sub _open {
    my $self = shift;
    my $file = shift || $self->file;
    if ($self->fh) {
        close $self->fh;
        delete $self->{'fh'};
    }
    my $fh;
    unless (open($fh, $file)) {
        carp "Cannot read $file: $!\n";
        return undef;
    }
    $self->fh($fh);
    return $self;
} # _open


################################################################################
=head2 close

 Title   : close
 Usage   : $io->close;
 Function: Closes the internal file handle
 Example : $io->close;
 Returns : result of close()
 Args    : NA

Should not generally need to be explicitly called.

=cut
sub close {
    my $self = shift;
    return $self->fh()->close;
}


################################################################################
=head2 flush

 Title   : flush
 Usage   : $io->flush;
 Function: Flushes the internal file handle
 Example : $io->flush;
 Returns : result of flush()
 Args    : NA

Should not generally need to be explicitly called.

=cut
sub flush {
    my $self = shift;
    return $self->fh()->flush;
}


################################################################################
=head2 write

 Title   : write
 Usage   : $output->write($object);
 Function: Writes given domain object to the output stream
 Example : (see below)
 Returns : The string that was printed to the stream
 Args    : 
           -newline If true, also prints a newline (default)
           -fh another file handle, apart from the internal file handle

Generally this method should be overriden by sub-classes.

A generic implementation is provided here.

 my $outfile = "results.txt";
 my $ioout = new SBG::IO(-file=>">$outfile");
 foreach my $o (@objects) {
     $ioout->write($o);
 }

=cut
sub write {
    my $self = shift;
    my ($obj, %o) = @_;
    return unless $obj;
    # Default to on, unless already set
    $o{-newline} = 1 unless defined($o{-newline});
    my $fh = $self->fh;
    $fh = $o{-fh} if defined $o{-fh};

    defined($fh) and print $fh $obj;
    return $obj;
} # write


################################################################################
=head2 read

 Title   : read
 Usage   : my $dom = $io->read();
 Function: Reads the next object from the stream.
 Example : (see below)
 Returns : 
 Args    : NA

Should generally be overriden by sub-classes.

This simple implementation reads line by line

 # Read all lines from a file
 my @lines;
 while (my $l = $io->read) {
     push @lines, $l;
 }
 print "Read in " . scalar(@lines) . " lines\n";

=cut
sub read {
    my $self = shift;
    my $fh = $self->fh;
    my $l = <$fh>;
    return unless defined $l;
    chomp $l;
    return $l;
} # read



################################################################################
1;
