#!/usr/bin/env perl

=head1 NAME

SBG::DomainIO::cofm - I/O for STAMP's C-of-M (center of mass) format

=head1 SYNOPSIS

use SBG::DomainIO::cofm;
my $io = SBG::DomainIO::cofm->new(file=>'some-file.cofm');
while (my $dom = $io->read) {
    push @doms, $dom;
}

=head1 DESCRIPTION

Though domains are returned one-at-a-time, the format makes it difficult to read
one domain at a time. This module reads the whole file, then simply returns them
one at a time. This results in a bit of overhead reading the first domain, but 
zero overhead reading the remaining domains.

Note that the 'REMARK' line that immediately preceeds a block of 'ATOM' lines is 
space-separated, whereas the 'ATOM' records are a column-based format.
See PDB format spec:

PDB file format, Version 3.20 (Sept 15, 2008)
 http://www.wwpdb.org/documentation/format32/v3.2.html


=head1 SEE ALSO

L<SBG::Domain> , L<SBG::IOI> , L<SBG::STAMP>

PDB file format, Version 3.20 (Sept 15, 2008)
 http://www.wwpdb.org/documentation/format32/v3.2.html

=cut

package SBG::DomainIO::cofm;

use Moose;
with 'SBG::IOI';

use Log::Any qw/$log/;
use Moose::Autobox;
use Text::ParseWords qw/quotewords/;
use POSIX qw/ceil/;
use IO::String;

use SBG::U::List qw/flatten/;
use SBG::TransformIO::stamp;
use SBG::DomainIO::pdb;
use SBG::Types qw/$re_pdb/;
use SBG::Transform::Affine;

=head2 homogenous

Whether to use homogenous coordinates, whereby each 3D point is extended to 4D 
with an additional 1. 
E.g. the point 

 ( 33.434, -23.003, 129.332 ) 

becomes the 4D point: 

 ( 33.434, -23.003, 129.332, 1).

Default: 1 (enabled)

This makes http://en.wikipedia.org/wiki/Affine_transformation easier

=cut

has 'homogenous' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

=head2 renumber_chains

When true, chains output will be renumbered beginning with 'A'.
Default is to to use the native chain ID of the domain written.

If a domain spans multiple chains, then it does not have one unique chain ID.
In that case, you should set renumber_chains.
=cut

has 'renumber_chains' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

=head2 verbose

Write in the same format as 'cofm -v' with information on transformations, etc.
=cut

has 'verbose' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

# Save domains after parsing them. Returning them sequentially. Stream semantics
has '_doms' => (
    is  => 'rw',
    isa => 'Maybe[ArrayRef[SBG::Domain::Sphere]]',
);

# Index into which domain to be returned next. Provides stream semantics.
# This is not a stream parser, but it's for the sake of BioPerl consistency
has '_index' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

sub BUILD {
    my ($self) = @_;
    $self->objtype('SBG::Domain::Sphere') unless defined $self->objtype;
}

=head2 write

 Function: 
 Example : 
 Returns : 
 Args    : L<SBG::Domain::Sphere> object(s)

If multiple domains are given, they are appended in the same file.

If any domain spans multiple chains, use renumber_chains. Otherwise the chain
id '_' will be used for multi-chain domains.

Each point/atom is represented as an Alpha-Carbon of Alanine

Since a sphere is represented as seven points, this only prints the first seven
points of a structure, regardless of how many points it has.

=cut

sub write {
    my ($self, @doms) = @_;
    return unless @doms;
    @doms = flatten(@doms);
    my $fh = $self->fh;

    $self->_verbose_header(@doms) if $self->verbose;

    for (my $i = 0; $i < @doms; $i++) {
        my $dom    = $doms[$i];
        my $domain = $i + 1;

        printf $fh "REMARK Domain %2d Id %4s N = %5d Rg = %7.3f Rmax = %7.3f "
            . "Ro = %8.3f  %8.3f  %8.3f",
            $domain, $dom->id, $dom->length, $dom->radius, 'nan',
            $dom->coords->slice('0:2,0')->list,
            ;

        printf $fh " Assembly = %d", $dom->assembly if defined $dom->assembly;
        printf $fh " Model = %d",    $dom->model    if defined $dom->model;
        print $fh " Classification = ", $dom->classification
            if defined $dom->classification;
        print $fh "\n";

        # Print ATOM records (seven points of the crosshair)
        my $chain =
            $self->renumber_chains ? $self->next_chain : $dom->onechain;
        $chain ||= ' ';
        $self->_print_atoms($dom, $chain);
    }

    return $self;
}    # write

sub next_chain {
    my ($self) = @_;
    my $index = $self->_index;

    # This will be the index (for chain renumbering) next time we're called
    $self->_index($index + 1);

    # TODO index into the array ('A'..'Z','a'..'z',0..9) and mod 62
    chr(ord('A') + ($index % 26));
}

