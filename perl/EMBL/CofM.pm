#!/usr/bin/env perl

=head1 NAME

EMBL::CofM - Centre of Mass (of a PDB protein chain)

=head1 SYNOPSIS

use EMBL::CofM;

=head1 DESCRIPTION


=head1 BUGS

None known.

=head1 REVISION

$Id: Prediction.pm,v 1.33 2005/02/28 01:34:35 uid1343 Exp $

=head1 APPENDIX

Details on functions implemented here are described below.
Private internal functions are generally preceded with an _

=cut

################################################################################

package EMBL::CofM;
use Spiffy -Base, -XXX;
# The centre of mass is a point (an mpdl)
# Default: (0,0,0,1). For affine multiplication, hence additional '1'
field 'pt';
# Radius of gyration
field 'rg' => 0;
# A STAMP domain ID, if used
field 'id';

use overload (
    '""' => 'stringify',
    );

use PDL;
use PDL::Math;
use PDL::Matrix;
use IO::String;

use lib "..";
use EMBL::DB;



################################################################################
=head2 new

 Title   : new
 Usage   : 
 Function: 
 Returns : 
 Args    :

=cut

sub new() {
    my $self = {};
    bless $self, shift;
    $self->{pt} = mpdl (0,0,0,1);
    $self->init(@_) if @_;
    return $self;
} # new

sub init {
    # Initialize with a 3-tuple of X,Y,Z coords
    $self->{pt}->slice('0,0:2') .= mpdl (@_[0..2]);
}

# Return as 3-tuple 
sub array {
    my @a = ($self->{pt}->at(0,0), $self->{pt}->at(0,1), $self->{pt}->at(0,2)); 
    return @a;
}

sub stringify {
    my @a = $self->array;
    return "@a";
}

# Transform this point, using a STAMP tranform from the given file
# File is actually just a space-separated CSV with a 3x4 matrix
# I.e not a STAMP DOM file
sub ftransform {
    my $filepath = shift;
    chomp $filepath;
    print STDERR "transform: $filepath\n";
    unless (-f $filepath && -r $filepath && -s $filepath) {
        print STDERR "Cannot read transformation from: $filepath\n";
        return undef;
    }

    # This transformation is just a 3x4 text table, from STAMP, without any { }
    my $rasc = zeroes(4,4);
    # Overwrite with 3x4 from file 
    $rasc->rasc($filepath);
    # Put a 1 in the cell 3,3 (bottom right) for affine matrix multiplication
    $rasc->slice('3,3') .= 1;

    # Finally, transform vect using matrix (using PDL::Matrix::mpdl objects)
    # (transpose'ing row of point coordinates to column vector)
    my $new = mpdl($rasc) x $self->{pt}->transpose;
    # Convert back to row vector
    $self->{pt} = $new->transpose;

    return $self->{pt};
}


sub transform {
    my $transform = shift;

    print STDERR "CofM::transform self: $self\n";
    print STDERR "CofM::transform transform: $transform\n";

    print STDERR "matrix: ", $transform->{matrix}, "\n";
    print STDERR "pt: ", $self->{pt}, "\n";

    my $new = $transform->{matrix} x $self->{pt}->transpose;
    return $self->{pt} = $new->transpose;
}


# Extent to which two spheres overlap (linearly, i.e. not in terms of volume)
# ... requires no sqrt calculation (which could be costly)
sub overlap {
    my $obj = shift;
    # Distance between centres
    my $sqdist = sumover (($self->{pt} - $obj->{pt}) ** 2);
    # Convert to scalar
    $sqdist = $sqdist->at(0);
    # Radii of two spheres
    my $radii = $self->{rg} + $obj->{rg};
    # Overlaps when distance between centres < sum of two radii
    return $radii * $radii - $sqdist;
}

# true of the spheres still overlap, beyond a given allowed minimum overlap
sub overlaps {
    my ($obj, $thresh) = @_;
    $thresh ||= 0;
    return $self->overlap($obj) - $thresh > 0;
}

# Update internal coords from DB, given PDB ID/chain ID
sub fetch {
    my $id = shift;

    # TODO use Config::IniFiles;
    my $dbh = dbconnect("pc-russell12", "trans_1_5") or return undef;
    # Static handle, prepare it only once
    our $sth;
    $sth ||= $dbh->prepare("select cofm.Cx,cofm.Cy,cofm.Cz,cofm.Rg " .
                           "from cofm, entity " .
                           "where cofm.id_entity=entity.id and " .
                           "entity.acc=?");
    $sth or return undef;


    # Upper-case PDB ID
    my ($pdbid, $chainid) = $id =~ /(.{4})(.{1})/;
    $pdbid = uc $pdbid;
    my $str = "pdb|$pdbid|$chainid";

    if (! $sth->execute($str)) {
        print STDERR $sth->errstr;
        return undef;
    }

    my @pt_rg = $sth->fetchrow_array();

    $self->id($id);
    # Save as new coords in $self
    $self->init(@pt_rg);
    return @pt_rg;
} # fetch

