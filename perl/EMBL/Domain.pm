#!/usr/bin/env perl

=head1 NAME

EMBL::Domain - Represents a STAMP domain

=head1 SYNOPSIS

use EMBL::Domain;

=head1 DESCRIPTION

Represents a single STAMP Domain, being a chain or sub-segment of a protein
chain from a PDB entry.

=head1 Functions

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################

package EMBL::Domain;
use Spiffy -Base, -XXX;

# The centre of mass is a point (as an mpdl, from PDL::Matrix)
# Default: (0,0,0,1). For affine multiplication, hence additional '1'
# Prefer to use accessor
# field 'cofm';
# Radius of gyration
field 'rg' => 0;
# STAMP domain identifier (any label)
field 'stampid' => '';
# The original stamp identifier of structure
# TODO BUG With or without chain ID ?
field 'pdbid' => '';
# Path to PDB/MMol file
field 'file' => '';
# STAMP descriptor (e.g. "A 125 _ to A 555 _" or "CHAIN A")
field 'descriptor' => '';
# Ref to Transform object, product of all Transform's ever applied
# Prefer to use an accessor method here
# field 'transformation';

use base "Bio::Root::Root";

use overload (
    '""' => 'asstring',
    '-' => 'rmsd',
    );

use Carp;
use PDL;
use PDL::Math;
use PDL::Matrix;
use File::Temp qw(tempfile);

use EMBL::DB;
use EMBL::Transform;


################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    : 

Accepts a label (e.g. componentA) , and a PDBID/CHAIN ID (e.g. '2nn6A')

=cut 
# NB Spiffy requires () on constructors and Pdoc requires a space before the ()
sub new () {
    my $self = {};
    bless $self, shift;
    $self->{cofm} = mpdl (0,0,0,1);
    $self->reset();

    my ($stampid, $pdbid, $descriptor) = 
        $self->_rearrange(
            [qw(STAMPID PDBID DESCRIPTOR)], 
            @_);

    $self->{stampid} = $stampid if $stampid;

# TODO
#     $self->fetch($pdbid_chainid) if $pdbid_chainid;

    return $self;
} # new


################################################################################
=head2 _parse_file

 Title   : _parse_file
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Parse out the original PDB ID / CHAIN ID, from the file name

=cut
sub _parse_file {
    my $file = $self->file;
    return 0 unless $file;
    my (undef,$pdbid,$chid) = m|.*/(pdb)?(.{4})([a-zA-Z_])?\.?.*|;
    $self->pdbid($pdbid) if $pdbid;
    if ($chid && ! $self->descriptor) {
        $self->descriptor("CHAIN $chid");
    }
    return $pdbid;
} 


################################################################################
=head2 _parse_stampid

 Title   : _parse_stampid
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
sub _parse_stampid {
    my $stampid = $self->stampid;
    return 0 unless $stampid;
    my ($pdbid,$chid) = m|(.{4})([a-zA-Z_])?|;
    $self->pdbid($pdbid) if $pdbid;
    if ($chid && ! $self->descriptor) {
        $self->descriptor("CHAIN $chid");
    }
    return $pdbid;
}


################################################################################
=head2 cofm

 Title   : cofm
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
sub cofm {
    my $x = shift;
    return $self->{cofm} unless $x;
    return $self->{cofm} = $x;
}


################################################################################
=head2 transformation

 Title   : transformation
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
sub transformation {
    my $x = shift;
    return $self->{transformation} unless $x;
    return $self->{transformation} = $x;
}


################################################################################
=head2 reset

 Title   : reset
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Resets the cumulative Transform, but not the centre of mass

=cut
sub reset {
    $self->{tainted} = 0; 
    return $self->{transformation} = new EMBL::Transform;
}


################################################################################
=head2 asarray

 Title   : asarray
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Return as 3-tuple 

=cut
sub asarray {
    my @a = 
        ($self->{cofm}->at(0,0), $self->{cofm}->at(0,1), $self->{cofm}->at(0,2)); 
    return @a;
}


################################################################################
=head2 asstring

 Title   : asstring
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut
sub asstring {
    my @a = ($self->stampid, $self->pdbid, $self->asarray, $self->rg);
    return "@a";
}


################################################################################
=head2 transform

 Title   : transform
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Apply a new transformation to this point, and save cumulative transform

TODO DOC order of mat. mult.
=cut

sub transform {
    my $newtrans = shift;
    # Need to transpose row vector to a column vector first. 
    # Then let Transform do the work.
    my $newcofm = $newtrans->transform($self->cofm->transpose);
    $self->cofm($newcofm->transpose);

    # Update the cumulative transformation
    $self->transformation($self->transformation * $newtrans);
    return $self;
}


################################################################################
=head2 rmsd

 Title   : rmsd
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Distance between this Domain and some other

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
    return $mean;
}


################################################################################
=head2 overlap

 Title   : overlap
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

Extent to which two spheres overlap (linearly, i.e. not in terms of volume).
Requires no sqrt calculation (which could be costly).

=cut
sub overlap {
    my $obj = shift;
    # Distance between centres
    my $sqdist = sumover (($self->cofm - $obj->cofm) ** 2);
    # Convert to scalar
    my $dist = sqrt $sqdist->at(0);
    # Radii of two spheres
    my $sum_radii = $self->rg + $obj->rg;
    # Overlaps when distance between centres < sum of two radii
    return $sum_radii - $dist;
}


################################################################################
=head2 overlaps

 Title   : overlaps
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

True if the spheres still overlap, beyond a given allowed minimum overlap thresh

=cut
sub overlaps {
    my ($obj, $thresh) = @_;
    $thresh ||= 0;
    return $self->overlap($obj) - $thresh > 0;
}


################################################################################
1;

