#!/usr/bin/env perl

=head1 NAME

SBG::DomainI - Simplified domain representation (a L<Moose::Role>)

=head1 SYNOPSIS

 package SBG::DomaiN::MyDomainImplementation;
 use Moose;
 with 'SBG::DomainI'; 


=head1 DESCRIPTION


A Domain is defined, according to STAMP, as one of:
1) ALL : All chains in a structure entry
2) CHAIN X : A complete chain, for some X in [A-Za-z0-9_]
3) B 12 _ to B 233 _ : An arbitrary segment of a chain
4) Any number of combinations of 2) and 3), e.g. 
  CHAIN B A 3 _ to A 89 _ C 232 _ to C 321 _
 

If your class uses this role, it will need to define all the methods below.

=head1 SEE ALSO

L<SBG::Domain>, L<Moose::Role>

http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

=cut

package SBG::DomainI;
use Moose::Role;

with 'SBG::Role::Clonable';
with 'SBG::Role::Dumpable';
with 'SBG::Role::Scorable';
with 'SBG::Role::Storable';
with 'SBG::Role::Transformable';
with 'SBG::Role::Writable';

# You will need to redefine this (i.e. copy) it to implementing classes
# The methods themselves will be consumed via this role, however.
# I.e. just the overload needs to be explicitly redfined in implementing classes.
# use overload (
#     '""' => \&stringify,
#     '==' => \&equal,
#     fallback => 1,
#     );

use Moose::Autobox;

# Get address of a reference
use Scalar::Util qw(refaddr);
use Module::Load;
use File::Basename qw/basename/;

use PDL::Lite;
use PDL::Core qw/pdl/;
use PDL::Basic qw/transpose/;

# Default transform type
use SBG::Transform::Affine;
# Read smtry operators
use SBG::TransformIO::smtry;

use SBG::U::RMSD;
use SBG::Run::pdbseq;

# Some regexs for parsing PDB IDs and descriptors
use SBG::Types qw/$re_chain $re_chain_seg/;

=head2 pdbid

PDB identifier, from which this domain comes. 
Will be coerced to lowercase. 

=cut

has 'pdbid' => (
	is       => 'rw',
	isa      => 'Maybe[SBG.PDBID]',
	required => 0,

	# Coerce to lowercase
	coerce => 1,
);

=head2 descriptor

Which chains and residues are contained within this domain. This may be a single
chain, multiple chains, segments of a chain, or segments from separate chains
together.

STAMP descriptor, Examples:

ALL
A 125 _ to A 555 _
CHAIN A
CHAIN A B 12 _ to B 211 _
B 33 _ to B 99 _ CHAIN A

See L<SBG::Types>
=cut

has 'descriptor' => (
	is      => 'rw',
	isa     => 'SBG.Descriptor',
	default => 'ALL',

	# Coerce from 'Str', defined in SBG::Types
	coerce => 1,
);

=head2 description

 Function: 
 Example : 
 Returns : 
 Args    : 

Annotation of this domain, functional description text

=cut

has 'description' => (
	is  => 'rw',
	isa => 'Str',
);

=head2 assembly

 Function: 
 Example : 
 Returns : 
 Args    : 

Which PDB biounit assembly this domain is contained in

1-based counting, if defined

=cut

has 'assembly' => (
	is      => 'rw',
	isa     => 'Maybe[Int]',
);

=head2 model

 Function: 
 Example : 
 Returns : 
 Args    : 


Which PDB biounit model in the assembly

1-based counting, if assembly defined

NB Has nothing to do with SBG::Model

=cut

has 'model' => (
	is      => 'rw',
	isa     => 'Maybe[Int]',
);

=head2 entity

 Function: 
 Example : 
 Returns : 
 Args    : 

entity.id field of TransDB

TODO should be a subclass

=cut

has 'entity' => (
	is  => 'rw',
	isa => 'Str',
);


=head2 file

Path to PDB/MMol file.

This can be blank and STAMP will look for thas file based on its ID, which must
begin with the PDB ID for the domain. 
This also requires that the STAMPDIR environment variable be set

Files from biounit cannot be automatically found. For those, it is necessary to set the base directory via biounit_base.

NB In filenames, the PDB ID is expected to always be lowercase

=cut

