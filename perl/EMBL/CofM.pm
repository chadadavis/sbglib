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

use strict; 
use warnings;

package EMBL::CofM;

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

sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless $self, $class;

    $self->{pt} = mpdl (0,0,0,1);

    $self->init(@args) if @args;

    # Radius of gyration
    $self->{rg} = $args[3] || 0;
    return $self;

} # new

sub init {
    my ($self, @args) = @_;
    $self->{pt}->slice('0,0:2') .= mpdl (@args[0..2]);
}


# TODO switching back and forth between pdl and mpdl is wasted copying
sub transform {
    my ($self, $filepath) = @_;
    chomp $filepath;
    print STDERR "transformation:\n$filepath\n";
    return undef unless -r $filepath;
    # This transformation is just a 3x4 text table, from STAMP, without any { }

    # 4x4 of 0's
    my $rasc = mpdl zeroes(4,4);
    # Overwrite with 3x4 from file 
    $rasc->rasc($filepath);
    # Put in row-major order
    $rasc = transpose $rasc;
    # Put a 1 in the cell 3,3 (bottom right) for affine matrix multiplication
    $rasc->slice('3,3') .= 1;
    print STDERR "transform:$rasc";
    
    # Create column vector of current coords, with final 1, for affine multipl.
    my $col = ones 4;
    $col->slice('0:2') .= $self->{pt};
    # Needs to be an mpdl object, like the transformation, for matrix multipl.
    $col = mpdl transpose($col);
    print STDERR "pt:$col";
    
    # Finally, transform vect using matrix
    my $new = $rasc x $col;
    print STDERR "new:$new";
    # print wcols(transpose $new);

    # Update saved point
    $self->{pt} = pdl $new->slice('0:2')->transpose;
    print "pt:", $self->{pt}, "\n";
}

sub transform2 {
    my ($self, $filepath) = @_;
    chomp $filepath;
    return undef unless -r $filepath;

    # This transformation is just a 3x4 text table, from STAMP, without any { }
    # 4x4 of 0's
    my $rasc = zeroes(4,4);
    # Overwrite with 3x4 from file 
    $rasc->rasc($filepath);
    # Put a 1 in the cell 3,3 (bottom right) for affine matrix multiplication
    $rasc->slice('3,3') .= 1;
    print STDERR "transform:$rasc";

    # Append final 1, for affine multipl.
    my $col = ones 4;
    $col->slice('0:2') .= $self->{pt};
    print STDERR "pt:$col\n";

    # Finally, transform vect using matrix (using PDL::Matrix::mpdl objects)
    # (transpose'ing row of point coordinates to column vector)
    my $new = mpdl($rasc) x mpdl($col->transpose);
    print STDERR "new:$new";

    # Update saved point
    my @n;
    push @n, $new->at($_, 0) for 0..2;

#     print STDERR "back:", $new->at(1,0), $new->at(2,0), "\n";
    print STDERR "back:@n\n";
#     $self->{pt} = pdl $new->transpose->at(0..2);
#     print STDERR "newpt:", $self->{pt}, "\n";
}

sub transform3 {
    my ($self, $filepath) = @_;
    chomp $filepath;
    return undef unless -r $filepath;

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

# Extent to which two spheres overlap (linearly, i.e. not in terms of volume)
# ... requires no sqrt calculation (which could be costly)
sub overlap {
    my ($self, $obj) = @_;
    # Distance between centres
    my $sqdist = sumover (($self->{pt} - $obj->{pt}) ** 2);
    # Convert to scalar
    $sqdist = $sqdist->at(0);
    # Radii of two spheres
    my $radii = $self->rg + $obj->rg;
    # Overlaps when distance between centres < sum of two radii
    return $radii * $radii - $sqdist;
}

# true of the spheres still overlap, beyond a given allowed minimum overlap
sub overlaps {
    my ($self, $obj, $thresh) = @_;
    $thresh ||= 0;
    return $self->overlap($obj) - $thresh > 0;
}

# Update internal coords from DB, given PDB ID/chain ID
sub fetch {
    my ($self, $id) = @_;

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

    # Save as new coords in $self
    $self->init(@pt_rg);
    return @pt_rg;
} # fetch



################################################################################
=head2 AUTOLOAD

 Title   : AUTOLOAD
 Usage   : $obj->member_var($new_value);
 Function: Implements get/set functions for member vars. dynamically
 Returns : Final value of the variable, whether it was changed or not
 Args    : New value of the variable, if it is to be updated

Overrides built-in AUTOLOAD function. Allows us to treat member vars. as
function calls.

=cut

sub AUTOLOAD {
    my ($self, $arg) = @_;
    our $AUTOLOAD;
    return if $AUTOLOAD =~ /::DESTROY$/;
    my ($pkg, $file, $line) = caller;
    $line = sprintf("%4d", $line);
    # Use unqualified member var. names,
    # i.e. not 'Package::member', rather simply 'member'
    my ($field) = $AUTOLOAD =~ /::([\w\d]+)$/;
    $self->{$field} = $arg if defined $arg;
    return $self->{$field} || '';
} # AUTOLOAD


###############################################################################

1;

__END__
