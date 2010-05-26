#!/usr/bin/env perl

=head1 NAME

SBG::DomainIO::pdb - IO for L<SBG::Domain> objects, in PDB format

=head1 SYNOPSIS


=head1 DESCRIPTION

Requires the B<transform> program from the STAMP package.

=head1 SEE ALSO

L<SBG::Domain> , L<SBG::IOI> , L<SBG::STAMP>

PDB file format, Version 3.20 (Sept 15, 2008)
 
 http://www.wwpdb.org/documentation/format32/v3.2.html

ATOM records:

 http://www.wwpdb.org/documentation/format32/sect9.html#ATOM

=cut



package SBG::DomainIO::pdb;
use Moose;
use Moose::Autobox;
use Log::Any qw/$log/;

with 'SBG::IOI';
use SBG::Domain;

use PDL::Core qw/pdl ones/;
use PDL::IO::Misc qw/rcols rgrep/;

# Write PDB file by writing a STAMP Dom file and having 'transform' create PDB
use SBG::DomainIO::stamp;

use File::Slurp qw/slurp/;


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


=head2 atom_type

A regular expression for the atom type code, e.g. 'CA' of atoms to read in from
a PDB coordinate file.

NB that e.g. 'CD' would match 'CD1' and 'CD2' unless you say 'CD ' (i.e. with an
explicit trailing space). Likewise, 'C' will match 'CA', 'CB', 'CG', 'CG1',
'CG2', etc

=cut
has 'atom_type' => (
    is => 'rw',
    default =>  ' CA ',
    );


has 'residues' => (
    is => 'ro',
    isa => 'Maybe[ArrayRef[Int]]',
    );


=head2 homogenous

Whether to use homogenous coordinates, whereby each 3D point is extended to 4D with an additional 1. E.g. the point ( 33.434, -23.003, 129.332 ) becomes the 4D point: ( 33.434, -23.003, 129.332, 1).

Default: 1 (enabled)

=cut
has 'homogenous' => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
    );



=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : 

Depends on the B<transform> program from the STAMP suite

http://www.compbio.dundee.ac.uk/Software/Stamp/stamp.html

=cut
sub write {
    my ($self, @doms) = @_;
    return unless @doms;

    # A domain defines a subset of structure, write that to a temp file first
    my $domio = new SBG::DomainIO::stamp(tempfile=>1);
    $domio->write(@doms);
    $domio->flush;
    # Need to redirect to a tempfile, in case stream goes e.g. to stdout
    my $tmp = SBG::IO->new(tempfile=>1);
    my $tmppath = $tmp->file;
    my $cmd = 'transform -g -f ' . $domio->file() . ' -o ' . $tmppath;
    unless (system("$cmd > /dev/null") == 0) {
        warn "$cmd failed: $!";
    }
    $tmp->flush;
    my $fh = $self->fh;
    print $fh slurp($tmppath);

    return $self;
} # write



=head2 read

 Function: 
 Example : 
 Returns : 
 Args    : 

NB This does not set the L<pdbid> or L<descriptor> fields of the L<SBG::DomainI>
object, as these cannot always be determined from a PDB file.

=cut
sub read {
    my ($self) = @_;

    my $coords = $self->coords();

    # What type of Domain to create:
    my $objtype = $self->objtype;
    # Also note the file that was read from
    my $dom = $objtype->new(coords=>$coords, file=>$self->file());
    return $dom;

}


=head2 coords

 Function: Loads atom coordinates from the PDB file into a L<PDL> matrix
 Example : my $atom_coords = $domainio->coords();
 Returns : PDL matrix of 3 columns (or 4, if L<homogenous> set)
 Args    : NA

When called in array context, also returns the array of amino acid 3-letter
codes.

See also L<Bio::SeqUtils> for converting amino acid residue codes between
3-letter and 1-letter versions.

TODO BUG The PDB format is column-defined, not white-space separated. For
certain PDB files, this can break the parsing, if the fields are not white-space
separated.

=cut
sub coords {
    my ($self, ) = @_;
    my $record = 'ATOM  ';
    my $atom = $self->atom_type;
    my $getresids = $self->residues;

    our $cache; 
    $cache ||= {};
    my $cachekey = join '--', $self->file, $self->atom_type;
    $log->debug("Cache key: $cachekey");
    my $cached = $cache->{$cachekey};
    
    # Fields to extract
    my ($resSeq, $x, $y, $z);

    if (defined $cached) {
        $log->debug("Cache hit: $cachekey");
        ($resSeq, $x, $y, $z) = @$cached;
    } else {
        ($resSeq, $x, $y, $z) = rgrep { 
            /^$record..... $atom.... .(....).   (........)(........)(........)/ 
        } $self->file();
        
        # Probably faster to leave it as a PDL, but an Array is more flexible
        $resSeq = [ $resSeq->list ];
        $cache->{$cachekey} =  [ $resSeq, $x, $y, $z ];
    }
    # No atoms matching the given pattern?
    return unless $x->nelem > 0;

    # Subset residue IDs, if given
    if ($getresids) {
        # Create a map from residue ID to array index
        my %resmap = map { $resSeq->[$_] => $_ } 0..@$resSeq-1;
        my $select = $getresids->map(sub{$resmap{$_}});

        $resSeq = $resSeq->slice($select);
        $x = $x->dice($select);
        $y = $y->dice($select);
        $z = $z->dice($select);
    }

    # Columns for X,Y,Z coords, 
    my $mat;
    if ($self->homogenous) {
        # plus a column of 1's (for homogenous coords)
        $mat = pdl([ $x, $y, $z, ones($x->dims) ])->transpose;
    } else {
        $mat = pdl([ $x, $y, $z ])->transpose;
    }

    return $mat;

} # coords



__PACKAGE__->meta->make_immutable;
no Moose;
1;