has 'file' => (
	is      => 'rw',
	isa     => 'Maybe[SBG.File]',
	clearer => 'clear_file',
	lazy_build => 1,
);
sub _build_file {
	my ($self) = @_;
	# The PDB ID in filename is expected to be lowercase
	my $pdbid = lc $self->pdbid;
	return unless $pdbid;
	my $str = $pdbid;
	# Append e.g. '-2' for 2nd assembly
	$str .= '-' . $self->assembly if $self->assembly;
	# Append model number in the biounit assembly
	$str .= '-' . $self->model if $self->model;
	# If PDB files are stored hierarchically e.g. pdb/xy/1xyz.pdb
	my $subdir = substr($pdbid, 1, 2);
	my $paths = $self->_path_specs or return;
	foreach my $path (@$paths) {
		my ($base, $prefix, $suffix) = @$path;
		# An underscore means no prefix / suffix
		$prefix =~ s/_//;
		$suffix =~ s/_//;
		my $filename = $prefix . $str . $suffix;
		my $filepath;
		# Try flat directory structure
		$filepath = $base . '/' . $filename;
		return $filepath if -f $filepath;
		# Try hierarchical directories
		$filepath = $base .'/' . $subdir . '/' . $filename;
		return $filepath if -f $filepath;
	}
	return;
}


has '_path_specs' => (
	is => 'rw',
	isa => 'Maybe[ArrayRef]',
	lazy_build => 1,
	);
	
	
sub _build__path_specs {
	our @paths;
	return \@paths if @paths;
	return unless $ENV{STAMPDIR};
	my $pdb_directories = $ENV{STAMPDIR} . '/pdb.directories';
	my $fh;
	open $fh, $pdb_directories;
	while (<$fh>) {
		my @values = split ' ';
		push @paths, [ @values ];
	}
	close $fh;
	return \@paths;
}


=head2 length

 Function: 
 Example : 
 Returns : 
 Args    : 

Number of AA residues in the entire domain, including residues from multiple
chains, if the domain spans multiple chains.

NB this is not simply the difference between the starting residue ID and the 
ending residue ID as PDB entry may skip residues.

=cut

has 'length' => (
	is  => 'rw',
	isa => 'Int',
	lazy_build => 1,
);

sub _build_length {
	my ($self) = @_;
	# TODO DES use SBG::Domain::Atoms and then count the dims of ->coords
	return 0;
}


=head2 transformation

The L<SBG::Transform> describing any applied transformations

This attribute is imported automatically in consuming classes. But you may
override it.

This defines where the domain is in space at any point in time.
=cut

has 'transformation' => (
	is       => 'rw',
	does     => 'SBG::TransformI',
	required => 1,
	default  => sub { new SBG::Transform::Affine },
);

=head2 coords

X,Y,Z coordinates of all the atoms in the domain.

This is generally a reduced representation of the domain, depending on which
subclass of L<SBG::DomainI> is being used. This might be the C-alpha atoms, or
simply, the centre of mass of a domain. Of course, all atoms may be used, at a
significant performance penalty.

Note that class detection is based on spherical representation of a domain.

Set of homogenous 4D coordinates. The 4th dimension of each point must be 1.

TODO: considering coercing coordinates from 3D to 4D here, for convenience

=cut

has 'coords' => (
	is         => 'rw',
	isa        => 'PDL',
	lazy_build => 1,
);

# Default: a single point at 0,0,0
# Final 1 is to create homogenous coordinate in 4D for affine transformation
sub _build_coords {
	return pdl [ [ 0, 0, 0, 1 ] ];
}


=head2 symmops

Symmetry operator matrices, defined in PDB file

=cut
has 'symops' => (
    is => 'rw',
    isa => 'ArrayRef[SBG::Transform::Affine]',
    lazy_build => 1,
    );
sub _build_symops {
	my ($self) = @_;
	my $file = $self->file;
	my $io = SBG::TransformIO::smtry->new(file=>$self->file);
	my $transformations = [];
	while (my $trans = $io->read) {
        $transformations->push($trans);
	}
	return $transformations;
	
}    
    

=head2 centroid

 Function: 
 Example : 
 Returns : 
 Args    : 

Center of mass of all X,Y,Z coordinates of the reduced representation.

=cut

requires 'centroid';

=head2 overlap

 Function: Extent to which two domains clash in space
 Example : 
 Returns : 
 Args    : 

=cut

requires 'overlap';

# Implicitly thread-safe: cloning (i.e. threading) is disallowed.
# This prevents double free bugs. Spawned thread only has undef references then.
# See man perlmod
sub CLONE_SKIP { 1 }

=head2 rmsd

 Function:
 Example :
 Returns : 
 Args    :

RMSD between the points of B<$self>'s representation and B<$other>

=cut

sub rmsd {
	my ( $self, $other ) = @_;
	return SBG::U::RMSD::rmsd( $self->coords, $other->coords );
}

