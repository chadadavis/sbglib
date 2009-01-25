#!/usr/bin/env perl

=head1 NAME

SBG::DomainIO - Represents a STAMP domain reader/writer

=head1 SYNOPSIS

 use SBG::DomainIO;

 my $file = "domains.dom";
 my $io = new SBG::DomainIO(-file=>"<$file");
 
 # Read all domains from a dom file
 my @doms;
 while (my $dom = $io->read) {
     push @doms, $dom;
 }
 print "Read in " . scalar(@doms) . " domains\n";

 # Write domains
 my $outfile = ">results.dom";
 my $ioout = new SBG::DomainIO(-file=>">$outfile");
 foreach my $d (@doms) {
     $ioout->write($d);
 }


=head1 DESCRIPTION

Represents a single STAMP Domain, being a chain or sub-segment of a protein
chain from a PDB entry.

=head1 SEE ALSO

L<SBG::Domain> , L<SBG::CofM> , L<SBG::IO>

=cut

################################################################################

package SBG::DomainIO;
use SBG::Root -base, -XXX;
use base qw(SBG::IO);


use warnings;
use File::Temp qw(tempfile);

use SBG::Domain;
use SBG::Transform;
use SBG::DB;


################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new SBG::IO(@_);
    return unless $self;
    # And add our ISA spec
    bless $self, $class;
    return $self;
} # new


################################################################################
=head2 write

 Title   : write
 Usage   : $output->write($dom);
 Function: Writes given domain object to the output stream
 Example : (see below)
 Returns : The string that was printed to the stream
 Args    : L<SBG::Domain> - A domain, may contain an L<SBG::Transform>
           -id Print 'pdbid' or 'label' (default) or 'stampid' as label
           -newline If true, also prints a newline after the domain (default)
           -fh another file handle

Prints in STAMP format, along with any transform(s) that have been applied.

 my $outfile = "results.dom";
 my $ioout = new SBG::DomainIO(-file=>">$outfile");
 foreach my $d (@doms) {
     $ioout->write($d);
 }

Or, to just convert to a string, without any file I/O:

 my $str = new SBG::DomainIO->write($dom);

=cut
sub write {
    my $self = shift;
    my ($dom, %o) = @_;
    $dom = want($dom, 'SBG::Domain');
    return unless $dom;

    my $fh = $o{-fh} || $self->fh;
    my $str = $dom->asstamp(%o);
    defined($fh) and print $fh $str;
    return $str;

} # write


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

=cut
sub read {
    my $self = shift;
    my $fh = $self->fh;
    while (<$fh>) {
        chomp;
        # Comments and blank lines
        next if /^\s*\%/;
        next if /^\s*\#/;
        next if /^\s*$/;

        # Create/parse new domain header
        # May not always have a file name
        unless (/^(\S*)\s+(\S+)\s+\{\s*([^}]*)(\s+\})?\s*$/) {
            $logger->error("Cannot parse:$_:");
            return undef;
        }

        my $dom = new SBG::Domain(-file=>$1,-label=>$2,-descriptor=>$3);

        # Header ends, i.e. contains no transformation
        if (/\}\s*$/) { 
            return $dom;
        }

        # Parse transformtion
        my $transstr = $self->_read_trans;
        my $trans = new SBG::Transform(-string=>$transstr);
        $dom->transformation($trans);
        return $dom;
    }
    # End of file
    return undef;
} # read



################################################################################
=head2 _read_trans

 Title   : _read_trans
 Usage   : my $trans_string = $self->_read_trans();
 Function: Reads a transformation matrix from the internal stream
 Example : my $trans_string = $self->_read_trans();
 Returns : Transformation matrix (3x4) as a 3-lined CSV string
 Args    : fh - An openeded file handle to read from, if not the internal one

Returned string is in CSV format, whitespace-separated, including newlines.
Matrix is 3x4 (3 rows, 4 cols).

=cut
sub _read_trans {
    my $self = shift;
    my $fh = shift || $self->fh;
    my $transstr;
    while (<$fh>) {
        # No chomp, keep this as CSV formatted text
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
1;
