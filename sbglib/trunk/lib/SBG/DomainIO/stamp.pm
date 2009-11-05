#!/usr/bin/env perl

=head1 NAME

SBG::DomainIO::stamp - IO for L<SBG::Domain> objects, in STAMP format

=head1 SYNOPSIS

 use SBG::DomainIO::stamp;

 my $file = "domains.dom";
 my $io = new SBG::DomainIO::stamp(file=>"<$file");
 
 # Read all domains from a dom file
 my @doms;
 while (my $dom = $io->read) {
     push @doms, $dom;
 }
 print "Read in " . scalar(@doms) . " domains\n";

 # Write domains
 my $outfile = ">results.dom";
 my $ioout = new SBG::DomainIO::stamp(file=>">$outfile");
 foreach my $d (@doms) {
     $ioout->write($d);
 }

Using a specific representation for the L<SBG::Domain> :

 my $io = new SBG::DomainIO(file=>"<$file", type=>'SBG::Domain::CofM');
 my $dom = $io->read;
 # Automatically populated. This is true;
 ok($dom->representation->isa('SBG::Domain::CofM'));


=head1 DESCRIPTION

Reads/writes SBG::Domain objects in STAMP format to/from files.

Any existing labels (i.e. STAMP IDs) are not retained. They are overwritten, as
STAMP requires them to be unique.

http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

=head1 SEE ALSO

L<SBG::Domain> , L<SBG::IOI>

=cut

################################################################################

package SBG::DomainIO::stamp;
use Moose;

with 'SBG::IOI';

use Carp qw/carp cluck/;

use Moose::Autobox;

use SBG::Domain;
use SBG::TransformIO::stamp;
use SBG::Types qw/$re_pdb $re_descriptor/;



################################################################################
=head2 native

 Function: Prevents writing the L<SBG::TransformI> of the domain
 Example : 
 Returns : Bool
 Args    : Bool
 Default : 0 (i.e. any transformation is printed by default)


=cut
has 'native' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    );


=head2 objtype

The sub-objtype to use for any dynamically created objects. Should implement
L<SBG::DomainI> role. Default "L<SBG::Domain>" .

=cut
# has '+objtype' => (
#     default => 'SBG::Domain',
#     );

sub BUILD {
    my ($self) = @_;
    $self->objtype('SBG::Domain') unless $self->objtype;
}
    

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

NB, if there is no file name, the STAMP header line will begin just with a
space, STAMP handles this to mean that it should look for the file in it's own
list of PDB directories.

=cut
sub write {
    my ($self, @doms) = @_;
    return unless @doms;
    my $fh = $self->fh or return;

    foreach my $dom (@doms) {
        my $str = 
            join(" ",
                 $dom->file  || '',
                 $dom->uniqueid || '',
                 '{',
                 $dom->descriptor || '',
            );
        print $fh $str;
        
        # Append transformation, if any
        my $trans = $dom->transformation;
        # Don't print transformations in native mode
        if ($trans->has_matrix && ! $self->native) {
            print $fh "\n";
            my $io = new SBG::TransformIO::stamp(fh=>$fh);
            $io->write($trans);
            # With a line break before the closing brace here
            print $fh "\}\n";
        } else {
            # With a space before the closing brace here
            print $fh " \}\n";
        }
    } 

    return $self;
} # write


################################################################################
=head2 read

 Title   : read
 Usage   : my $dom = $io->read();
 Function: Reads the next domain from the stream and makes an L<SBG::Domain>
 Example : (see below)
 Returns : An L<SBG::Domain>
 Args    : NA

 # Read all domains from a dom file
 my @doms;
 while (my $dom = $io->read) {
     push @doms, $dom;
 }
 print "Read in " . scalar(@doms) . " domains\n";

NB You can change L<objtype> in between invocations of L<read>

Any transformation found in the domain block is applied to the domain object
after it is created.

Called in an array context, returns an array of all domains in the file

=cut
sub read {
    my ($self) = @_;
    my $fh = $self->fh or return;
    my @doms;
    while (my $line = <$fh>) {
        chomp $line;
        # Comments and blank lines
        next if $line =~ /^\s*\%/;
        next if $line =~ /^\s*\#/;
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*\}/;

        # Create/parse new domain header, May not always have a file name
        unless ($line =~ 
                /^(\S*)\s+(\S+)\s*\{\s*($re_descriptor)(\s*\})?\s*$/) {
            carp("Cannot parse STAMP domain: $line");
            
            # Want an array of domains, then skip to next one, otherwise abort
            wantarray ? next : last;
        }

        my ($file, $pdbid, $descr) = ($1, $2, $3);
        ($pdbid) = $pdbid =~ /^($re_pdb)/;
        # Get only the params that are defined
        my $params = {pdbid=>$pdbid, descriptor=>$descr};
        $params->{file} = $file if $file;
        my $exists = $params->keys->grep(sub{defined $params->{$_}});
        $params = $params->hslice($exists);

        my $objtype = $self->objtype();
        my $dom = $objtype->new(%$params);

        # Parse transformtion, if any
        # Header ends?, i.e. contains no transformation
        if ($line !~ /\}\s*$/) { 
            my $transio = new SBG::TransformIO::stamp(fh=>$self->fh);
            my $transformation = $transio->read;
            # Since a transformation was found, apply it
            $dom->transform($transformation->matrix);
        }

        push @doms, $dom;

        # Stop the loop unless looking for all domains in the file
        last unless wantarray;
    }
    return wantarray ? @doms : shift @doms;

} # read


################################################################################
__PACKAGE__->meta->make_immutable;
no Moose;
1;