=head2 transform

 Function: 
 Example : $self->transform($some_4x4_PDL_matrix);
 Returns : $self (not a new instance)
 Args    : L<PDL> Affine transformation matrix (See L<SBG::Transform::Affine>)

This also updates the cumulative L<transformation> (since the original
coordinates).

=cut

sub transform {
	my ( $self, $matrix ) = @_;
	return $self unless defined($matrix);

	# Transform coords
	my $coords = $self->coords;
	$coords .= transpose( $matrix x transpose($coords) );

	# Update the cumulative transformation
	# I.e. transform the current transformation by the given matrix
	$self->transformation->transform($matrix);

	return $self;

}    # transform

=head2 wholechain

 Function:
 Example :
 Returns : Whether descriptor corresponds to one-and-only-one full chain
 Args    :

True when this domain consists of only one chain, and that entire chain

See als L<fromchain>
=cut

sub wholechain {
	my ($self) = @_;
	my ($chain) = $self->descriptor =~ /^\s*CHAIN\s+(.)\s*$/i;
	return $chain;
}

=head2 id

Combines the PDBID, or filename, and the descriptor into a short ID.

 2nn6 { A 13 _ to A 122 _ } => 2nn6A13_A122_

 mystructure.pdb { CHAIN A } => mystructureB
 
First four characters are the PDB ID, or the basename of the file when on PDB

A domain descriptor is then appended.

NB if no PDB ID is present, the filename should be unique.

See also L<uniqueid>

=cut

sub id {
	my ($self) = @_;
	my $str;
	if ($self->pdbid) {
		$str = $self->pdbid;
		$str .= '-' . $self->assembly . '-' if $self->assembly;
		$str .= $self->model . '-' if $self->model;
	} elsif ($self->file) {
		# Or use the filename, if this is not a PDB entry
		$str = basename($self->file ,qw/.pdb .ent .pdb.gz .ent.gz/);
	}	
	$str .= $self->_descriptor_short if $self->_descriptor_short;
	return $str;
}

=head2 uniqueid

A unique ID, for use with STAMP.

In addition to L<id>, a unique ID is appended.

NB If the L<SBG::Domain> contains a L<SBG::Transform>, the unique ID will be
different after read/write or after serializing and deserializing. This is
because the ID is simply the memory address of the Transform. It will be
different for two copies of the same transform.

=cut

sub uniqueid {
	my ($self) = @_;
	my $str = $self->id();

	# Get the memory address of some relevant attribute object,
	my $rep = $self;
	$str .= $rep ? sprintf( "-0x%x", refaddr($rep) ) : '';
	return $str;
}

=head2 stringify

 Function: Resturns a string representation of this domain.
 Example : print "Domain is $dom"; # automatic stringification
 Returns : string
 Args    : NA

=cut

sub stringify {
	my ($self) = @_;
	return $self->id;
}

=head2 equal

 Function:
 Example :
 Returns : 
 Args    :

Are two domains effectively equal.

Does not check B<coords> for equality as that is a function of the
implementation, and not what is being represented.

=cut

sub equal {
	my ( $self, $other ) = @_;

	return 0 unless defined $other;

	# Equal if pointing to same underlying object
	return 1 if refaddr($self) == refaddr($other);

	# Fields, from most general to more specific
	my @fields = qw/pdbid assembly model descriptor file/;
	foreach (@fields) {

		# If both undefined, then they are not necessarily unequal
		next if !defined( $self->$_ ) && !defined( $other->$_ );

		# If one is defined but the other undefined, they are unequal
		return 0 if defined( $self->$_ ) ^ defined( $other->$_ );

		# Here both are defined, are they equal
		return 0 if $self->$_ ne $other->$_;
	}

	# Assume equal if metadata is same and transformations are same
	my $transeq = $self->transformation == $other->transformation;

	return $transeq;

}    # equal

=head2 _descriptor_short

 Function:
 Example :
 Returns : 
 Args    :

Converts: first line to second:

 'B 234 _ to B 333 _ CHAIN D E 5 _ to E 123 _'
 'B234_B333_DE5_E123_'

=cut

sub _descriptor_short {
	my ($self) = @_;
	my $descriptor = $self->descriptor;
	$descriptor =~ s/CHAIN//g;
	$descriptor =~ s/to//gi;
	$descriptor =~ s/\s+//g;
	return $descriptor;
}

=head2 seq

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut

sub seq {
	my ( $self, ) = @_;
	my $seq = SBG::Run::pdbseq::pdbseq($self);
	return $seq;

}    # seq

no Moose::Role;
1;

