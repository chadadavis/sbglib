#!/usr/bin/env perl

=head1 NAME

SBG::Domain - Represents a STAMP domain

=head1 SYNOPSIS

 use SBG::Domain;

=head1 DESCRIPTION

Represents a single STAMP Domain, being a chain or sub-segment of a protein
chain from a PDB entry.

Can include multiple segments from multiple chains of a single file.

=head1 SEE ALSO

L<SBG::DomainIO> , L<SBG::CofM> , L<SBG::Transform>

http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html
=cut

################################################################################

package SBG::Domain;
use SBG::Root -Base, -XXX;

use overload (
    '""' => '_asstring',
    '-' => 'rmsd',
    );

use warnings;
use Carp;
use PDL;
use PDL::Math;
use PDL::Matrix;
use File::Temp qw(tempfile);

use SBG::Transform;


################################################################################
# Fields and accessors


# The centre of mass is a point (as an mpdl, from PDL::Matrix)
# Default: (0,0,0,1). For affine multiplication, hence additional '1'
# Prefer to use accessor
# field 'cofm';

# Radius of gyration
field 'rg' => 0;

# STAMP domain identifier.  This can be any label, but STAMP like it the first
# four characters correspond to a PDB ID (case insensitive).
field 'stampid' => '';

# Source PDB ID of structure (without any chain ID)
# Does not need to be explicitly set
# field 'pdbid' => '';


# Path to PDB/MMol file
# This can be blank and STAMP will look for thas file based on its 'stampid'
field 'file' => '';

# STAMP descriptor (e.g. "A 125 _ to A 555 _" or "CHAIN A")
field 'descriptor' => '';

# Ref to Transform object, product of all Transform's ever applied
# Prefer to use an accessor method here
# field 'transformation';

# Sets the PDB ID to given value
# Otherwise, tries to extract if from STAMP label or frome any associated file
# TODO DOC
sub pdbid {
    my ($newid) = shift;
    if ($newid) { return $self->{pdbid} = $newid; }
    return $self->{pdbid} if $self->_stampid2pdbid;
    return $self->{pdbid} if $self->_file2pdbid;
    return undef;
}


################################################################################
=head2 cofm

 Title   : cofm
 Usage   : my $cofm = $dom->cofm; # get
           $dom->cofm($cofm);     # set
           $dom->cofm(12.2343, 66.122, 233.122); # set XYZ
 Function: Accessor for 'cofm' field, which is an L<PDL::Matrix>
 Example : 
 Returns : New value of 'cofm' field.
 Args    : L<PDL::Matrix> - optional, new centre-of-mass to be assigned

The 'cofm' field represents the centre-of-mass of this domain.
The L<PDL::Matrix> is a 1x4 affine matrix (i.e. the last cell is always 1.0);

This is always defined. By default it is the the 4-tuple 0,0,0,1

=cut
sub cofm {
    my ($x, $y, $z) = @_;
    return $self->{cofm} unless (defined $x);
    if (ref($x)) {
        $self->{cofm} = $x;
    } else {
        $self->{cofm} = mpdl ($x, $y, $z, 1);
    }
    return $self->{cofm};
}


################################################################################
=head2 transformation

 Title   : transformation
 Usage   : my $trans = $dom->transformation; # get
           $dom->transformation($trans);     # set
 Function: Accessor for 'transformation' field, which is an L<SBG::Transform>
 Example : 
 Returns : New value of 'transformation' field;
 Args    : L<SBG::Transform> - optional, new transformation to be assigned

=cut
sub transformation {
    my $x = shift;
    return $self->{transformation} unless (defined $x);
    return $self->{transformation} = $x;
}


################################################################################
# Public


