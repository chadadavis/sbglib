#!/usr/bin/env perl

=head1 NAME

SBG::IO - Generic I/O (input/output) module, 

=head1 SYNOPSIS

 use SBG::IO;


=head1 DESCRIPTION


=head1 SEE ALSO

Interface L<SBG::IOI>

=cut



package SBG::IO;
use Moose;
with qw/SBG::IOI/;



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
    return if defined $self->file && -e $self->file && ! $self->overwrite;
    print $fh @a;
    return $self;
} # write



__PACKAGE__->meta->make_immutable(inline_constructor=>0);
no Moose;
1;
