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

################################################################################

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
use overload (
    '""' => 'stringify',
    '==' => 'equal',
    fallback => 1,
    );


# Get address of a reference
use Scalar::Util qw(refaddr);
use Module::Load;
use File::Basename qw/basename/;


use PDL::Lite;
use PDL::Core qw/pdl/;
use PDL::Basic qw/transpose/;

use SBG::TransformI;
# Default transform type
use SBG::Transform::Affine;
use SBG::U::RMSD;

# Some regexs for parsing PDB IDs and descriptors
use SBG::Types qw/$re_chain $re_chain_seg/;



################################################################################
=head2 pdbid

PDB identifier, from which this domain comes. 
Will be coerced to lowercase. 

=cut
has 'pdbid' => (
    is => 'rw',
    isa => 'SBG.PDBID',
    required => 0,
    # Coerce to lowercase
    coerce => 1,
    );


################################################################################
=head2 descriptor

STAMP descriptor, Examples:

ALL
A 125 _ to A 555 _
CHAIN A
CHAIN A B 12 _ to B 211 _
B 33 _ to B 99 _ CHAIN A

See L<SBG::Types>
=cut
has 'descriptor' => (
    is => 'rw',
    isa => 'SBG.Descriptor',
    default => 'ALL',
    # Coerce from 'Str', defined in SBG::Types
    coerce => 1,
    );


has 'description' => (
    is => 'rw',
    isa => 'Str',
    );


# entity.id field of TransDB
has 'entity' => (
    is => 'rw',
    isa => 'Str',
    );


################################################################################
=head2 file

Path to PDB/MMol file.

This can be blank and STAMP will look for thas file based on its ID, which must
begin with the PDB ID for the domain.

=cut
has 'file' => (
    is => 'rw',
    isa => 'SBG.File',
    clearer => 'clear_file',
    );


################################################################################
=head2 length

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
has 'length' => (
    is => 'rw',
    isa => 'Int',
    );


################################################################################
=head2 transformation

The L<SBG::Transform> describing any applied transformations

This attribute is imported automatically in consuming classes. But you may
override it.

This defines where the domain is in space at any point in time.
=cut
has 'transformation' => (
    is => 'rw',
    does => 'SBG::TransformI',
    required => 1,
    default => sub { new SBG::Transform::Affine },
    );


################################################################################
=head2 coords

Set of homogenous 4D coordinates. The 4th dimension of each point must be 1.

TODO: considering coercing coordinates from 3D to 4D here, for convenience

=cut
has 'coords' => (
    is => 'rw',
    isa => 'PDL',
    lazy_build => 1,
    );
# Default: a single point at 0,0,0
# Final 1 is to create homogenous coordinate in 4D for affine transformation
sub _build_coords {
    return pdl [ [ 0,0,0,1 ] ];
}


################################################################################
=head2 centroid

 Function: 
 Example : 
 Returns : 
 Args    : 

Center of mass of all coordinates;

=cut
requires 'centroid';


################################################################################
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


################################################################################
=head2 rmsd

 Function:
 Example :
 Returns : 
 Args    :

RMSD between the points of B<$self>'s representation and B<$other>

=cut
sub rmsd {
    my ($self, $other) = @_;
    return SBG::U::RMSD::rmsd($self->coords, $other->coords);
}


################################################################################
=head2 transform

 Function: 
 Example : $self->transform($some_4x4_PDL_matrix);
 Returns : $self (not a new instance)
 Args    : L<PDL> Affine transformation matrix (See L<SBG::Transform::Affine>)

This also updates the cumulative L<transformation> (since the original
coordinates).

=cut
sub transform {
    my ($self, $matrix) = @_;
    return $self unless defined($matrix);

    # Transform coords
    my $coords = $self->coords;
    $coords .= transpose($matrix x transpose($coords));

    # Update the cumulative transformation
    # I.e. transform the current transformation by the given matrix
    $self->transformation->transform($matrix);

    return $self;

} # transform


################################################################################
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


################################################################################
=head2 id

Combines the PDBID and the descriptor into a short ID.

E.g. 2nn6 { A 13 _ to A 122 _ } => 2nn6A13_A122_

First four characters are the PDB ID.
A domain descriptor is then appended.

See also L<uniqueid>

=cut
sub id {
    my ($self) = @_;
    my $str = $self->pdbid;
    $str ||= basename($self->file) . '_' if $self->file;
    $str .= ($self->_descriptor_short || '');
    return $str;
} 


################################################################################
=head2 uniqueid

A unique ID, for use with STAMP.

In addition to L<id>, a unique ID for the transformation, if defined, is
appended.

NB If the L<SBG::Domain> contains a L<SBG::Transform>, the unique ID will be
different after read/write or after serializing and deserializing. This is
because the ID is simply the memory address of the Transform. It will be
different for two copies of the same transform.

=cut
sub uniqueid {
    my ($self) = @_;
    my $str = $self->id();
    # Get the memory address of some relevant attribute object, 
    my $rep = $self->transformation;
    $str .= $rep ? sprintf("-0x%x", refaddr($rep)) : '';
    return $str;
} 


################################################################################
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


################################################################################
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
    my ($self, $other) = @_;

    return 0 unless defined $other;
    # Equal if pointing to same underlying object
    return 1 if refaddr($self) == refaddr($other);

    # Fields, from most general to more specific
    my @fields = qw/pdbid descriptor file/;
    foreach (@fields) {
        # If both undefined, then they are not necessarily unequal
        next if !defined($self->$_) && !defined($other->$_);
        # If one is defined but the other undefined, they are unequal
        return 0 if defined($self->$_) ^ defined($other->$_);
        # Here both are defined, are they equal
        return 0 if $self->$_ ne $other->$_;
    }
    # Assume equal if metadata is same and transformations are same
    my $transeq = $self->transformation == $other->transformation;

    return $transeq;

} # equal


################################################################################
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


################################################################################
=head2 seq

 Function: 
 Example : 
 Returns : 
 Args    : 


=cut
sub seq {
    my ($self,) = @_;
    my $seq = SBG::Run::pbdseq($self);
    return $seq;

} # seq


################################################################################
no Moose::Role;
1;