################################################################################
=head2 new

 Title   : new
 Usage   : my $dom = new SBG::Domain(-stampid=>'mydom', 
                                      -pdbid=>'2nn6', 
                                      -descriptor=>'CHAIN A');
 Function: Creates a new STAMP representation of segment of a protein chain
 Returns : Object handle
 Args    : -stampid - Any label to identify this structure (no whitespace)
           -pdbid - PDB ID of original structure (not case-sensitive)
           -file - Path to PDB file or original structure
           -descriptor - STAMP descriptor. See:
           http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html

=cut 
sub new () {
    my ($class, %o) = @_;
    my $self = { %o };
    bless $self, $class;
    $self->_undash;

    $self->{cofm} ||= mpdl (0,0,0,1);
    # Set the default transformation to the identity
    $self->reset();

    return $self;
} # new


################################################################################
=head2 transform

 Title   : transform
 Usage   : $dom->transform($some_transformation);
 Function: Applyies given transformation to the centre-of-mass, transforming it
 Example : $dom->transform($some_transformation);
 Returns : $self
 Args    : L<SBG::Transform>

Apply a new transformation to this centre-of-mass.

Any previously saved 'transformation' is updated with the product of the two.

=cut
sub transform {
    my $newtrans = shift;
    return $self unless (defined $newtrans);
    # Need to transpose row vector to a column vector first. 
    # Then let Transform do the work.
    my $newcofm = $newtrans->transform($self->cofm->transpose);
    # Transpose back
    $self->cofm($newcofm->transpose);

    # Update the cumulative transformation
    $self->transformation($self->transformation * $newtrans);
    return $self;
}


################################################################################
=head2 reset

 Title   : reset
 Usage   : $dom->reset;
 Function: Resets the 'transformation' to the identity;
 Example : $dom->reset;
 Returns : The new value of 'transformation', i.e. an identity.
 Args    : NA

Resets the internal Transform, but not the centre of mass ('cofm');

=cut
sub reset {
    return $self->{transformation} = new SBG::Transform;
}


################################################################################
=head2 rmsd

 Title   : rmsd
 Usage   : my $linear_distance = $dom1->rmsd($dom2);
 Function: Positive distance between centres-of-mass of to L<SBG::Domain>s
 Example : my $linear_distance = $dom1 - $dom2; # overloaded operator -
 Returns : Euclidean distance between $dom1->cofm and $dom2->cofm
 Args    : L<SBG::Domain> - Other domain to measure distance to.

Distance between this Domain and some other, measured from their centres-of-mass

=cut
sub rmsd { 
    my $other = shift;
    return undef unless $self->cofm->dims == $other->cofm->dims;
    my $diff = $self->cofm - $other->cofm;
    
    # Remove dimension 0 of matrix, producing a 1-D list. 
    # And remove the last field (just a 1, for affine multiplication)
    $diff = $diff->slice('(0),0:2');
    my $squared = $diff ** 2;
    my $mean = sumover($squared) / nelem($squared);
    my $sqrt = sqrt $mean;

    return $sqrt;
} # rmsd


################################################################################
=head2 overlap

 Title   : overlap
 Usage   : my $linear_overlap = $dom1->overlap($dom2);
 Function: Similar to L<rmsd>, but considers the radius of gyration 'rg'
 Example : my $linear_overlap = $dom1->overlap($dom2);
 Returns : Positive: linear overlap along line connecting centres of spheres
           Negative: linear distance between surfaces of spheres
 Args    : Another L<SBG::Domain>

=cut
sub overlap {
    my $obj = shift;
    # Distance between centres
    my $dist = $self - $obj;
    # Radii of two spheres
    my $sum_radii = $self->rg + $obj->rg;
    # Overlaps when distance between centres < sum of two radii
    my $diff = $sum_radii - $dist;
    return $diff;
}


################################################################################
=head2 overlaps

 Title   : overlaps
 Usage   : $dom1->overlaps($dom2, 20.5);
 Function: Whether two spheres overlap, beyond an allowed threshold (Angstrom)
 Example : if($dom1->overlaps($dom2,20.5)) { print "Clash!\n"; }
 Returns : true if L<overlap> exceeds given thresh
 Args    : L<SBG::Domain> 
           thresh - default 0

