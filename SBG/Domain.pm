#!/usr/bin/env perl

=head1 NAME

SBG::Domain - Represents a STAMP domain

=head1 SYNOPSIS

 use SBG::Domain;

=head1 DESCRIPTION

Represents a single STAMP Domain, being a chain or sub-segment of a protein
chain from a PDB entry.

Can include multiple segments from multiple chains of a single file.

Each domain has a unique name, called a B<label>. When this is read from STAMP DOM files, these may take the form:

 2br2 (pdbid=2br2)
 2br2A (pdbid=2br2, chainid=A0
 2br2-RRP43 (pdbid=2br2, label=RRP43)
 2br2A-RRP43 (pdbid=2br2, chainid=A, label=RRP43)
 RRP43 (label=RRP43)
 2br2A2 (pdbid=2br2, chainid=A, and it's had 2 transforms applied)
 2br2A_3 (pdbid=2br2, chainid=A, the '_3' is discarded)

The label (part after the '-') must be unique within any L<SBG::Complex>

If a label contains a dash, only the bit after the - will be the actual label. I.e. 

 my $d = new SBG::Domain(-label=>"2br2d-myprot");
 print $d->label;

... will print "myprot". If you want the whole thing back, use :

 print $d->stampid;



=head1 SEE ALSO

L<SBG::DomainIO> , L<SBG::CofM> , L<SBG::Transform>

http://www.compbio.dundee.ac.uk/manuals/stamp.4.2/node29.html
=cut

################################################################################

package SBG::Domain;
use SBG::Root -Base;

use overload (
    '""' => '_asstring',
    '-' => 'dist',
    '==' => '_equal',
    'eq' => '_equal',
    'cmp' => '_cmp',
    );

use warnings;
use PDL;
use PDL::Ufunc;
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
=head2 rg
 
Radius of gyration of this domain

=cut
field 'rg' => 0;


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
    if ($self->{pdbid}) { return $self->{pdbid}; }
    # Or try parsing out of filename or label
    return $self->{pdbid} if $self->_file2pdbid;
    return $self->{pdbid} if $self->_label2pdbid;
    return undef;
}

# Name of domain (or STAMP domain ID).  STAMP likes it the first four characters
# correspond to a PDB ID (case insensitive).
sub label {
    my ($newlabel) = shift;
    return $self->{label} unless $newlabel;
    $self->{label} = $newlabel;
    # Try to extract any PDB ID at beginning of label
    $self->_label2pdbid();
    return $self->{label};
}


# Path to PDB/MMol file
# This can be blank and STAMP will look for thas file based on its 'label'
sub file {
    my ($newfile) = shift;
    return $self->{file} unless $newfile;
    $self->{file} = $newfile;
    # Try to extract any PDB ID from file name
    $self->_file2pdbid();
    return $self->{file};
}


# Only returns value when this Domain corresponds to an entire chain
# Otherwise, check the 'descriptor' field
sub chainid {
    $self->descriptor =~ /^\s*CHAIN\s+([a-zA-Z_])\s*$/i;
    return $1;
}


# A label suitable for STAMP (unique), prefixed with PDBID/chain ID
sub stampid {
    my $pdbid = $self->pdbid;
    if ($pdbid && $self->label) {
        # Just return the label if it already begins with the PDB ID
        return $self->label if $self->label =~ /^$pdbid/;        
        # Otherwise concatenate
        return $pdbid . ($self->chainid||'') . '-' . $self->label;
    } elsif ($pdbid) {
        return $pdbid . ($self->chainid||'');
    } elsif ($self->label) {
        return $self->label;
    } else {
        return 'UNK';
    }
} # stampid



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
    # If this is the first call
    $self->{cofm_orig} = $self->{cofm} unless defined $self->{cofm_orig};
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
 Usage   : my $dom = new SBG::Domain(-label=>'mydom', 
                                      -pdbid=>'2nn6', 
                                      -descriptor=>'CHAIN A');
 Function: Creates a new STAMP representation of segment of a protein chain
 Returns : Object handle
 Args    : -label - Any label to identify this structure (no whitespace)
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

    # Parse out PDB ID from label or filename, if given
    $self->_file2pdbid();
    $self->_label2pdbid();

    $self->{opcount} ||= 0;
    # Init centre-of-mass
#     $self->{cofm} ||= mpdl (0,0,0,1);
    # Set the default transformation to the identity
    $self->{transformation} ||= new SBG::Transform;

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
    return $self unless defined($newtrans) && defined($self->cofm);
    # Need to transpose row vector to a column vector first. 
    # Then let Transform do the work.
    my $newcofm = $newtrans->transform($self->cofm->transpose);
    # Transpose back
    $self->cofm($newcofm->transpose);

    $self->{opcount}++;

    # Update the cumulative transformation
    my $prod = $newtrans * $self->transformation;
    $self->transformation($prod);

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
    $self->{transformation} = new SBG::Transform;
    $self->{opcount} = 0;
    $self->{cofm} = $self->{cofm_orig} || mpdl (0,0,0,1);
}