# Print file names and transformations
sub _verbose_header {
    my ($self, @doms) = @_;
    my $fh = $self->fh;

    # STAMP does this debug out, so just copy it
    print $fh "Reading coordinates...\n";

    for (my $i = 0; $i < @doms; $i++) {
        my $dom    = $doms[$i];
        my $domain = $i + 1;
        my $chain =
            $self->renumber_chains ? $self->next_chain : $dom->onechain;
        $chain ||= '_';

        # Header
        printf $fh "Domain %3d %s %s\n", $domain, $dom->file || 'undef',
            $dom->id;

        # Chain counts
        my $descriptor = $dom->descriptor;
        $descriptor = "from $descriptor" if $descriptor =~ /to/; # cofm format
        printf $fh "        %s %d CAs => %4d CAs in total\n",
            $descriptor, $dom->length, $dom->length;
        print $fh "Applying the transformation...\n";
        $self->flush;
        my $out = SBG::TransformIO::stamp->new(fh => $self->fh);

        # Verbose: force even the identity to matrix to be printed, as cofm does
        $out->write($dom->transformation, verbose => 1);
        $out->flush;
        print $fh "     ...to these coordinates.\n";
    }
    $self->_index($self->_index + @doms);
    print $fh "\n\n";
}

# Print seven ATOM records
sub _print_atoms {
    my ($self, $dom, $chain) = @_;
    my $fh = $self->fh;

    # This is a column-based format (defined by the PDB specification)
    my $rows = $dom->coords->dim(1);
    for (my $j = 0; $j < $rows; $j++) {

        # Vary the temparature, to be able to visualize relative orientation
        # But only display every second one, to be able to identify +x vs -x
        # Temperatures: 0, 4, 0, 12, 0, 20, 0
        my $temp = ($j % 2) * 4 * $j;

        printf $fh '%-6s' .      # Record
            '%5d' .              # Atom serial num
            ' ' . '%-4s' .       # Atom name (default 'CA')
            '%1s' .              # Alt location
            '%3s' .              # Res name (default 'ALA')
            ' ' . '%1s' .        # Chain
            '%4d' .              # Residue sequence number
            '%1s' .              # Residue insertion code
            '   ' . '%8.3f' .    # X coordinate
            '%8.3f' .            # Y coordinate
            '%8.3f' .            # Z coordinate
            '%6.2f' .            # B-Occupancy
            '%6.2f' .            # Temperature factor
            "\n",
            'ATOM', ceil($j / 2.0), ' CA ', ' ', 'ALA', $chain,
            ceil($j / 2.0), ' ',
            $dom->coords->slice("0:2,$j")->list, 1.0, $temp;
    }
}

=head2 read

 Function: 
 Example : 
 Returns : 
 Args    : 


When cofm is run with -v (verbose) option, file name and lengths are also given,
as well as the STAMP descriptor defining the domain range.

With or without the -v option, each domain will have one 'REMARK Domain' line
This preceedes the block of ATOM records for each domain, e.g.:

 REMARK Domain 1 Id 1li4a N = 860 Rg = 34.441 Rmax = 58.412 Ro = 44.760 0.000 85.323


Finally, all the ATOM records are read in quickly in one big PDL block, which 
is then indexed based on the fact that each center of mass contains 7 points


=cut

sub read {
    my ($self) = @_;

    # Make sure the input is buffered, to be able to seek() on it,
    # Necessary, because we have to read it twice, once for atoms,
    # once for header metadata
    $self->buffer() or return;

    # Which dom in the 'stream' to return next
    my $index = $self->_index;
    if (defined $self->_doms) {
        return unless $index < $self->_doms->length;
        $self->_index($index + 1);
        return $self->_doms->[$index];
    }

    # Verbose headers are first
    # The each domain has one REMARK line followed by ATOM lines, alternating
    my $doms = $self->_read_header();

    # Reset the stream, then read the ATOM lines
    $self->rewind();

    # Read all atoms into a single structure
    my $atoms_in = SBG::DomainIO::pdb->new(fh => $self->fh);
    my $all_atoms = $atoms_in->read()->coords;

    # Since this is a cofm file, each domain has exactly seven (CA) atoms
    for (my $i = 0; $i < @$doms; $i++) {
        my $dom   = $doms->[$i];
        my $start = 7 * $i;

        # TODO potential optimization
        # Ignore redundant atoms if they haven't been oriented
        #        my $end = $dom->transformation->has_matrix ? $start + 6 : $start + 0;
        my $end = $start + 6;

        # Column-major indexing (rows in the second dimension)
        $dom->coords($all_atoms->slice(",$start:$end"));
    }
    $self->_doms($doms);
    while (defined($self->_doms) && $index < $self->_doms->length) {
        $self->_index($index + 1);
        return $self->_doms->[$index];
    }
}