=cut
sub overlaps {
    my ($obj, $thresh) = @_;
    $thresh ||= 0;
    return $self->overlap($obj) - $thresh > 0;
}


################################################################################
# Private


################################################################################
=head2 _asstring

 Title   : _asstring
 Usage   : my $str = $dom->_asstring;
 Function: Resturns a string representation of this domain.
 Example : print "Domain is $dom"; # automatic stringification
 Returns : string
 Args    : NA

Contains space-separated fields: stampid, pdbid, cofm, rg

=cut
sub _asstring {
    my @a = ($self->stampid, $self->pdbid, $self->_cofm2array, $self->rg);
    @a = map { $_ || "" } @a;
    return "@a";
}



################################################################################
=head2 _cofm2array

 Title   : _cofm2array
 Usage   : my @xyz = $dom->_cofm2array();
 Function: Converts internal centre-of-mass ('cofm' field) to a 3-tuple
 Example : print "centre-of-mass is: " . $dom->_cofm2array() . "\n";
 Returns : 3-tuple (array of 3 elements)
 Args    : NA

=cut
sub _cofm2array {
    my @a = 
        ($self->{cofm}->at(0,0), 
         $self->{cofm}->at(0,1), 
         $self->{cofm}->at(0,2)); 
    return @a;
} # _cofm2array



################################################################################
=head2 _file2pdbid

 Title   : _file2pdbid
 Usage   : $dom->_file2pdbid
 Function: Sets the internal $dom->pdbid based on $dom->file
 Example : $dom->file2id
 Returns : The parsed out PDB ID, if any
 Args    : filename, optional, otherwise $self->file is used

Parses out the original PDB ID / CHAIN ID, from the file name

If there is no existing 'descriptor' it is set to 'CHAIN <chainid>', if a chain
identifier can also be parsed out of the filename.

Overwrites any existing 'pdbid' if a PDB ID can be parsed from filename.

=cut
sub _file2pdbid {
    my $file = shift || $self->file;
    return 0 unless $file;
    my (undef,$pdbid,$chid) = $file =~ m|.*/(pdb)?(.{4})([a-zA-Z_])?\.?.*|;
    return unless $pdbid;
    # Overwrite any previous PDB ID, as the file name is more authoritative
    $self->pdbid($pdbid) if $pdbid;
    # Don't overwrite the descriptor, if we were just looking for the PDB ID
    if ($chid && ! $self->descriptor) {
        $self->descriptor("CHAIN $chid");
    }
    return $pdbid;
} # _file2pdbid


################################################################################
=head2 _stampid2pdbid

 Title   : _stampid2pdbid
 Usage   : $dom->_stampid2pdbid
 Function: Sets the internal $dom->pdbid based on $dom->stampid
 Example : $dom->_stampid2pdbid
 Returns : The parsed out PDB ID, if any
 Args    : overwrite - if true, erase current pdbid if parsable from stampid

Parses out the original PDB ID / CHAIN ID, from the STAMP label, if any

A STAMP label is generally just the concatenated PDB ID with the chain ID,
lowercase, e.g. 2nn6a.

If there is no existing 'descriptor' it is set to 'CHAIN <chainid>', if a chain
identifier can also be parsed out of the label.

=cut
sub _stampid2pdbid {
    my $overwrite = shift || 0;
    my $stampid = $self->stampid;
    return 0 unless $stampid;
    my ($pdbid,$chid) = $stampid =~ m|^(.{4})([a-zA-Z_])?$|;
    return unless $pdbid;
    # Don't overwrite an existing pdbid, unless forced
    if ($pdbid && ($overwrite || ! $self->{pdbid})) {
        $self->pdbid($pdbid);
    }
    if ($chid && ! $self->descriptor) {
        $self->descriptor("CHAIN $chid");
    }
    return $pdbid;
} # _stampid2pdbid


################################################################################
1;