################################################################################
=head2 dist

 Title   : dist
 Usage   : my $linear_distance = $dom1->dist($dom2);
 Function: Positive distance between centres-of-mass of to L<SBG::Domain>s
 Example : my $linear_distance = $dom1 - $dom2; # overloaded operator -
 Returns : Euclidean distance between $dom1->cofm and $dom2->cofm
 Args    : L<SBG::Domain> - Other domain to measure distance to.

Distance between this Domain and some other, measured from their centres-of-mass

=cut
sub dist { 
    $logger->trace;
    my $other = shift;
    $logger->debug("$self $other");
    $logger->trace($self->_cofm2string, " - ", $other->_cofm2string);
    $logger->trace("self") unless defined $self;
    $logger->trace("other") unless defined $other;
    $logger->trace("self cofm") unless defined($self->cofm);
    $logger->trace("other cofm") unless defined($other->cofm);
    $logger->trace("==") unless $self->cofm->dims == $other->cofm->dims;
    return undef unless 
        defined($self) && defined($other) && 
        defined($self->cofm) && defined($other->cofm) &&
        $self->cofm->dims == $other->cofm->dims;
    $logger->trace($self->_cofm2string, " - ", $other->_cofm2string);
    return sqrt(sqdist($self->cofm, $other->cofm));
} # dist


################################################################################
=head2 sqdist

 Title   : sqdist
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Squared distance between two centres of mass
Takes two PDL objects
=cut
sub sqdist {
    my $other = shift;
    my $diff = $self - $other;
    # Remove dimension 0 of matrix, producing a 1-D list. 
    # And remove the last field (just a 1, for affine multiplication)
    $diff = $diff->slice('(0),0:2');
    my $squared = $diff ** 2;
    my $sum = sumover($squared);
    return $sum;
}


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
    my $apt = join(' ', $self->_cofm2array, $self->rg);
    my $bpt = join(' ', $obj->_cofm2array, $obj->rg);
    $logger->debug("$diff = $self($apt) - $obj($bpt)");
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
    if ($self->_equal($obj)) {
        $logger->info("Identical domain, overlaps");
        return 1;
    }
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

=cut
sub _asstring {
    my $s = $self->label || "";
    if ($self->pdbid) {
        $s .= "(" . $self->pdbid . " " . $self->descriptor . ")";
    }
    return $s;
}


# Are two domains effectively equal, other than their label
# This includes centre-of-mass
sub _equal {
    my ($other) = @_;

    # Fields, from most general to more specific
    my @fields = qw(pdbid descriptor file);
    foreach (@fields) {
        return 0 if $self->{$_} && $other->{$_} && 
            $self->{$_} ne $other->{$_};
    }
    # But has one maybe already been transformed?
    return 0 unless all($self->cofm == $other->cofm);
    # OK, everything's the same, apart from the label, which is allowed
    return 1;
}


sub _cmp {
    my ($other) = @_;
    return $self->label cmp $other->label;
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
    return unless defined $self->cofm;
    my @a = 
        ($self->{cofm}->at(0,0), 
         $self->{cofm}->at(0,1), 
         $self->{cofm}->at(0,2)); 
    return @a;
} # _cofm2array


sub _cofm2string {
    my @a = $self->_cofm2array;
    return sprintf("%10.5f %10.5f %10.5f", @a);
} # _cofm2string


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
    my $overwrite = shift || 0;
    my $file = $self->file;
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
=head2 _label2pdbid

 Title   : _label2pdbid
 Usage   : $dom->_label2pdbid
 Function: Sets the internal $dom->pdbid based on $dom->label
 Example : $dom->_label2pdbid
 Returns : The parsed out PDB ID, if any
 Args    : overwrite - if true, erase current pdbid if parsable from label

Parses out the original PDB ID / CHAIN ID, from the STAMP label, if any

A STAMP label is generally just the concatenated PDB ID with the chain ID,
lowercase, e.g. 2nn6a.

If there is no existing 'descriptor' it is set to 'CHAIN <chainid>', if a chain
identifier can also be parsed out of the label.

=cut
sub _label2pdbid {
    my $overwrite = shift || 0;
    return 0 unless $self->{label};
    # Remove any trailing _3434 increment
    $self->{label} =~ s/_\d+$//;
    my $label = $self->label;

    # Looking for labels like: 2br2 2br2A 2br2-RRP43 2br2A_test-RRP43 RRP43
    # E.g.: 2br2A_test-RRP43_5
    # Then: $1: 2br2A_test $2: 2br2 $3: A $4: _test $5: -RRP43 $6: RRP43  
    return 0 unless $label =~ /^((\d\S{3})([a-zA-Z_])?([^-]*))(-?(\S+))?$/;

    $self->{pdbid} = $2 if $overwrite || ! defined $self->{pdbid};
    $self->{label} = $6 || $1 || $self->{label};
    $self->descriptor("CHAIN $3") if $3 && ! defined $self->{descriptor};

    return $self->{pdbid};
} # _label2pdbid


################################################################################
1;

