#!/usr/bin/env perl

=head1 NAME

SBG::DomainIO - Represents a STAMP domain reader/writer

=head1 SYNOPSIS

 use SBG::DomainIO;

 my $file = "domains.dom";
 my $io = new SBG::DomainIO(-file=>"<$file");
 
 # Read all domains from a dom file
 my @doms;
 while (my $dom = $io->next_domain) {
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

our @EXPORT = qw(pdbc);

use warnings;
use File::Temp qw(tempfile);
use Carp;

use SBG::Domain;
use SBG::Transform;


################################################################################

sub new () {
    my $class = shift;
    # Delegate to parent class
    my $self = new SBG::IO(@_);
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
           -id Print 'pdbid' or 'stampid' (default) as domain label
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
    unless (ref($dom) eq 'SBG::Domain') {
        carp "write() expected SBG::Domain , got: " . ref($dom) . "\n";
        return;
    }
    # Default to on, unless already set
    $o{-newline} = 1 unless defined($o{-newline});
    my $fh = $self->fh;
    $fh = $o{-fh} if defined $o{-fh};
    my $id = $o{-id} || 'stampid';
    my $str = 
        join(" ",
             $dom->file,
             $dom->{$id},
             '{',
             $dom->descriptor,
        );
    my $transstr = $dom->transformation->ascsv;
    # Append any transformation
    $str .= $transstr ? (" \n${transstr}\}") : " \}";
    $str .= "\n" if defined($o{-newline}) && $o{-newline};
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
        unless (/^(\S+)\s+(\S+)\s+\{ ([^}]+)\s+/) {
            carp "Cannot parse:$_:\n";
            return undef;
        }

        my $dom = new SBG::Domain();
        $dom->file($1);
        $dom->file2pdbid(); # Parses out PDB ID from filename
        $dom->stampid($2);
        $dom->descriptor($3);

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
=head2 pdbc

 Title   : pdbc
 Usage   : pdbc('2nn6');
           pdbc('2nn6', 'A', 'B');
           pdbc('2nn6A', 'F');
 Function: Runs STAMP's pdbc and opens its output as the internal input stream.
 Example : my $domio = pdbc('2nn6');
           my $dom = $domio->read();
           # or all in one:
           my $first_dom = pdbc(-pdbid=>'2nn6')->read();
 Returns : $self (success) or undef (failure)
 Args    : @ids - begins with one PDB ID, followed by any number of chain IDs

Depending on the configuration of STAMP, domains may be searched in PQS first.

 my $io = new SBG::DomainIO;
 $io->pdbc('2nn6');
 # Get the first domain (i.e. chain) from 2nn6
 my $dom = $io->read;

=cut
sub pdbc {
    my $str = join("", @_);
    return unless $str;
    my (undef, $path) = tempfile();
    my $cmd;
    $cmd = "pdbc -d $str > ${path}";
    # NB checking system()==0 fails, even when successful
    system($cmd);
    # So, just check that file was written to instead
    unless (-s $path) {
        carp "Failed: $cmd : $!\n";
        return 0;
    }
    return new SBG::DomainIO(-file=>"<$path");

} # pdbc


################################################################################
1;