=head2 _read_header

 Function: 
 Example : 
 Returns : 
 Args    : 

This input exists when cofm is run with the -v (verbose) option

Examples:

Examples:
Single chain:

 Domain   1 /g/russell3/pqs/1li4.mmol 1li4A
        chain A 430 CAs =>  430 CAs in total

Multiple chains:
 Domain   1 /g/russell3/pqs/1li4.mmol 1li4A
        chain A 430 CAs  chain B 430 CAs =>  860 CAs in total

Segment:
 Domain   1 /g/russell3/pqs/1li4.mmol 1li4A-single
        from A    3   to A  189   187 CAs =>  187 CAs in total

Multiple segments:
 Domain   1 /g/russell3/pqs/1li4.mmol 1li4A-double
        from A    3   to A  189   187 CAs  from A  353   to A  432    80 CAs =>  267 CAs in total

With insertion codes:
Domain   1 /usr/local/data/pdb/pdb2frq.ent.gz 2frqB
        from B  100   to B  131 A  33 CAs =>   33 CAs in total


With transformation matrix:
 Domain   1 /usr/local/data/pdb/pdb2frq.ent.gz 2frqB
        from B  100   to B  131 A  33 CAs =>   33 CAs in total
 Applying the transformation... 
   1.00000    0.00000    0.00000             0.00000 
   0.00000    1.00000    0.00000             0.00000 
   0.00000    0.00000    1.00000             0.00000 
      ...to these coordinates.


=cut

sub _read_header {
    my ($self) = @_;
    my $fh = $self->fh;
    return unless $fh;

    # What type of Domain to create:
    my $objtype = $self->objtype;

    my $doms = [undef];

    # All header lines come first, if any
    # These have to be matched to one another by the domain counter (Int, from 1)
    my $index;
    while (my $line = <$fh>) {
        if ($line =~ /^Domain\s+(\d+)\s+(\S+)\s*(\S+)?/i) {

            # Found a new domain, this line has the file name
            $index = $1;    # 1-based index
            my $dom = $objtype->new;

            # Also note the file that was read from
            $dom->file($2) if defined $2 && -r $2;
            $doms->[ $index - 1 ] = $dom;
            $dom->label($3) if defined $3;
        }
        elsif ($line =~ /\s+(.*?)=>\s+\d+\s+CAs in total$/) {

            # One of: 'from A 33 _ to A 566 B' or 'CHAIN X' or 'all residues'
            my @matches = $1
                =~ /from\s+(.*?)\s+\d+ CAs|(chain .)|(all residues)\s+\d+ CAs/ig;
            @matches = grep {defined} @matches;
            my $descriptor = "@matches";
            $descriptor =~ s/all residues/ALL/;

            # cofm uses lowercase, but STAMP uses uppercase
            $descriptor =~ s/chain/CHAIN/g;
            my $dom = $doms->[ $index - 1 ];
            $dom->descriptor($descriptor);
        }
        elsif ($line =~ /^Applying the transformation/i) {

            # Keep track of any non-native transformation matrices
            my $transio = SBG::TransformIO::stamp->new(fh => $self->fh);
            my $transformation = $transio->read;
            $doms->[ $index - 1 ]->transformation($transformation);
        }
        elsif ($line =~ /^REMARK((\s+\S+){4})/i) {

            # The first 2 fields (4 tokens) don't use an =
            my %fields = split ' ', $1;
            my $rest = $';

            # The remaining fields use an = and values may contain spaces
            # Which is why this regex has to be so ugly
            # Find words after the = as long as one of those isn't followed by =
            # So, (thing=value) and (thing = one two three) both work
            while ($rest =~ /(\S+)\s*=\s*(\S+(?:\s+\S+\b(?!\s*=))*)/g) {
                $fields{$1} = $2;
            }

            $index = $fields{Domain};
            $doms->[ $index - 1 ] = $objtype->new
                unless defined $doms->[ $index - 1 ];
            my $dom = $doms->[ $index - 1 ];
            $dom->length($fields{N});
            $dom->radius($fields{Rg});
            $dom->radius_max($fields{Rmax});
            $dom->assembly($fields{Assembly}) if defined $fields{Assembly};
            $dom->model($fields{Model})       if defined $fields{Model};
            $dom->classification($fields{Classification})
                if defined $fields{Classification};

            # If the Id looks like it begins with a PDB ID, parse it out
            if ($fields{Id} =~ /^($re_pdb)/) { $dom->pdbid($1) }
        }
    }    # while
    return $doms;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
