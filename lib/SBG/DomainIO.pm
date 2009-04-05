#!/usr/bin/env perl

=head1 NAME

SBG::DomainIO - Reads/writes L<SBG::Domain> objects, primarily in STAMP format

=head1 SYNOPSIS

 use SBG::DomainIO;

 my $file = "domains.dom";
 my $io = new SBG::DomainIO(file=>"<$file");
 
 # Read all domains from a dom file
 my @doms;
 while (my $dom = $io->read) {
     push @doms, $dom;
 }
 print "Read in " . scalar(@doms) . " domains\n";

 # Write domains
 my $outfile = ">results.dom";
 my $ioout = new SBG::DomainIO(file=>">$outfile");
 foreach my $d (@doms) {
     $ioout->write($d);
 }

Using a specific representation for the L<SBG::Domain> :

 my $io = new SBG::DomainIO(file=>"<$file", representation=>'SBG::CofM');
 my $dom = $io->read;
 # Automatically populated. This is true;
 ok($dom->representation->isa('SBG::CofM'));


=head1 DESCRIPTION

Reads/writes SBG::Domain objects in STAMP format to/from files.

Any existing labels (i.e. STAMP IDs) are not retained. They are overwritten, as to make them unique. STAMP requires them to be unique.

http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

=head1 SEE ALSO

L<SBG::Domain> , L<SBG::IO>

=cut

################################################################################

package SBG::DomainIO;
use Moose;

extends qw/Moose::Object SBG::IO/;

use Module::Load;

use SBG::Types qw/$re_pdb $re_descriptor/;
use SBG::Domain;
use SBG::Transform;
use SBG::Log;

################################################################################
# Accessors

=head2 type

The sub-type to use for any dynamically created objects. Should be
L<SBG::Domain> or a sub-class of that. Default "L<SBG::Domain>" .

=cut
has 'type' => (
    is => 'rw',
    isa => 'ClassName',
    required => 1,
    default => 'SBG::Domain',
    );

# ClassName does not validate if the class isn't already loaded. Preload it here.
before 'type' => sub {
    my ($self, $classname) = @_;
    return unless $classname;
    load($classname);
};


################################################################################
=head2 write

 Function: Writes given domain object to the output stream
 Example : $output->write($dom);
 Returns : $self
 Args    : L<SBG::Domain> - A domain, may contain an L<SBG::Transform>

Prints in STAMP format, along with any transform(s) that have been applied.

 my $outfile = "results.dom";
 my $ioout = new SBG::DomainIO(file=>">$outfile");
 foreach my $d (@doms) {
     $ioout->write($d);
 }

Or, to just convert to a string, without any file I/O:

 my $str = new SBG::DomainIO->write($dom);

=cut
override 'write' => sub {
    my ($self, $dom, %ops) = @_;
    defined($dom) or return;
    my $fh = $self->fh or return;
    my $str = $dom->asstamp(%ops);
    print $fh $str;
    return $self;
}; # write


################################################################################
=head2 read

 Title   : read
 Usage   : my $dom = $io->read();
 Function: Reads the next domain from the stream and make an L<SBG::Domain>
 Example : (see below)
 Returns : An L<SBG::Domain>
 Args    : NA

 # Read all domains from a dom file
 my @doms;
 while (my $dom = $io->read) {
     push @doms, $dom;
 }
 print "Read in " . scalar(@doms) . " domains\n";

NB You can change L<type> in between invocations of L<read>

Any transformation found in the domain block is applied to the domain object
after it is created.

=cut
override 'read' => sub {
    my ($self) = @_;
    my $fh = $self->fh or return;
    while (my $line = <$fh>) {
        chomp $line;
        # Comments and blank lines
        next if $line =~ /^\s*\%/;
        next if $line =~ /^\s*\#/;
        next if $line =~ /^\s*$/;

        # Create/parse new domain header, May not always have a file name
        unless ($line =~ 
                /^(\S*)\s+($re_pdb)(\S*)\s*\{\s*($re_descriptor)(\s*\})?\s*$/) {
            $logger->error("Cannot parse:$line:");
            return;
        }

        # $1 is (possible) file
        # $2 is pdbid
        # $3 is rest of STAMP label
        # $4 is STAMP descriptor, without { }

        my $class = $self->type;
        my $dom = $class->new(pdbid=>$2,descriptor=>$4);
        $dom->file($1) if $1;

        # Header ends, i.e. contains no transformation
        if ($line =~ /\}\s*$/) { 
            return $dom;
        }
        # Parse transformtion
        my $transstr = $self->_read_trans;
        my $trans = new SBG::Transform(string=>$transstr);
        # Since a transformation was found, apply it
        $dom->transform($trans);
        return $dom;
    }
    # End of file
    return;
}; # read



################################################################################
=head2 _read_trans

 Function: Reads a transformation matrix from the internal stream
 Example : my $trans_string = $self->_read_trans();
 Returns : Transformation matrix (3x4) as a 3-lined CSV string
 Args    : 

Returned string is in CSV format, whitespace-separated, including newlines.
Matrix is 3x4 (3 rows, 4 cols).

=cut
sub _read_trans {
    my ($self) = @_;
    my $fh = $self->fh or return;
    my $transstr;
    while (<$fh>) {
        # No homp, keep this as CSV formatted text
#         chomp;
        # Comments and blank lines
        next if /^\s*\%/;
        next if /^\s*$/;
        $transstr .= $_;
        # Stop after a } has been encountered, and remove it
        last if $transstr =~ s/}//g;
    }
    return $transstr;
} # _read_trans




################################################################################
__PACKAGE__->meta->make_immutable;
1;
